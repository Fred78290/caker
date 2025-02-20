import Foundation
import SwiftRadix

struct DHCPLease {
	let ipAddress: String
	let macAddress: String
	let hostname: String
	let expireAt: Date
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
		return leases[macAddress]?.ipAddress
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
			result[lease.macAddress] = lease
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