import Foundation
import System

struct ARPEntry {
	let ipAddress: String
	let macAddress: String
	let interface: String
}

class ARPParser: DHCPLeaseProvider {
	private struct CacheEntry {
		let timestamp: Date
		let arp: [String: ARPEntry]
	}

	private static let cacheTTL: TimeInterval = 10
	private static let cacheLock = NSLock()
	private static var cache: CacheEntry?

	let arp: [String: ARPEntry]

	init() throws {
		self.arp = try Self.cachedArp()
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

	private static func cachedArp() throws -> [String: ARPEntry] {
		Self.cacheLock.lock()
		if let cache = Self.cache, Date().timeIntervalSince(cache.timestamp) < Self.cacheTTL {
			Self.cacheLock.unlock()
			return cache.arp
		}
		Self.cacheLock.unlock()

		let parsedArp = Self.parseArp(arpOutput: try Shell.exec(FilePath("/usr/sbin/arp"), arguments: ["-an"]))

		Self.cacheLock.lock()
		Self.cache = CacheEntry(timestamp: Date(), arp: parsedArp)
		Self.cacheLock.unlock()

		return parsedArp
	}
}
