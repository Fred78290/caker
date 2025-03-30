import Foundation

struct VZSharedNetwork: Codable {
	let netmask: String
	let dhcpStart: String
	let dhcpEnd: String
	let uuid: String?
	let nat66Prefix: String?

	private enum CodingKeys : String, CodingKey {
		case netmask = "netmask"
		case dhcpStart = "dhcp-start"
		case dhcpEnd = "dhcp-end"
		case uuid = "uuid"
		case nat66Prefix = "nat66-prefix"
	}
}

extension String {
	func isValidIP() -> Bool {
		let ipPattern = "^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"
		let regex = try? NSRegularExpression(pattern: ipPattern, options: [])
		let range = NSRange(location: 0, length: self.utf16.count)
		return regex?.firstMatch(in: self, options: [], range: range) != nil
	}

	func isValidCIDR() -> Bool {
		let cidrPattern = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})/(3[0-2]|[1-2]?[0-9])$"
		let regex = try? NSRegularExpression(pattern: cidrPattern, options: [])
		let range = NSRange(location: 0, length: self.utf16.count)
		return regex?.firstMatch(in: self, options: [], range: range) != nil
	}

	func netmaskToCidr() -> Int {
		let octets: [Int] = self.split(separator: ".").map({Int($0)!})
		var cidr: Int = 0

		for i in 0..<4 {
			cidr += (octets[i] == 255) ? 8 : (octets[i] == 254) ? 7 : (octets[i] == 252) ? 6 : (octets[i] == 248) ? 5 : (octets[i] == 240) ? 4 : (octets[i] == 224) ? 3 : (octets[i] == 192) ? 2 : (octets[i] == 128) ? 1 : (octets[i] == 0) ? 0 : -1
		}

		return cidr
	}
	
	func cidrToNetmask() -> String {
		var value = Int(self) ?? 0
		value = 0xFFFFFFFF ^ ((1 << (32 - value)) - 1)

		return "\((value >> 24) & 0xFF).\((value >> 16) & 0xFF).\((value >> 8) & 0xFF).\(value & 0xFF)"
	}
	
	func IPToInt() -> Int {
		let octets: [Int] = self.split(separator: ".").map({Int($0)!})
		var numValue: Int = 0

		for i in stride(from:3, through:0, by:-1) {
			numValue += octets[3-i] << (i * 8)
		}

		return numValue
	}
}

struct VZVMNetConfig: Codable {
	var sharedNetworks: [String:VZSharedNetwork]

	var sharedNetworkNames: [String] {
		return Array(sharedNetworks.keys)
	}

	private enum CodingKeys : String, CodingKey {
		case sharedNetworks = "networks"
	}

	static func networkInterfaces() -> [IP.Block<IP.V4>] {
		var ipAddresses: [IP.Block<IP.V4>] = []
		var addrList: UnsafeMutablePointer<ifaddrs>? = nil

		guard getifaddrs(&addrList) == 0, let firstAddr = addrList else {
			return []
		}

		defer {
			freeifaddrs(addrList)
		}

		for cursor in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
			let addrStr: String

			if let addr = cursor.pointee.ifa_addr, let netmask = cursor.pointee.ifa_netmask {
				let flags = Int32(cursor.pointee.ifa_flags)
				let interface = addr.pointee
				let addrFamily = interface.sa_family

				if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
					var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

					if addrFamily == UInt8(AF_INET) {
						if getnameinfo(addr, socklen_t(interface.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
							var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))

							if getnameinfo(netmask, socklen_t(netmask.pointee.sa_len), &netmaskName, socklen_t(netmaskName.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
								addrStr = "\(String(cString: hostname))/\(String(cString: netmaskName).netmaskToCidr())"
							} else {
								addrStr = String(cString: hostname)
							}

							if let ip:IP.Block<IP.V4> = .init(addrStr) {
								ipAddresses.append(ip)
							}
						}
					}
				}
			}

		}

		return ipAddresses
	}

	static func freeIP(segment: String) throws -> (String, String) {
		let networks = Self.networkInterfaces().map {
			IP.Block<IP.V4>(base: $0.base.zeroMasked(to: $0.bits), bits: $0.bits)
		}

		for value: UInt8 in 1..<255 {
			var base: [UInt8] = [192, 168, value, 0]
			let segment = segment.split(separator: ".").map { UInt8($0) ?? 0 }

			for i in 0..<segment.count {
				base[i] = segment[i]
			}

			let ip: IP.V4 = .init(base[0], base[1], base[2], base[3])

			if networks.first(where: { $0.contains(ip)}) == nil {
				return (String(format: "%d.%d.%d.%d", base[0], base[1], base[2], 1), String(format: "%d.%d.%d.%d", base[0], base[1], base[2], 254))
			}
		}
		
		throw ServiceError("No free network address available")
	}

	static func createNetwork(baseAddress: String, cidr: Int) throws -> VZSharedNetwork {
		let (gateway, dhcpEnd) = try freeIP(segment: baseAddress)

		return .init(netmask: "\(cidr)".cidrToNetmask(), dhcpStart: gateway, dhcpEnd: dhcpEnd, uuid: UUID().uuidString, nat66Prefix: nil)
	}

	init() throws {
		self.sharedNetworks = [
			"shared": try Self.createNetwork(baseAddress: "192.168", cidr: 24),
			"host": try Self.createNetwork(baseAddress: "172.\(Int.random(in: 16...31))", cidr: 24)
		]
	}

	init(fromJSON: Data) throws {
		self = try JSONDecoder().decode(VZVMNetConfig.self, from: fromJSON)
	}

	init(fromURL: URL) throws {
		self = try Self(fromJSON: try Data(contentsOf: fromURL))
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.sharedNetworks = try container.decodeIfPresent([String:VZSharedNetwork].self, forKey: .sharedNetworks) ?? [:]
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encodeIfPresent(sharedNetworks, forKey: .sharedNetworks)
	}

	func save(toURL: URL) throws {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		try encoder.encode(self).write(to: toURL)
	}
}
