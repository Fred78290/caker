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
/// happen inside `CakedLib` (`StartHandler`). At most one handler is installed at a time —
/// only the `caked service listen` process installs one.
public enum VMLifecycleHooks {
	public typealias Handler = @Sendable (VMLifecycleEvent) -> Void

	private static let handler: Mutex<Handler?> = Mutex(nil)

	public static func setHandler(_ handler: Handler?) {
		Self.handler.withLock { $0 = handler }
	}

	static func notify(_ event: VMLifecycleEvent) {
		let current = Self.handler.withLock { $0 }

		current?(event)
	}
}
