import CakeAgentLib
import Foundation
import Synchronization

/// The lease table of **one** network: allocation out of its pool plus persistence in a `dhcpd_leases`-format file
/// that lives in the network's own directory (`<CAKE_HOME>/net/<name>/dhcpd_leases`), so leases of different
/// networks are independent of each other and of the host's `/var/db/dhcpd_leases`.
///
/// The file uses the format vmnet's bootpd writes, which is what `DHCPLeaseParser` reads, so everything that
/// looks an address up by MAC/DUID or hostname works unchanged.
public final class DHCPLeaseStore: @unchecked Sendable {
	public struct Lease: Equatable, Sendable {
		public var hwAddress: String
		public var address: UInt32
		public var hostname: String?
		public var expiresAt: Date
		/// The hardware address (`chaddr`) the client used, `aa:bb:..`. The lease key (`hwAddress`) is the client
		/// identifier, which can change for the same machine: an installer asks with its MAC, the installed system
		/// with a DUID. The MAC is what ties both to one address.
		public var macAddress: String? = nil

		/// The MAC of the client, from `macAddress` or, for an Ethernet key (`1,<mac>`), from the key itself.
		var effectiveMAC: String? {
			if let macAddress { return macAddress }

			return hwAddress.hasPrefix("1,") ? String(hwAddress.dropFirst(2)) : nil
		}
	}

	public static let leaseFilename = "dhcpd_leases"

	/// An offer holds its address for this long while the client decides.
	static let offerHold: TimeInterval = 60
	/// A declined address (the client found it in use) is not offered again for this long.
	static let declineHold: TimeInterval = 600
	/// Expired leases are kept this long after expiry so the same client gets the same address back.
	static let expiredRetention: TimeInterval = 7 * 24 * 3600

	public let gateway: UInt32
	public let poolStart: UInt32
	public let poolEnd: UInt32
	public let fileURL: URL?

	private struct State {
		var leases: [String: Lease] = [:]
		var offers: [String: (address: UInt32, expiresAt: Date)] = [:]
		var declined: [UInt32: Date] = [:]
		/// Where the next scan for a free address starts, so addresses are handed out in turn and an address freed
		/// a moment ago isn't the first one reused. `nil` = start of the pool.
		var cursor: UInt32? = nil
	}

	private let state = Mutex(State())
	private let now: @Sendable () -> Date
	private let leaseDuration: TimeInterval

	/// - Parameters:
	///   - poolStart/poolEnd: inclusive range handed out; `gateway` is skipped inside it.
	///   - fileURL: where leases are persisted, `nil` keeps them in memory only (tests).
	public init(gateway: UInt32, poolStart: UInt32, poolEnd: UInt32, leaseDuration: TimeInterval, fileURL: URL?, now: @escaping @Sendable () -> Date = { Date() }) {
		self.gateway = gateway
		self.poolStart = poolStart
		self.poolEnd = poolEnd
		self.leaseDuration = leaseDuration
		self.fileURL = fileURL
		self.now = now

		self.load()
	}

	public var leaseTime: TimeInterval {
		self.leaseDuration
	}

	public func lease(for hwAddress: String) -> Lease? {
		self.state.withLock { $0.leases[hwAddress] }
	}

	public var activeLeases: [Lease] {
		let current = self.now()

		return self.state.withLock { $0.leases.values.filter { $0.expiresAt > current } }
	}

	// MARK: - Allocation

	/// The address to offer `hwAddress`: its previous one if still free (also the one of the same machine under another
	/// client identifier, see `Lease.macAddress`), then `requested`, then the next free address after the last one
	/// handed out, wrapping around the pool.
	public func offer(hwAddress: String, macAddress: String? = nil, requested: UInt32?) -> UInt32? {
		let current = self.now()

		return self.state.withLock { state in
			var candidates: [UInt32] = []

			if let previous = state.leases[hwAddress]?.address {
				candidates.append(previous)
			}

			if let mac = macAddress ?? state.leases[hwAddress]?.effectiveMAC, let sibling = self.sameMachineLease(of: hwAddress, mac: mac, in: state) {
				candidates.append(sibling.address)
			}

			if let requested {
				candidates.append(requested)
			}

			for candidate in candidates where self.isFree(candidate, for: hwAddress, mac: macAddress, in: state, at: current) {
				state.offers[hwAddress] = (candidate, current.addingTimeInterval(Self.offerHold))
				return candidate
			}

			// An address that belonged to a client (even an expired lease) is only reused once nothing else is left,
			// so that a client coming back later still finds its own.
			let remembered = Set(state.leases.values.map(\.address))

			for avoidRemembered in [true, false] {
				if let address = self.scan(for: hwAddress, mac: macAddress, in: state, at: current, skipping: avoidRemembered ? remembered : []) {
					state.offers[hwAddress] = (address, current.addingTimeInterval(Self.offerHold))
					state.cursor = address >= self.poolEnd ? nil : address + 1
					return address
				}
			}

			return nil
		}
	}

	/// First free pool address from the cursor, wrapping around once.
	private func scan(for hwAddress: String, mac: String?, in state: State, at current: Date, skipping: Set<UInt32>) -> UInt32? {
		guard self.poolStart <= self.poolEnd else { return nil }

		let first = min(max(state.cursor ?? self.poolStart, self.poolStart), self.poolEnd)
		var address = first

		repeat {
			if skipping.contains(address) == false, self.isFree(address, for: hwAddress, mac: mac, in: state, at: current) {
				return address
			}

			address = address >= self.poolEnd ? self.poolStart : address + 1
		} while address != first

		return nil
	}

	/// The newest lease of the same machine (same MAC) held under another client identifier.
	private func sameMachineLease(of hwAddress: String, mac: String, in state: State) -> Lease? {
		state.leases.values
			.filter { $0.hwAddress != hwAddress && $0.effectiveMAC == mac }
			.max { $0.expiresAt < $1.expiresAt }
	}

	/// Commits `address` to `hwAddress`. `false` when it is outside the pool or already held by another client.
	@discardableResult
	public func commit(hwAddress: String, macAddress: String? = nil, address: UInt32, hostname: String?) -> Bool {
		let current = self.now()

		let committed = self.state.withLock { state -> Bool in
			guard self.isFree(address, for: hwAddress, mac: macAddress, in: state, at: current) else {
				return false
			}

			let mac = macAddress ?? state.leases[hwAddress]?.effectiveMAC
			var inheritedHostname = state.leases[hwAddress]?.hostname

			// The same machine under another identifier (installer MAC, then installed system DUID): it takes over.
			if let mac {
				let siblings = state.leases.filter { $0.key != hwAddress && $0.value.effectiveMAC == mac }

				for (key, lease) in siblings {
					inheritedHostname = inheritedHostname ?? lease.hostname
					state.leases[key] = nil
					state.offers[key] = nil
				}
			}

			// Expired leases of other clients on this very address are of no use any more.
			let stale = state.leases.filter { $0.key != hwAddress && $0.value.address == address && $0.value.expiresAt <= current }.keys

			for key in stale {
				state.leases[key] = nil
			}

			state.offers[hwAddress] = nil
			state.leases[hwAddress] = Lease(hwAddress: hwAddress, address: address, hostname: hostname == nil ? inheritedHostname : (Self.isValidHostname(hostname) ? hostname : nil), expiresAt: current.addingTimeInterval(self.leaseDuration), macAddress: mac)

			return true
		}

		if committed {
			self.save()
		}

		return committed
	}

	public func release(hwAddress: String) {
		let current = self.now()

		self.state.withLock { state in
			state.offers[hwAddress] = nil

			// Keep the entry (stickiness) but end it.
			if var lease = state.leases[hwAddress] {
				lease.expiresAt = current
				state.leases[hwAddress] = lease
			}
		}

		self.save()
	}

	public func decline(hwAddress: String, address: UInt32) {
		let current = self.now()

		self.state.withLock { state in
			state.offers[hwAddress] = nil

			if state.leases[hwAddress]?.address == address {
				state.leases[hwAddress] = nil
			}

			state.declined[address] = current.addingTimeInterval(Self.declineHold)
		}

		self.save()
	}

	/// Whether `address` belongs to the pool (and isn't the gateway).
	public func isInPool(_ address: UInt32) -> Bool {
		address >= self.poolStart && address <= self.poolEnd && address != self.gateway
	}

	private func isFree(_ address: UInt32, for hwAddress: String, mac: String? = nil, in state: State, at current: Date) -> Bool {
		let mac = mac ?? state.leases[hwAddress]?.effectiveMAC

		guard self.isInPool(address) else {
			return false
		}

		if let until = state.declined[address], until > current {
			return false
		}

		for (key, lease) in state.leases where key != hwAddress && lease.address == address && lease.expiresAt > current {
			// The same machine under another client identifier doesn't compete with itself.
			if let mac, lease.effectiveMAC == mac { continue }

			return false
		}

		for (key, offer) in state.offers where key != hwAddress && offer.address == address && offer.expiresAt > current {
			return false
		}

		return true
	}

	// MARK: - Persistence

	/// The hostname comes from the client (option 12) and ends up in a line-based file read back by `load()` and by
	/// `DHCPLeaseParser`: a name holding a newline would forge extra entries (a lease for another client, or a pool
	/// address nobody can get). Only the characters of a host name, at most 63 bytes, are accepted; anything else is dropped.
	static func isValidHostname(_ name: String?) -> Bool {
		guard let name, name.isEmpty == false, name.utf8.count <= 63 else { return false }

		return name.utf8.allSatisfy { ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x41 && $0 <= 0x5a) || ($0 >= 0x61 && $0 <= 0x7a) || $0 == 0x2d || $0 == 0x2e || $0 == 0x5f }
	}

	func render(at current: Date) -> String {
		self.state.withLock { state in
			state.leases.values
				.filter { $0.expiresAt.addingTimeInterval(Self.expiredRetention) > current }
				.sorted { $0.address < $1.address }
				.map { lease in
					var lines = ["{"]

					if let name = lease.hostname, Self.isValidHostname(name) {
						lines.append("\tname=\(name)")
					}

					lines.append("\tip_address=\(DHCPAddress.string(lease.address))")
					lines.append("\thw_address=\(lease.hwAddress)")
					lines.append("\tidentifier=\(lease.hwAddress)")

					// Not part of vmnet's format (readers ignore it): what ties a DUID lease to the machine's MAC.
					if let mac = lease.macAddress {
						lines.append("\tchaddr=\(mac)")
					}

					lines.append("\tlease=0x\(String(Int(lease.expiresAt.timeIntervalSince1970), radix: 16))")
					lines.append("}")

					return lines.joined(separator: "\n")
				}
				.joined(separator: "\n") + "\n"
		}
	}

	private func save() {
		guard let fileURL else { return }

		do {
			try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			try Data(self.render(at: self.now()).utf8).write(to: fileURL, options: .atomic)
			// Read by non-root processes (caker, caked in user mode), like /var/db/dhcpd_leases.
			try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path(percentEncoded: false))
		} catch {
			Logger("DHCPLeaseStore").error("Unable to save leases to \(fileURL.path(percentEncoded: false)): \(error)")
		}
	}

	private func load() {
		guard let fileURL, let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }

		var entry: [String: String] = [:]
		var leases: [String: Lease] = [:]

		for raw in content.split(separator: "\n") {
			let line = raw.trimmingCharacters(in: .whitespaces)

			if line == "{" {
				entry = [:]
			} else if line == "}" {
				if let ip = entry["ip_address"].flatMap(DHCPAddress.parse), let hw = entry["hw_address"], let expiry = entry["lease"].flatMap({ Int($0.dropFirst(2), radix: 16) }) {
					leases[hw] = Lease(hwAddress: hw, address: ip, hostname: entry["name"], expiresAt: Date(timeIntervalSince1970: TimeInterval(expiry)), macAddress: entry["chaddr"])
				}
			} else if let separator = line.firstIndex(of: "=") {
				entry[String(line[..<separator])] = String(line[line.index(after: separator)...])
			}
		}

		self.state.withLock { state in
			state.leases = leases

			// Carry on after the most recently granted lease (the lease time is constant, so the latest expiry is the latest grant).
			if let latest = leases.values.filter({ self.isInPool($0.address) }).max(by: { $0.expiresAt < $1.expiresAt }) {
				state.cursor = latest.address >= self.poolEnd ? nil : latest.address + 1
			}
		}
	}
}
