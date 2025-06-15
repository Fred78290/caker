import Foundation

struct ARPEntry {
	let ipAddress: String
	let macAddress: String
	let interface: String
}

class ARPParser: DHCPLeaseProvider {
	let arp: [String: ARPEntry]

	init() throws {
		self.arp = Self.parseArp(arpOutput: try Shell.bash(to: "/usr/sbin/arp", arguments: ["-an"]))
	}

	subscript(macAddress: String) -> String? {
		guard let macAddress = String(macAddress: macAddress) else {
			return nil
		}

		return arp[macAddress]?.ipAddress
	}

	private static func parseArp(arpOutput: String) -> [String: ARPEntry] {
		var entries = [ARPEntry]()
		let lines = arpOutput.split(separator: "\n")

		for line in lines {
			let components = line.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", omittingEmptySubsequences: true)

			if components.count >= 8 {
				if let hwAddress = String(macAddress: String(components[3])) {
					let ipAddress = String(components[1].trimmingCharacters(in: CharacterSet(charactersIn: "()")))
					let interface = String(components[5])
					let entry = ARPEntry(ipAddress: ipAddress, macAddress: hwAddress, interface: interface)

					entries.append(entry)
				}
			}
		}

		return entries.reduce(into: [:]) { result, entry in
			result[entry.macAddress] = entry
		}
	}
}
