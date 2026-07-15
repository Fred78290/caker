import Darwin
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

	/// Same as `ipAddress(forMACAddress:)`, but when the ARP cache has no entry, sends a
	/// single broadcast ICMP echo on `interfaceName`'s subnet before giving up.
	///
	/// The host's own ARP cache is only ever populated by traffic the host itself has seen —
	/// which never happens for a bridged VM the host has no reason to talk IP to directly
	/// (unlike, say, a host-only network where the guest must talk to the host as its
	/// gateway). Broadcasting forces every live host on that L2 segment, including such a
	/// VM, to ARP-resolve *this* machine in order to reply — and the kernel learns their
	/// (IP, MAC) from that inbound ARP request as a side effect, without us ever needing to
	/// already know their IP. `interfaceName` is a BSD interface name (e.g. `en0`), matching
	/// what `getifaddrs` reports; pass `nil` to skip the probe entirely.
	public static func ipAddress(forMACAddress macAddress: String, proddingInterface interfaceName: String?) -> String? {
		if let ip = ipAddress(forMACAddress: macAddress) {
			return ip
		}

		guard let interfaceName, let broadcast = BroadcastProbe.broadcastAddress(forInterface: interfaceName) else {
			return nil
		}

		BroadcastProbe.ping(broadcastAddress: broadcast)
		ARPParser.invalidateCache()

		return ipAddress(forMACAddress: macAddress)
	}
}

/// Sends a single best-effort broadcast ICMP echo to force every live host on a subnet to
/// ARP-resolve this machine, populating this host's own ARP cache with their (IP, MAC) as a
/// side effect. Used only as a last resort by `ARPResolver` when a passive ARP-cache lookup
/// comes up empty.
private enum BroadcastProbe {
	/// The IPv4 broadcast address (`address | ~netmask`) of the named interface, or `nil` if
	/// the interface doesn't exist or has no IPv4 address configured.
	static func broadcastAddress(forInterface name: String) -> String? {
		var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?

		guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
		defer { freeifaddrs(ifaddrPtr) }

		var cursor: UnsafeMutablePointer<ifaddrs>? = first

		while let ifa = cursor {
			defer { cursor = ifa.pointee.ifa_next }

			guard String(cString: ifa.pointee.ifa_name) == name,
				let addrPtr = ifa.pointee.ifa_addr,
				addrPtr.pointee.sa_family == sa_family_t(AF_INET),
				let netmaskPtr = ifa.pointee.ifa_netmask
			else { continue }

			let address = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
			let netmask = netmaskPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
			var broadcast = in_addr(s_addr: address | ~netmask)

			var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))

			guard inet_ntop(AF_INET, &broadcast, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }

			return String(cString: buffer)
		}

		return nil
	}

	/// Fires one ICMP echo at `broadcastAddress` (macOS allows unprivileged ICMP echo over
	/// `SOCK_DGRAM`/`IPPROTO_ICMP`) and gives replies — and the kernel's opportunistic ARP
	/// learning from them — a brief moment to land before returning.
	static func ping(broadcastAddress: String) {
		let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)

		guard fd >= 0 else { return }
		defer { close(fd) }

		var allowBroadcast: Int32 = 1
		setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &allowBroadcast, socklen_t(MemoryLayout<Int32>.size))

		var addr = sockaddr_in()
		addr.sin_family = sa_family_t(AF_INET)
		inet_pton(AF_INET, broadcastAddress, &addr.sin_addr)

		var packet = [UInt8](repeating: 0, count: 8)
		packet[0] = 8  // ICMP_ECHO

		let identifier = UInt16.random(in: 0...UInt16.max)
		packet[4] = UInt8(identifier >> 8)
		packet[5] = UInt8(identifier & 0xff)
		packet[7] = 1  // sequence

		var checksum: UInt32 = 0
		for i in stride(from: 0, to: packet.count, by: 2) {
			checksum += UInt32(packet[i]) << 8 | UInt32(packet[i + 1])
		}
		while checksum >> 16 != 0 { checksum = (checksum & 0xffff) + (checksum >> 16) }

		let sum = UInt16(~checksum & 0xffff)
		packet[2] = UInt8(sum >> 8)
		packet[3] = UInt8(sum & 0xff)

		_ = withUnsafePointer(to: &addr) { ptr in
			ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
				sendto(fd, packet, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
			}
		}

		Thread.sleep(forTimeInterval: 0.3)
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

	/// Drops the cached `arp -an` snapshot so the next lookup shells out again instead of
	/// returning a stale (pre-probe) table. Used by `ARPResolver`'s broadcast-probing overload
	/// right after it prods the network, so the immediate re-check isn't served from cache.
	static func invalidateCache() {
		self.cache.withLock { $0 = nil }
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
