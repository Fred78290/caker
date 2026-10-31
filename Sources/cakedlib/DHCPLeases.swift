import Foundation
import SwiftRadix

extension String {
	init?(macAddress: String) {
		let components = macAddress.split(separator: ":")

		if components.count == 6 {
			self = components.map { String(format: "%02X", UInt8($0, radix: 16)!) }.joined(separator: ":")
		} else {
			return nil
		}
	}
}

struct DHCPLease {
	let hwAddressProto: UInt8
	let ipAddress: String
	let hwAddressAddress: String
	let hostname: String?
	let expireAt: Date

	init?(hwAddressProto: UInt8, ipAddress: String, hwAddressAddress: String, hostname: String?, expireAt: Date) {
		guard hwAddressProto == ARPHRD_ETHER || hwAddressProto == 255 else {
			return nil
		}

		self.hwAddressProto = hwAddressProto
		self.ipAddress = ipAddress
		self.hostname = hostname
		self.expireAt = expireAt

		if hwAddressProto == ARPHRD_ETHER {
			if let mac = String(macAddress: hwAddressAddress) {
				self.hwAddressAddress = mac
			} else {
				return nil
			}
		} else {
			self.hwAddressAddress = hwAddressAddress.lowercased()
		}
	}
}

protocol DHCPLeaseProvider {
	subscript(macAddress: String) -> String? { get }
}

class DHCPLeaseParser: DHCPLeaseProvider {
	private let leases: [String: DHCPLease]
	private let allLeases: [DHCPLease]

	init() throws {
		let content = try String(contentsOfFile: "/var/db/dhcpd_leases", encoding: .ascii)

		self.allLeases = Self.parseLeases(content: content)
		self.leases = Self.newestByAddress(self.allLeases)
	}

	/// Builds a parser from the text of a `dhcpd_leases` file, for tests.
	init(content: String) {
		self.allLeases = Self.parseLeases(content: content)
		self.leases = Self.newestByAddress(self.allLeases)
	}

	/// The address of the newest unexpired lease the guest asked for under `hostname` (the `name=` field).
	/// A DHCP client that identifies itself with a DUID (dhcpcd on Alpine and Gentoo) has a lease whose
	/// key is that DUID, not the VM's MAC address, so the MAC lookup never finds it.
	///
	/// `network` (`a.b.c.d/nn`) restricts the match to leases inside that subnet: the lease file is shared by
	/// every vmnet network, so without it an unexpired lease of the same name on another network (IMDS) could win.
	func address(forHostname hostname: String, in network: String? = nil, now: Date = Date()) -> String? {
		let name = hostname.lowercased()

		return self.allLeases
			.filter { $0.hostname?.lowercased() == name && $0.expireAt > now && Self.contains(network, $0.ipAddress) }
			.max { $0.expireAt < $1.expireAt }?
			.ipAddress
	}

	private static func ipv4(_ address: String) -> UInt32? {
		let octets = address.split(separator: ".", omittingEmptySubsequences: false).map { UInt8($0) }

		guard octets.count == 4, octets.allSatisfy({ $0 != nil }) else {
			return nil
		}

		return octets.reduce(UInt32(0)) { ($0 << 8) | UInt32($1!) }
	}

	/// `true` when `network` is nil, or `address` belongs to the `a.b.c.d/nn` subnet.
	private static func contains(_ network: String?, _ address: String) -> Bool {
		guard let network else {
			return true
		}

		let parts = network.split(separator: "/", omittingEmptySubsequences: false)

		guard parts.count == 2, let base = ipv4(String(parts[0])), let bits = Int(parts[1]), (0...32).contains(bits), let ip = ipv4(address) else {
			return false
		}

		let mask: UInt32 = bits == 0 ? 0 : ~UInt32(0) << UInt32(32 - bits)

		return (base & mask) == (ip & mask)
	}

	subscript(macAddress: String) -> String? {
		if let mac = String(macAddress: macAddress) {
			return leases[mac]?.ipAddress
		} else {
			// A DUID client identifier (`DHCPLease` keeps it lowercased, as vmnet writes it).
			// An expired lease must not end the lookup: the caller has other sources to try.
			guard let lease = leases[macAddress.lowercased()], lease.expireAt > Date() else {
				return nil
			}

			return lease.ipAddress
		}
	}

	private static func parseLeases(content: String) -> [DHCPLease] {
		var leases = [DHCPLease]()
		let lines = content.split(separator: "\n")

		var currentLease: [String: String] = [:]
		var inBody = false

		for input in lines {
			let line = input.trimmingCharacters(in: .whitespacesAndNewlines)

			if line == "{" {
				currentLease = [:]
				inBody = true
			} else if line == "}" {
				if let lease = createLease(currentLease) {
					leases.append(lease)
				}
				currentLease = [:]
				inBody = false
			} else if line.isEmpty {
				continue
			} else if inBody {
				let components = line.split(separator: "=", maxSplits: 1).map { String($0) }

				if components.count == 2 {
					currentLease[components[0]] = components[1]
				}
			}
		}

		return leases
	}

	private static func newestByAddress(_ leases: [DHCPLease]) -> [String: DHCPLease] {
		leases.reduce(into: [:]) { result, lease in
			if result[lease.hwAddressAddress] == nil || result[lease.hwAddressAddress]!.expireAt < lease.expireAt {
				result[lease.hwAddressAddress] = lease
			}
		}
	}

	private static func createLease(_ from: [String: String]) -> DHCPLease? {
		guard let ipAddress = from["ip_address"], let hwAddress = from["hw_address"], let lease = from["lease"] else {
			return nil
		}

		let hostname = from["name"]
		let hwAddressSplits = hwAddress.split(separator: ",").map { String($0) }

		guard hwAddressSplits.count == 2 else {
			return nil
		}

		guard let expiresAt = lease.hex?.value else {
			return nil
		}

		// The type is written in hex by vmnet: "1" for Ethernet, "ff" for a DUID client identifier.
		guard let hwAddressProto = UInt8(hwAddressSplits[0], radix: 16), hwAddressProto == ARPHRD_ETHER || hwAddressProto == 255 else {
			return nil
		}

		let hwAddressAddress = String(hwAddressSplits[1])

		return DHCPLease(hwAddressProto: hwAddressProto, ipAddress: ipAddress, hwAddressAddress: hwAddressAddress, hostname: hostname, expireAt: Date(timeIntervalSince1970: TimeInterval(expiresAt)))
	}
}
