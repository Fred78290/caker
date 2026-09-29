import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib
import NIO

/// Owns the single, process-wide `ComposeDNSServer` for the `caked` daemon — same overall shape
/// as `IMDSCoordinator`, and the two are deliberately kept separate (not one coordinator running
/// both servers) since they bind different addresses for different reasons: see `ComposeDNS.swift`
/// for why this one sits on the NAT gateway rather than IMDS's own isolated side channel.
///
/// - Started lazily, on the first VM lifecycle event that turns out to be a compose-managed VM
///   with an already-resolvable NAT-network IP; torn down once the last registered one stops —
///   so a host that never runs `compose up` never binds the socket.
/// - Learns about VM start/stop through the same `VMLifecycleHooks` `IMDSCoordinator` uses
///   (`VMLifecycleHooks.addHandler` supports multiple independent subscribers — see its own doc
///   comment) — every VM start/stop is observed, not just Linux ones (unlike IMDS, since the NAT
///   attachment this rides on isn't OS-gated), and a VM is only registered if `CakeConfig`
///   carries the `composeProject`/`composeService` tags `CakedLib.ComposeHandler.up(...)` sets.
/// - **What's read from code rather than empirically verified**: that
///   `VZNATNetworkDeviceAttachment` genuinely permits VM-to-VM UDP traffic on the shared NAT
///   subnet, not only VM-to-host/internet. Everything here is consistent with that (a single,
///   host-wide subnet per `NetworksHandler.natNetworkInfos()`, no isolation flag anywhere in the
///   code path this attachment goes through), and the existing `VMLocation.waitIPWithLease(...)`
///   NAT branch is proof the *host* can already read a NAT-attached VM's lease-table IP — but
///   nothing in this codebase previously depended on a *guest* being able to reach that resolver
///   over the same subnet. Worth a real two-VM boot-and-`dig` check before relying on this in
///   production; if it turns out VM-to-VM traffic is blocked after all, the fix is confined to
///   this file and `ComposeDNSServer`'s bind address — the registry/wire-codec logic in
///   `ComposeDNS.swift` is unaffected by which network the server ends up bound to.
public actor ComposeDNSCoordinator {
	private let group: EventLoopGroup
	private let runMode: Utils.RunMode
	private let internalPort: Int
	private let registry = ComposeDNSRegistry()
	private let logger = Logger("ComposeDNSCoordinator")

	private var server: ComposeDNSServer?
	private var startTask: Task<Void, Error>?

	public init(group: EventLoopGroup, runMode: Utils.RunMode, internalPort: Int = ComposeDNSServer.internalBindPort) {
		self.group = group
		self.runMode = runMode
		self.internalPort = internalPort
	}

	/// Registers every already-running compose-tagged VM at daemon startup (the daemon
	/// restarted while VMs kept running) — mirrors `IMDSCoordinator.registerAlreadyRunning()`.
	public func registerAlreadyRunning() async {
		guard let vms = try? StorageLocation(runMode: self.runMode).list() else { return }

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

	public func shutdown() async {
		self.startTask?.cancel()
		_ = await self.startTask?.result
		self.startTask = nil

		if let server = self.server {
			await self.disableRedirect()

			await server.shutdown()
			self.server = nil
			self.logger.info("Compose DNS server stopped")
		}
	}

	// MARK: - Internals

	private func register(location: VMLocation) async {
		guard let config = try? location.config(), let project = config.composeProject, let service = config.composeService else {
			return
		}

		guard let address = ComposeDNS.natAddress(for: config) else {
			self.logger.warn("Compose service \(project)/\(service) (\(location.name)) has no NAT-network lease yet; skipping compose DNS registration")
			return
		}

		self.registry.register(project: project, service: service, ip: address)

		self.logger.info("Registered compose service \(project)/\(service) with compose DNS (\(address))")

		await self.ensureServerRunning()
	}

	private func unregister(location: VMLocation) async {
		guard let config = try? location.config(), let project = config.composeProject, let service = config.composeService else {
			return
		}

		guard self.registry.unregister(project: project, service: service) else { return }

		self.logger.info("Unregistered compose service \(project)/\(service) from compose DNS")

		if self.registry.isEmpty {
			await self.shutdown()
		}
	}

	private func ensureServerRunning() async {
		guard self.server == nil, self.startTask == nil else { return }

		guard let gateway = ComposeDNS.natGatewayAddress(runMode: self.runMode) else {
			self.logger.warn("Compose DNS server could not determine the NAT network gateway; skipping")
			return
		}

		let server = ComposeDNSServer(group: self.group, registry: self.registry, bindAddress: gateway, internalPort: self.internalPort)

		self.server = server

		self.startTask = Task {
			do {
				try await server.startWithRetry()

				self.logger.info("Compose DNS server started at \(gateway):\(server.internalPort)")

				if server.needsPFRedirect {
					await self.enableRedirect(gateway: gateway, internalPort: server.internalPort)
				}
			} catch is CancellationError {
				// Torn down before it managed to start; nothing to log.
			} catch {
				self.logger.warn("Compose DNS server could not start: \(error)")

				self.server = nil
				self.startTask = nil
			}
		}
	}

	/// Installs the `pf` UDP/TCP port redirect so the guest, told to query the gateway address
	/// directly on port 53 (see `ComposeFile.toBuildOptions`'s split-DNS `post_commands`), can
	/// actually reach the server on whichever port it's really bound to (53 as root, or
	/// `internalPort` otherwise). Runs a short-lived root helper via `SudoCaked` — see
	/// `Networks.ComposeDNSRedirect`/`PFRedirect`. Best-effort and silently skipped in sandboxed
	/// builds (needs `sudo`), matching `IMDSCoordinator.enableAddressAlias(...)` exactly — but
	/// unlike that one, this redirect isn't a convenience: without it, an unprivileged `caked`
	/// simply has no way for a guest to reach compose DNS at all (`resolvectl dns` has no syntax
	/// for a non-standard port).
	private func enableRedirect(gateway: String, internalPort: Int) async {
		guard Bundle.isApplicationSandboxed == false else { return }

		let runMode = self.runMode

		do {
			try await Task.detached(priority: .utility) {
				let helper = try SudoCaked(
					arguments: [
						"networks",
						"compose-dns-redirect",
						"--gateway-address=\(gateway)",
						"--internal-port=\(internalPort)",
						"--log-level=\(Logger.Level().description)",
					],
					runMode: runMode,
					standardOutput: FileHandle.standardOutput,
					standardError: FileHandle.standardError
				)

				guard try helper.runAndWait() == 0 else {
					throw ServiceError(helper.standardError.isEmpty ? helper.standardOutput : helper.standardError)
				}
			}.value

			self.logger.info("Compose DNS also reachable at \(gateway):53 (pf redirect)")
		} catch {
			self.logger.warn("Could not install compose DNS pf redirect (is passwordless sudo configured for caked?): \(error)")
		}
	}

	private func disableRedirect() async {
		guard Bundle.isApplicationSandboxed == false else { return }

		let runMode = self.runMode

		do {
			try await Task.detached(priority: .utility) {
				let helper = try SudoCaked(
					arguments: [
						"networks",
						"compose-dns-redirect",
						"--disable",
						"--log-level=\(Logger.Level().description)",
					],
					runMode: runMode,
					standardOutput: FileHandle.standardOutput,
					standardError: FileHandle.standardError
				)

				guard try helper.runAndWait() == 0 else {
					throw ServiceError(helper.standardError.isEmpty ? helper.standardOutput : helper.standardError)
				}
			}.value
		} catch {
			self.logger.warn("Could not remove compose DNS pf redirect: \(error)")
		}
	}
}
