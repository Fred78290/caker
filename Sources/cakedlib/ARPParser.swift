import Foundation
import System
import Synchronization

struct ARPEntry {
	let ipAddress: String
	let macAddress: String
	let interface: String
}

/// Public, allocation-cheap wrapper around the host's ARP cache. Used to resolve which
/// guest (by MAC address) currently owns a given source IP on a shared host-only network —
/// e.g. the IMDS network, where several VMs' guest NICs share one virtual switch and the
/// only way to tell them apart at the HTTP layer is the request's source IP.
public enum ARPResolver {
	/// Returns the current IPv4 address the host's ARP cache has for `macAddress`, if any.
	/// Backed by `ARPParser`'s 10s cache, so safe to call per-request.
	public static func ipAddress(forMACAddress macAddress: String) -> String? {
		(try? ARPParser())?[macAddress]
	}
}

class ARPParser: DHCPLeaseProvider {
	private struct CacheEntry {
		let timestamp: Date
		let arp: [String: ARPEntry]
	}

	// Keep ARP data fresh while avoiding spawning `/usr/sbin/arp` repeatedly during polling loops.
	private static let cacheTTL: TimeInterval = 10
	private static let cache: Mutex<CacheEntry?> = Mutex(nil)

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
		if let cachedArp = Self.freshCache() {
			return cachedArp
		}

		let output = try Shell.exec(FilePath("/usr/sbin/arp"), arguments: ["-an"]) { (exitCode, stdout, stderr) in
			if exitCode != 0 {
				throw ServiceError(String(localized: "Failed to run arp: \(exitCode) \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"))
			}
			
			return stdout
		}

		return Self.updateCache(Self.parseArp(arpOutput: output))
	}

	private static func freshCache() -> [String: ARPEntry]? {
		return self.cache.withLock {
			guard let cache = $0, Date().timeIntervalSince(cache.timestamp) < Self.cacheTTL else {
				return nil
			}

			return cache.arp
		}
	}

	private static func updateCache(_ arp: [String: ARPEntry]) -> [String: ARPEntry] {
		return self.cache.withLock {
			$0 = CacheEntry(timestamp: Date(), arp: arp)

			return arp
		}
	}
}
