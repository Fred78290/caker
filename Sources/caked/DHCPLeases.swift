import Foundation
import SwiftRadix

extension String {
	init?(macAddress: String) {
		let components = macAddress.split(separator: ":")

		if components.count == 6 {
			self = components.map{ String(format: "%02X", UInt8($0, radix: 16)!) }.joined(separator: ":")
		} else {
			return nil
		}
	}
}

struct DHCPLease {
	let ipAddress: String
	let macAddress: String
	let hostname: String
	let expireAt: Date

	init?(ipAddress: String, macAddress: String, hostname: String, expireAt: Date) {
		if let mac = String(macAddress: macAddress) {
			self.ipAddress = ipAddress
			self.macAddress = mac
			self.hostname = hostname
			self.expireAt = expireAt
		} else {
			return nil
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

	private static func parseLeases(_ filePath: String) throws -> [String:DHCPLease] {
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
			if result[lease.macAddress] == nil || result[lease.macAddress]!.expireAt < lease.expireAt {
				result[lease.macAddress] = lease
			}
		}
	}

	private static func createLease(from: [String: String]) -> DHCPLease? {
		guard let ipAddress = from["ip_address"],
		      let hwAddress = from["hw_address"],
		      let hostname = from["name"],
		      let lease = from["lease"] else {
			return nil
		}

		let hwAddressSplits = hwAddress.split(separator: ",").map { String($0) }

		guard hwAddressSplits.count == 2 else {
			return nil
		}

		guard let expiresAt = lease.hex?.value else {
			return nil
		}

		if let hwAddressProto = Int(hwAddressSplits[0]), hwAddressProto != ARPHRD_ETHER {
			return nil
		}

		let macAddress = String(hwAddressSplits[1])

		return DHCPLease(ipAddress: ipAddress, macAddress: macAddress, hostname: hostname, expireAt: Date(timeIntervalSince1970: TimeInterval(expiresAt)))
	}
}