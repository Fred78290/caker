import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib
import NIO

/// Owns the `ComposeDNSServer` of one shared network that has DNS enabled (`VZSharedNetwork.dns`).
/// It is started by the process running that network (`caked networks run`, from
/// `VZVMNet.start(_:)`'s `startedHandler`), bound to the network's gateway address, and lives and
/// dies with it — there is no standalone resolver process any more.
///
/// - **Discovery is a periodic disk poll**, not `VMLifecycleHooks`: a VM may be started by any
///   process (`caked compose up`, `caker`'s `.app` mode, a `caked service listen` daemon), none of
///   which is the network's process. `refreshFromDisk()` (`StorageLocation(runMode:).list()` +
///   `CakeConfig`'s `composeProject`/`composeService` tags) is the single source of truth.
/// - **Every running VM is resolvable**, not just compose-tagged ones: a plain `<vmname>.<domain>`
///   entry for each, plus `<service>.<project>.<domain>` for compose-managed ones.
/// - **A missing gateway interface fails fast.** `ComposeDNSServer.start()` checks that the bind
///   address is assigned to a host interface before binding and throws
///   `ComposeDNSServerError.gatewayNotPresent` otherwise; the next poll tick retries, so this is
///   logged at `.debug`.
/// - **Not verified end to end**: addresses come from the host DHCP lease table of the *default*
///   network (`ComposeDNS.natAddress(for:)`), so a custom network with DNS enabled answers with
///   the default network's addresses.
public actor ComposeDNSCoordinator {
	private let group: EventLoopGroup
	private let runMode: Utils.RunMode
	private let internalPort: Int
	private let registry = ComposeDNSRegistry()
	private let logger = Logger("ComposeDNSCoordinator")

	private var server: ComposeDNSServer?
	private var startTask: Task<Void, Error>?
	private var pollTask: Task<Void, Never>?
	private let bindAddress: String

	public init(group: EventLoopGroup, runMode: Utils.RunMode, bindAddress: String, internalPort: Int = ComposeDNS.internalBindPort) {
		self.group = group
		self.runMode = runMode
		self.bindAddress = bindAddress
		self.internalPort = internalPort
	}

	/// Binds the server, then runs the recurring poll loop until `shutdown()` cancels it. Blocks
	/// for the lifetime of the coordinator: the poll task is the work keeping the caller alive.
	public func startPollingSync(interval: TimeInterval = ComposeDNSServer.pollInterval) async {
		self.pollTask?.cancel()

		let task = Task {
			await self.ensureServerRunning()
			await self.polling(interval: interval)
		}

		self.pollTask = task

		_ = await task.value
	}

	private func polling(interval: TimeInterval) async {
		defer {
			self.logger.info("Compose DNS coordinator stopped")
		}

		while Task.isCancelled == false {
			await self.refreshFromDisk()

			try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
		}
	}

	/// One full rescan: lists every VM, keeps the ones that are currently running with a
	/// resolvable address, and atomically swaps both the plain-name and the compose-service
	/// entries into the registry (`ComposeDNSRegistry.replaceAll(...)`). Also retries binding the
	/// server if an earlier attempt failed.
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

		await self.ensureServerRunning()
	}

	public func shutdown() async {
		self.logger.info("Will shutdown Compose DNS server")

		if let pollTask {
			self.pollTask = nil

			pollTask.cancel()
		}

		if let startTask {
			self.startTask = nil

			startTask.cancel()
			_ = await startTask.result
		}

		if let server = self.server {
			self.server = nil

			await server.shutdown()

			self.logger.info("Compose DNS server stopped")
		}
	}

	private func ensureServerRunning() async {
		guard self.server == nil, self.startTask == nil else { return }

		let server = ComposeDNSServer(group: self.group, registry: self.registry, bindAddress: self.bindAddress, internalPort: self.internalPort)

		self.server = server

		self.startTask = Task {
			do {
				try await server.startWithRetry()

				self.logger.info("Compose DNS server started at \(self.bindAddress):\(server.internalPort)")
			} catch is CancellationError {
				// Torn down before it managed to start; nothing to log.
				self.logger.debug("Compose DNS server cancelled before it could start")
			} catch let error as ComposeDNSServerError {
				// Expected and transient: the gateway interface isn't up yet. The next poll
				// tick calls `ensureServerRunning()` again.
				self.logger.debug("Compose DNS server not started yet: \(error)")

				self.server = nil
			} catch {
				self.logger.warn("Compose DNS server could not start: \(error)")

				self.server = nil
			}

			self.startTask = nil
		}
	}
}
