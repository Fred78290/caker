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
/// - **Two discovery mechanisms, because `VMLifecycleHooks` alone isn't enough.** `VMLifecycleHooks`
///   (`IMDSCoordinator` also uses it, supports multiple independent subscribers) only fires inside
///   the *same process* that spawned/reaped the VM via `StartHandler` — a VM built by `caked
///   compose up`'s own one-shot process, or by `caker`'s `.app` mode (VMs embedded in-process, no
///   `caked` at all — see `CakedLib.ComposeHandler`'s own doc comment), is invisible to a
///   coordinator running inside a *different* `caked service listen` process, or inside the
///   standalone `caked dns` command (`Sources/caked/Commands/Dns.swift`). A periodic disk-based
///   poll (`refreshFromDisk()`, `StorageLocation(runMode:).list()` + `CakeConfig`'s
///   `composeProject`/`composeService` tags) is the authoritative, process-independent source of
///   truth; `VMLifecycleHooks` (via `handle(_:)`) is kept purely as a low-latency accelerant for
///   the one process where it does fire, not relied on for correctness.
/// - **Every running VM is resolvable, not just compose-tagged ones** — `refreshFromDisk()`
///   registers a plain `<vmname>.<domain>` entry for every running VM with a NAT address,
///   compose-managed or not, in addition to the `<service>.<project>.<domain>` entry a
///   compose-tagged VM also gets. This is a deliberate widening from the original "compose
///   service discovery only" design: once the resolver exists and is reachable from every VM
///   anyway, there's no reason to withhold plain-name resolution from a VM that just happens not
///   to be part of a compose project.
/// - **Lazy vs. eager**: embedded in `caked service listen` (`stopWhenEmpty: true`, the default),
///   the server still only binds once *any* VM is actually running and shuts itself down once the
///   registry empties out (no VMs running at all) — a host with nothing running never pays for
///   the socket. The standalone `caked dns` command instead calls `start(eager: true)`, which
///   binds immediately and never self-shuts on an empty registry (0 VMs running right now doesn't
///   mean none will ever start again — that's the whole point of running it as its own persistent
///   command).
/// - **A missing NAT gateway interface fails fast, not after a 10s retry.** Since every running
///   VM now keeps `refreshFromDisk()`'s registry non-empty (not just compose-tagged ones — see
///   above), `ensureServerRunning()` fires on essentially every VM start — and the gateway
///   interface vmnet is supposed to bring up for that VM's NAT attachment can briefly lag behind
///   the VM's own `.running` status, or (on a host where no VM has ever used the NAT network)
///   not exist yet at all. `ComposeDNSServer.start()` checks the target address is actually
///   assigned to a host interface before ever attempting to bind, throwing the dedicated
///   `ComposeDNSServerError.gatewayNotPresent` case if not — `startWithRetry` rethrows that
///   immediately rather than spending its usual `maxAttempts`/`retryDelayNanoseconds` budget
///   (up to 10s) on a condition a tight bind-retry loop can't fix. This coordinator's own catch
///   block logs it at `.debug`, not `.warn`, since `refreshFromDisk()`'s own poll cadence (every
///   few seconds) will call `ensureServerRunning()` again on its own — the retry story lives at
///   the poll level, not inside `startWithRetry`, for this specific failure.
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
	private var pollTask: Task<Void, Never>?
	private var stopWhenEmpty = true

	public init(group: EventLoopGroup, runMode: Utils.RunMode, internalPort: Int = ComposeDNSServer.internalBindPort) {
		self.group = group
		self.runMode = runMode
		self.internalPort = internalPort
	}

	/// Registers every already-running compose-tagged VM at daemon startup (the daemon
	/// restarted while VMs kept running) — mirrors `IMDSCoordinator.registerAlreadyRunning()`.
	/// Superseded by `startPolling(interval:)` for anything running continuously (the poll loop's
	/// own first pass does the same thing), kept as a separate entry point for a caller that only
	/// wants the initial snapshot without committing to a recurring poll.
	public func registerAlreadyRunning() async {
		await self.refreshFromDisk()
	}

	/// The blocking counterpart to `startPolling(interval:eager:)` below — same setup (cancels
	/// any existing poll task, optionally starts the server eagerly), but *awaits* the new poll
	/// task's completion instead of firing it off detached and returning immediately. Used by the
	/// standalone `caked dns` command's `run()` so the process stays alive via the poll loop
	/// actually running, not via a separate `CheckedContinuation` kept pending until a signal
	/// arrives — the poll task *is* the work keeping the process up, and `shutdown()` cancelling
	/// it is what lets this function (and `run()` with it) return naturally once a signal fires.
	public func startPollingSync(interval: TimeInterval = 3, eager: Bool = false) async {
		self.pollTask?.cancel()

		let task = Task {
			if eager {
				self.stopWhenEmpty = false
				await self.ensureServerRunning()
			}

			await self.polling(interval: interval)
		}

		self.pollTask = task

		_ = await task.value
	}

	/// Starts (or restarts) the recurring poll loop that is this coordinator's real, process-
	/// independent source of truth — see the type's own doc comment. `eager: true` (used by the
	/// standalone `caked dns` command) binds the server immediately, before the first poll even
	/// runs, and disables the "shut down once the registry is empty" behavior the embedded,
	/// lazy-start use inside `caked service listen` still wants.
	public func startPolling(interval: TimeInterval = 3, eager: Bool = false) async {
		self.pollTask?.cancel()

		if eager {
			self.stopWhenEmpty = false
			await self.ensureServerRunning()
		}

		self.pollTask = Task { [weak self] in
			guard let self else { return }

			await self.polling(interval: interval)
		}
	}

	private func polling(interval: TimeInterval) async {
		while Task.isCancelled == false {
			await self.refreshFromDisk()

			try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
		}
	}

	/// One full rescan: lists every VM, keeps the ones that are currently running with a
	/// resolvable NAT address — every one of those becomes a plain `<vmname>.<domain>` entry,
	/// and the compose-tagged subset additionally becomes a `<service>.<project>.<domain>` entry
	/// — and atomically swaps both sets into the registry (`ComposeDNSRegistry.replaceAll(...)`)
	/// — see that method's own doc comment for why a full swap rather than incremental
	/// register/unregister calls. Starts the server on the first pass that finds anything running
	/// at all (mirroring `register(location:)`'s old lazy-start behavior) and, for the
	/// embedded/lazy use, stops it again once a pass finds nothing running.
	public func refreshFromDisk() async {
		guard let vms = try? StorageLocation(runMode: self.runMode).list() else { return }

		var services: [(project: String, service: String, ip: String)] = []
		var vmNames: [(name: String, ip: String)] = []

		for (_, location) in vms {
			guard case .running = location.status else { continue }
			guard let config = try? location.config() else { continue }
			guard let address = ComposeDNS.natAddress(for: config) else { continue }

			vmNames.append((name: location.name, ip: address))

			if let project = config.composeProject, let service = config.composeService {
				services.append((project: project, service: service, ip: address))
			}
		}

		self.registry.replaceAll(services: services, vms: vmNames)

		if services.isEmpty, vmNames.isEmpty {
			if self.stopWhenEmpty, self.server != nil {
				self.logger.info("No virtual machines left running; stopping compose DNS server")
				await self.shutdown(stopPolling: false)
			}
		} else {
			await self.ensureServerRunning()
		}
	}

	public func handle(_ event: VMLifecycleEvent) async {
		// A pure accelerant, not authoritative — see the type doc comment. Either branch just
		// triggers an immediate rescan instead of hand-updating the registry itself, so this can
		// never drift from what `refreshFromDisk()` would have found on its own a few seconds
		// later anyway.
		switch event {
		case .started, .stopped:
			await self.refreshFromDisk()
		}
	}

	public func shutdown() async {
		await self.shutdown(stopPolling: true)
	}

	// MARK: - Internals

	private func shutdown(stopPolling: Bool) async {
		if stopPolling {
			self.pollTask?.cancel()
			self.pollTask = nil
		}

		self.startTask?.cancel()
		_ = await self.startTask?.result
		self.startTask = nil

		if let server = self.server {
			await self.disableRedirect()

			await server.shutdown()
			self.server = nil

			if let home = try? Home(runMode: self.runMode) {
				try? home.composeDnsPID.delete()
			}

			self.logger.info("Compose DNS server stopped")
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

				// So `ComposeDNS.isResolverRunning(runMode:)` — checked by `ensureResolverRunning(runMode:)`
				// before spawning a standalone `caked dns` — sees this coordinator too, whether it's
				// embedded in `caked service listen` or itself the standalone command.
				if let home = try? Home(runMode: self.runMode) {
					try? home.composeDnsPID.writePID()
				}

				if server.needsPFRedirect {
					await self.enableRedirect(gateway: gateway, internalPort: server.internalPort)
				}
			} catch is CancellationError {
				// Torn down before it managed to start; nothing to log.
			} catch let error as ComposeDNSServerError {
				// Expected and transient, not an operational failure — the NAT gateway
				// interface just isn't up yet (see the error's own doc comment). The next
				// `refreshFromDisk()` poll tick (a few seconds away) will call
				// `ensureServerRunning()` again on its own; logging this at `.warn` every
				// time would be noisy now that any VM starting (not just a compose one)
				// triggers this same race.
				self.logger.debug("Compose DNS server not started yet: \(error)")

				self.server = nil
				self.startTask = nil
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
