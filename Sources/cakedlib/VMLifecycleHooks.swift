import Foundation
import GRPCLib
import GRPC
import CakeAgentLib
import Synchronization

/// A daemon-observable event describing a VM process transition, fired from the same
/// process that spawned the per-VM `caked vmrun` child (i.e. `caked service listen`,
/// or `StartHandler.autostart`).
///
/// This exists so that `CakedLib` (which knows nothing about Vapor/IMDS) can still let the
/// `caked` daemon executable (which owns the IMDS HTTP server) learn when a VM starts or
/// stops, without CakedLib depending on the daemon layer or a new bespoke IPC channel.
public enum VMLifecycleEvent: Sendable {
	/// A VM was started (or found already running at daemon startup) and its main-network
	/// IP has been resolved. `runMode` is included so a handler can independently reload
	/// the VM's `CakeConfig` (e.g. to read `imdsMacAddress`, which may only just have been
	/// persisted by the child process at this point).
	case started(location: VMLocation, runMode: Utils.RunMode)

	/// The VM's `caked vmrun` process has exited, for any reason (clean stop, crash, kill).
	case stopped(location: VMLocation, runMode: Utils.RunMode)
}

/// Process-wide hook that lets the daemon layer observe VM lifecycle transitions that
/// happen inside `CakedLib` (`StartHandler`). Multiple independent subscribers are
/// supported (unlike a single mutable handler slot, which one subscriber calling
/// `addHandler` would otherwise silently kick another off) — modeled after
/// `GrandCentralDispatch`'s multi-listener fan-out, the codebase's other daemon-wide
/// VM-state observation mechanism.
public enum VMLifecycleHooks {
	public typealias Handler = @Sendable (VMLifecycleEvent) -> Void
	public typealias HandlerID = UUID

	private static let handlers: Mutex<[HandlerID: Handler]> = Mutex([:])

	/// Registers `handler` and returns a token to later remove it with `removeHandler(_:)`.
	@discardableResult
	public static func addHandler(_ handler: @escaping Handler) -> HandlerID {
		let id = HandlerID()

		Self.handlers.withLock { $0[id] = handler }

		return id
	}

	public static func removeHandler(_ id: HandlerID) {
		Self.handlers.withLock { _ = $0.removeValue(forKey: id) }
	}

	static func notify(_ event: VMLifecycleEvent) {
		let current = Self.handlers.withLock { $0 }

		current.values.forEach { $0(event) }
	}

	/// Notifies this process's own subscribers and, unless the IMDS coordinator lives in the
	/// service (`USE_IMDS_COORDINATOR_IN_SERVICE`), the process running the `imds` network, which
	/// hosts it. Called by `StartHandler`, which knows when a `caked vmrun` child started (its IP
	/// resolved and persisted) and exited, whatever the reason — a crash or a `kill -9` included,
	/// which the VM process itself could never report.
	///
	/// A VM that doesn't go through `StartHandler` (record, provisioning, the app's embedded VMs, a
	/// guest-initiated shutdown) is reported by `VirtualMachine` itself, through `publish(_:waitingUpTo:)`.
	/// Both can report the same transition: the network registers and unregisters idempotently.
	///
	/// The network process receiving the event calls `notify(_:)` directly, never this, or the
	/// event would loop back to it.
	static func publish(_ event: VMLifecycleEvent, waitingUpTo timeout: TimeInterval = 0) {
		Self.notify(event)

		#if !USE_IMDS_COORDINATOR_IN_SERVICE
			Self.forwardToIMDSNetwork(event, waitingUpTo: timeout)
		#endif
	}

	#if !USE_IMDS_COORDINATOR_IN_SERVICE
		/// Sends `event` to the `imds` network's process. `waitingUpTo` blocks the calling thread (never an
		/// event loop) until the network answered, for a process that is about to exit.
		static func forwardToIMDSNetwork(_ event: VMLifecycleEvent, waitingUpTo timeout: TimeInterval = 0) {
			guard IMDSNetworkInterface.imdsEnabled else {
				return
			}

			let location: VMLocation
			let runMode: Utils.RunMode
			let kind: Vmnet_VMLifecycleEventRequest.Event

			switch event {
			case .started(let eventLocation, let eventRunMode):
				(location, runMode, kind) = (eventLocation, eventRunMode, .started)
			case .stopped(let eventLocation, let eventRunMode):
				(location, runMode, kind) = (eventLocation, eventRunMode, .stopped)
			}

			// Only Linux VMs get the imds NIC, so only they are of any interest to the coordinator.
			guard let config = try? location.config(), config.os == .linux else {
				return
			}

			let logger = Logger("VMLifecycleHooks")

			// The network may not be running (IMDS off, or not started yet): it registers the running VMs itself when it starts.
			guard let client = try? NetworksHandler.getVMNetControlClient(IMDSNetworkInterface.imdsNetworkName, runMode: runMode) else {
				logger.debug("IMDS network control socket unavailable, lifecycle event for \(location.name) not forwarded")
				return
			}

			let done = timeout > 0 ? DispatchSemaphore(value: 0) : nil

			client.vMLifecycleEvent(
				.with {
					$0.event = kind
					$0.vmName = location.name
				}
			).response.whenComplete { result in
				if case .failure(let error) = result {
					logger.debug("Failed to forward lifecycle event for \(location.name) to the IMDS network: \(error)")
				}

				_ = client.channel.close()
				done?.signal()
			}

			_ = done?.wait(timeout: .now() + timeout)
		}
	#endif
}
