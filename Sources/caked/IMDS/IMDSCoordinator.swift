import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib
import NIO

/// Owns the single, process-wide `IMDSServer` for the `caked` daemon.
///
/// Design summary (see also the doc comment on `IMDSRegistry`):
///
/// - All Linux VMs on a host share one host-only "imds" vmnet virtual switch (see
///   `IMDSNetworkInterface` for the subnet/gateway), so exactly one `IMDSServer` bound
///   to that gateway is correct for any number of concurrently running VMs — there's no
///   need to bind per network interface.
/// - The server is started lazily, on the first Linux VM to start, and torn
///   down once the last one stops — so hosts that never run Linux guests
///   never bind the socket, and we never leak it.
/// - The daemon learns about VM start/stop through `VMLifecycleHooks`
///   (`CakedLib`), which `StartHandler` fires whenever it spawns or reaps a
///   `caked vmrun` child process. This covers both `cakectl start`-initiated
///   launches and `StartHandler.autostart()` at daemon boot — the only two
///   ways `caked service listen` itself brings up a VM. VMs started via a
///   standalone `caked vmrun` invocation that bypasses the daemon (or via
///   Caker.app running a VM in-process without a daemon) are *not* observed
///   by this hook and therefore won't get IMDS support; see the migration's
///   commit message for the reasoning behind accepting that limitation.
public actor IMDSCoordinator {
	private let group: EventLoopGroup
	private let runMode: Utils.RunMode
	private let internalPort: Int
	private let redirectRequested: Bool
	private let registry = IMDSRegistry()
	private let logger = Logger("IMDSCoordinator")

	private var server: IMDSServer?
	private var startTask: Task<Void, Error>?

	/// - Parameters:
	///   - internalPort: The unprivileged loopback port IMDS binds to when running
	///     unprivileged (ignored when root — see `IMDSServer`).
	///   - enablePFRedirect: Whether to install a `pf` redirect so guests can reach IMDS
	///     on port 80. IMDS still starts (on `internalPort`) either way; this only
	///     controls whether it's exposed to guests, since that step needs a short-lived
	///     root helper. Ignored when root (nothing to redirect — already on port 80).
	public init(group: EventLoopGroup, runMode: Utils.RunMode, internalPort: Int = IMDSServer.internalBindPort, enablePFRedirect: Bool = false) {
		self.group = group
		self.runMode = runMode
		self.internalPort = internalPort
		self.redirectRequested = enablePFRedirect
	}

	/// Registers every Linux VM that's already running at daemon startup (e.g. the daemon
	/// restarted while VMs kept running, or VMs were started by a previous daemon instance).
	/// Uses the values already persisted on disk rather than re-deriving them, since a
	/// running VM's `caked vmrun` process already wrote them once it had them.
	public func registerAlreadyRunning() async {
		guard let vms = try? StorageLocation(runMode: self.runMode).list() else {
			return
		}

		for (_, location) in vms {
			guard case .running = location.status else { continue }

			await self.register(location: location)
		}
	}

	public func handle(_ event: VMLifecycleEvent) async {
		switch event {
		case .started(let location, _):
			await self.register(location: location)
		case .stopped(let location, _):
			await self.unregister(location: location)
		}
	}

	/// Tears down the IMDS server (if running) and clears the registry. Call this once, as
	/// part of daemon shutdown.
	public func shutdown() async {
		self.startTask?.cancel()
		_ = await self.startTask?.result
		self.startTask = nil

		if let server = self.server {
			if server.needsPFRedirect && self.redirectRequested {
				await self.disablePFRedirect()
			}

			await server.shutdown()
			self.server = nil
			self.logger.info("IMDS server stopped")
		}
	}

	// MARK: - Internals

	private func register(location: VMLocation) async {
		guard let config = try? location.config(), config.os == .linux else {
			return
		}

		guard let imdsMac = config.imdsMacAddress else {
			self.logger.warn("Linux VM \(location.name) has no persisted IMDS MAC address yet; skipping IMDS registration")
			return
		}

		let metadata = IMDSMetadata(config: config, locationName: location.name, imdsMac: imdsMac)

		metadata.localIPv4 = config.runningIP ?? ""

		self.registry.register(name: location.name, metadata: metadata)

		self.logger.info("Registered VM \(location.name) with IMDS (mac: \(imdsMac))")

		await self.ensureServerRunning()
	}

	private func unregister(location: VMLocation) async {
		guard self.registry.unregister(name: location.name) else {
			return
		}

		self.logger.info("Unregistered VM \(location.name) from IMDS")

		if self.registry.isEmpty {
			await self.shutdown()
		}
	}

	private func ensureServerRunning() async {
		guard self.server == nil, self.startTask == nil else {
			return
		}

		do {
			let server = try await IMDSServer(group: self.group, registry: self.registry, internalPort: self.internalPort)

			self.server = server

			self.startTask = Task {
				do {
					try await server.startWithRetry()

					if server.needsPFRedirect {
						self.logger.info("IMDS server started at http://\(IMDSServer.bindAddress):\(server.internalPort) (reachable from guests already)")

						if self.redirectRequested {
							await self.enablePFRedirect(internalPort: server.internalPort)
						} else {
							self.logger.info("Not additionally exposing IMDS on the standard port 80 (pass --imds-redirect to do so)")
						}
					} else {
						self.logger.info("IMDS server started at http://\(IMDSServer.bindAddress):\(IMDSServer.bindPort)")
					}
				} catch is CancellationError {
					// Torn down before it managed to start; nothing to log.
				} catch {
					self.logger.warn("IMDS server could not start: \(error)")

					// Clear state so the next registration (e.g. once whatever blocked the
					// bind is fixed) retries instead of finding server/startTask non-nil
					// forever. Safe to do unconditionally here: this branch only runs on a
					// genuine startWithRetry() failure, not on the cancellation shutdown()
					// itself triggers.
					self.server = nil
					self.startTask = nil
				}
			}
		} catch {
			self.logger.warn("Failed to create IMDS server: \(error)")
		}
	}

	/// Makes `IMDSServer.bindAddress:bindPort` (port 80, which this unprivileged daemon
	/// can't bind directly) *additionally* reachable there, on top of the internal port it's
	/// already reachable on. Runs a short-lived root helper via `SudoCaked` — see
	/// `Networks.ImdsRedirect` / `PFRedirect`. Best-effort: if the host isn't set up for
	/// passwordless sudo on `caked`, this fails and is logged, but the server keeps running
	/// and stays reachable on its internal port regardless.
	private func enablePFRedirect(internalPort: Int) async {
		// Sandboxed builds (App Store) can't shell out to sudo at all — see
		// Utilities.swift's `if sudo && Bundle.isApplicationSandboxed` for the same
		// restriction elsewhere in this codebase. Don't even attempt it; it would just
		// fail with a confusing error. IMDS itself still works in sandboxed builds — this
		// only skips the optional port-80 exposure.
		guard Bundle.isApplicationSandboxed == false else {
			self.logger.warn("Can't expose IMDS on the standard port 80 in sandboxed builds (sudo isn't available); it stays reachable at http://\(IMDSServer.bindAddress):\(internalPort)")
			return
		}

		let runMode = self.runMode

		do {
			try await Task.detached(priority: .utility) {
				let helper = try SudoCaked(
					arguments: [
						"networks", "imds-redirect",
						"--internal-port=\(internalPort)",
					],
					runMode: runMode
				)

				guard try helper.runAndWait() == 0 else {
					throw ServiceError(helper.standardError.isEmpty ? helper.standardOutput : helper.standardError)
				}
			}.value

			self.logger.info("IMDS reachable at http://\(IMDSServer.bindAddress):\(IMDSServer.bindPort)")
		} catch {
			self.logger.warn("Could not install IMDS pf redirect (is passwordless sudo configured for caked?): \(error)")
		}
	}

	private func disablePFRedirect() async {
		guard Bundle.isApplicationSandboxed == false else {
			// Never installed in the first place — see enablePFRedirect().
			return
		}

		let runMode = self.runMode

		do {
			try await Task.detached(priority: .utility) {
				let helper = try SudoCaked(arguments: ["networks", "imds-redirect", "--disable"], runMode: runMode)

				guard try helper.runAndWait() == 0 else {
					throw ServiceError(helper.standardError.isEmpty ? helper.standardOutput : helper.standardError)
				}
			}.value
		} catch {
			self.logger.warn("Could not remove IMDS pf redirect: \(error)")
		}
	}
}
