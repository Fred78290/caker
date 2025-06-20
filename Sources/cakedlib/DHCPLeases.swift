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
	let hostname: String
	let expireAt: Date

	init?(hwAddressProto: UInt8, ipAddress: String, hwAddressAddress: String, hostname: String, expireAt: Date) {
		guard hwAddressProto != ARPHRD_ETHER && hwAddressProto != 255 else {
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

	init() throws {
		self.leases = try Self.parseLeases("/var/db/dhcpd_leases")
	}

	subscript(macAddress: String) -> String? {
		if let mac = String(macAddress: macAddress) {
			return leases[mac]?.ipAddress
		} else {
			return nil
		}
	}

	private static func parseLeases(_ filePath: String) throws -> [String: DHCPLease] {
		let content = try String(contentsOfFile: filePath)
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
				if let lease = createLease(from: currentLease) {
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

		return leases.reduce(into: [:]) { result, lease in
			if result[lease.hwAddressAddress] == nil || result[lease.hwAddressAddress]!.expireAt < lease.expireAt {
				result[lease.hwAddressAddress] = lease
			}
		}
	}

	private static func createLease(from: [String: String]) -> DHCPLease? {
		guard let ipAddress = from["ip_address"],
			let hwAddress = from["hw_address"],
			let hostname = from["name"],
			let lease = from["lease"]
		else {
			return nil
		}

		let hwAddressSplits = hwAddress.split(separator: ",").map { String($0) }

		guard hwAddressSplits.count == 2 else {
			return nil
		}

		guard let expiresAt = lease.hex?.value else {
			return nil
		}

		guard let hwAddressProto = UInt8(hwAddressSplits[0]), hwAddressProto == ARPHRD_ETHER || hwAddressProto == 255 else {
			return nil
		}

		let hwAddressAddress = String(hwAddressSplits[1])

		return DHCPLease(hwAddressProto: hwAddressProto, ipAddress: ipAddress, hwAddressAddress: hwAddressAddress, hostname: hostname, expireAt: Date(timeIntervalSince1970: TimeInterval(expiresAt)))
	}
}
