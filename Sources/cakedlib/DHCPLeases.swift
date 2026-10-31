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
	func address(forHostname hostname: String, now: Date = Date()) -> String? {
		let name = hostname.lowercased()

		return self.allLeases
			.filter { $0.hostname?.lowercased() == name && $0.expireAt > now }
			.max { $0.expireAt < $1.expireAt }?
			.ipAddress
	}

	subscript(macAddress: String) -> String? {
		if let mac = String(macAddress: macAddress) {
			return leases[mac]?.ipAddress
		} else {
			// A DUID client identifier (`DHCPLease` keeps it lowercased, as vmnet writes it).
			return leases[macAddress.lowercased()]?.ipAddress
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
