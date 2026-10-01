import CakedLib
import Foundation
import Synchronization

/// Tracks the current NAT-network IP for every running, resolvable VM — both by compose identity
/// (`(project, service)`, for `<service>.<project>.<domain>` queries) and by plain VM name (for
/// `<vmname>.<domain>` queries, covering every running VM, compose-managed or not). Populated by
/// `ComposeDNSCoordinator`'s poll-based `refreshFromDisk()` (and, as an accelerant, its
/// `VMLifecycleHooks` handler) — this type itself has no idea how a VM's IP is discovered, it
/// just holds whatever it's told.
public final class ComposeDNSRegistry: Sendable {
	private struct ServiceKey: Hashable {
		let project: String
		let service: String
	}

	private struct State {
		var services: [ServiceKey: String] = [:]
		var vms: [String: String] = [:]
	}

	private let state: Mutex<State> = Mutex(State())

	public init() {}

	public var isEmpty: Bool {
		self.state.withLock { $0.services.isEmpty && $0.vms.isEmpty }
	}

	public func register(project: String, service: String, ip: String) {
		self.state.withLock { $0.services[ServiceKey(project: project, service: service)] = ip }
	}

	@discardableResult
	public func unregister(project: String, service: String) -> Bool {
		self.state.withLock { $0.services.removeValue(forKey: ServiceKey(project: project, service: service)) != nil }
	}

	/// Atomically replaces both maps with `services`/`vms` — the poll-based discovery path
	/// (`ComposeDNSCoordinator.refreshFromDisk()`) uses this instead of individually
	/// registering/unregistering, since a full rescan already knows the complete, current set on
	/// every pass: swapping both maps in one step can't race with itself the way "diff, then
	/// issue N individual register/unregister calls" could, and there's nothing to keep in sync
	/// between an old and new snapshot — the new one simply replaces the old. `vms` is keyed
	/// case-insensitively (lowercased on the way in), matching `ComposeDNS.parseQueryName(_:)`'s
	/// own lowercasing of the query name it parses.
	public func replaceAll(services: [(project: String, service: String, ip: String)], vms: [(name: String, ip: String)]) {
		self.state.withLock { state in
			state.services = Dictionary(uniqueKeysWithValues: services.map { (ServiceKey(project: $0.project, service: $0.service), $0.ip) })
			state.vms = Dictionary(uniqueKeysWithValues: vms.map { ($0.name.lowercased(), $0.ip) })
		}
	}

	/// The current IP for `name`, if it names something this registry knows about — `nil` for a
	/// compose service or VM that isn't currently registered (not currently running, or — for a
	/// compose service — not compose-managed at all).
	public func address(for name: ComposeDNS.QueryName) -> String? {
		self.state.withLock { state in
			switch name {
			case .service(let serviceName):
				return state.services[ServiceKey(project: serviceName.project, service: serviceName.service)]
			case .vm(let vmName):
				return state.vms[vmName.lowercased()]
			}
		}
	}
}
