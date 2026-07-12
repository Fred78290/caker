import Foundation
import GRPCLib
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
}
