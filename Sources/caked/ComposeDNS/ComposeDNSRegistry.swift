import CakedLib
import Foundation
import Synchronization

/// Tracks the current NAT-network IP for every running compose-tagged VM, keyed by
/// `(project, service)`. Populated/cleared by `ComposeDNSCoordinator` from `VMLifecycleHooks`
/// events — this type itself has no idea how a VM's IP is discovered, it just holds whatever
/// it's told.
public final class ComposeDNSRegistry: Sendable {
	private struct Key: Hashable {
		let project: String
		let service: String
	}

	private let entries: Mutex<[Key: String]> = Mutex([:])

	public init() {}

	public var isEmpty: Bool {
		self.entries.withLock { $0.isEmpty }
	}

	public func register(project: String, service: String, ip: String) {
		self.entries.withLock { $0[Key(project: project, service: service)] = ip }
	}

	@discardableResult
	public func unregister(project: String, service: String) -> Bool {
		self.entries.withLock { $0.removeValue(forKey: Key(project: project, service: service)) != nil }
	}

	/// The current IP for `name`, if it names a service this registry knows about — `nil` for
	/// anything outside the synthetic domain (see `ComposeDNS.parseServiceName(_:)`) or naming a
	/// service that isn't currently registered (not compose-managed, or not running).
	public func address(for name: ComposeDNS.ServiceName) -> String? {
		self.entries.withLock { $0[Key(project: name.project, service: name.service)] }
	}
}
