import Foundation
import Virtualization
import GRPCLib

public struct VZSharedNetwork: Codable, Equatable {
	public let mode: VMNetMode
	public let netmask: String
	public let dhcpStart: String
	public let dhcpEnd: String
	public let dhcpLease: Int32?
	public let interfaceID: String
	public let nat66Prefix: String?

	public func toBridgedNetwork(name: String) -> BridgedNetwork {
		let cidr = self.netmask.netmaskToCidr()

		return BridgedNetwork(name: name,
							  mode: .init(from: self.mode),
							  description: self.mode == .host ? "Hosted network" : "Shared network",
							  gateway: "\(self.dhcpStart)/\(cidr)",
							  dhcpEnd: "\(self.dhcpEnd)/\(cidr)",
							  dhcpLease: self.dhcpLease != nil ? "\(self.dhcpLease!)" : "",
							  interfaceID: self.interfaceID,
							  endpoint: "")
	}

	public init(
		mode: VMNetMode = .bridged,
		netmask: String,
		dhcpStart: String,
		dhcpEnd: String,
		dhcpLease: Int32? = nil,
		interfaceID: String = "en0",
		nat66Prefix: String? = nil
	) {
		self.mode = mode
		self.netmask = netmask
		self.dhcpStart = dhcpStart
		self.dhcpEnd = dhcpEnd
		self.dhcpLease = dhcpLease
		self.interfaceID = interfaceID
		self.nat66Prefix = nat66Prefix
	}

	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.mode == rhs.mode && lhs.netmask == rhs.netmask && lhs.dhcpStart == rhs.dhcpStart && lhs.dhcpEnd == rhs.dhcpEnd && lhs.dhcpLease == rhs.dhcpLease && lhs.interfaceID == rhs.interfaceID && lhs.nat66Prefix == rhs.nat66Prefix
	}

	public static func != (lhs: Self, rhs: Self) -> Bool {
		return !(lhs == rhs)
	}

	private enum CodingKeys: String, CodingKey {
		case mode = "mode"
		case netmask = "netmask"
		case dhcpStart = "dhcp-start"
		case dhcpEnd = "dhcp-end"
		case dhcpLease = "dhcp-lease"
		case interfaceID = "interfaceID"
		case nat66Prefix = "nat66-prefix"
	}

	public func validate() throws {
		guard netmask.isValidNetmask() else {
			throw ServiceError("Invalid netmask \(netmask)")
		}

		guard let gateway = IP.V4(dhcpStart) else {
			throw ServiceError("Invalid gateway \(dhcpStart)")
		}

		guard let end = IP.V4(dhcpEnd) else {
			throw ServiceError("Invalid dhcp end \(dhcpEnd)")
		}

		let network = IP.Block<IP.V4>(base: gateway, bits: UInt8(netmask.netmaskToCidr())).network

		guard network.contains(end) else {
			throw ServiceError("dhcp end \(dhcpEnd) is not in the range of the network \(network.description)")
		}

		let networks = Self.networkInterfaces().map {
			$0.network
		}

		guard networks.first(where: { $0.contains(gateway) }) == nil else {
			throw ServiceError("Gateway \(dhcpStart) is already in use")
		}

		if let dhcpLease = dhcpLease {
			if dhcpLease > 24 * 3600 || dhcpLease < 60 {
				throw ServiceError("Invalid dhcp lease \(dhcpLease)")
			}
		}
	}

	public static func networkInterfaces() -> [IP.Block<IP.V4>] {
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

				if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
					var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

					if addrFamily == UInt8(AF_INET) {
						if getnameinfo(addr, socklen_t(interface.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
							var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))

							if getnameinfo(netmask, socklen_t(netmask.pointee.sa_len), &netmaskName, socklen_t(netmaskName.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
								addrStr = "\(String(cString: hostname))/\(String(cString: netmaskName).netmaskToCidr())"
							} else {
								addrStr = String(cString: hostname)
							}

							if let ip: IP.Block<IP.V4> = .init(addrStr) {
								ipAddresses.append(ip)
							}
						}
					}
				}
			}

		}

		return ipAddresses
	}

	public static func freeIP(segment: String) throws -> (String, String) {
		let networks = Self.networkInterfaces().map {
			$0.network
		}

		for value: UInt8 in 1..<255 {
			let value = UInt8.random(in: value...254)
			var base: [UInt8] = [192, 168, value, 0]
			let segment = segment.split(separator: ".").map { UInt8($0) ?? 0 }

			for i in 0..<segment.count {
				base[i] = segment[i]
			}

			let ip: IP.V4 = .init(base[0], base[1], base[2], base[3])

			if networks.first(where: { $0.contains(ip) }) == nil {
				return (String(format: "%d.%d.%d.%d", base[0], base[1], base[2], 1), String(format: "%d.%d.%d.%d", base[0], base[1], base[2], 254))
			}
		}

		throw ServiceError("No free network address available")
	}

	public static func createNetwork(mode: VMNetMode, baseAddress: String, cidr: Int) throws -> VZSharedNetwork {
		let (gateway, dhcpEnd) = try freeIP(segment: baseAddress)

		return .init(mode: mode, netmask: "\(cidr)".cidrToNetmask(), dhcpStart: gateway, dhcpEnd: dhcpEnd, dhcpLease: 300, interfaceID: UUID().uuidString, nat66Prefix: nil)
	}
}

extension String {
	public func isValidMAcAddress() -> Bool {
		self.range(of: "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", options: .regularExpression) != nil
	}

	public func isValidIP() -> Bool {
		self.range(of: "^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$", options: .regularExpression) != nil
	}

	public func isValidNetmask() -> Bool {
		self.range(of: "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})$", options: .regularExpression) != nil
	}

	public func netmaskToCidr() -> Int {
		let octets: [Int] = self.split(separator: ".").map({ Int($0)! })
		var cidr: Int = 0

		for i in 0..<4 {
			cidr += (octets[i] == 255) ? 8 : (octets[i] == 254) ? 7 : (octets[i] == 252) ? 6 : (octets[i] == 248) ? 5 : (octets[i] == 240) ? 4 : (octets[i] == 224) ? 3 : (octets[i] == 192) ? 2 : (octets[i] == 128) ? 1 : (octets[i] == 0) ? 0 : -1
		}

		return cidr
	}

	public func cidrToNetmask() -> String {
		var value = Int(self) ?? 0
		value = 0xFFFF_FFFF ^ ((1 << (32 - value)) - 1)

		return "\((value >> 24) & 0xFF).\((value >> 16) & 0xFF).\((value >> 8) & 0xFF).\(value & 0xFF)"
	}

	public func toIPV4() -> (address: IP.V4?, netmask: IP.V4?) {
		let parts = self.split(separator: "/")
		
		return (IP.V4(parts[0]), (parts.count > 1 ? IP.V4(String(parts[1]).cidrToNetmask()) : nil))
	}

	public func IPToInt() -> Int {
		let octets: [Int] = self.split(separator: ".").map({ Int($0)! })
		var numValue: Int = 0

		for i in stride(from: 3, through: 0, by: -1) {
			numValue += octets[3 - i] << (i * 8)
		}

		return numValue
	}
}

public struct VZVMNetConfig: Codable {
	public var sharedNetworks: [String: VZSharedNetwork]

	public var sharedNetworkNames: [String] {
		return Array(sharedNetworks.keys)
	}

	private enum CodingKeys: String, CodingKey {
		case sharedNetworks = "networks"
	}

	public init() throws {
		self.sharedNetworks = [
			"shared": try VZSharedNetwork.createNetwork(mode: .shared, baseAddress: "192.168", cidr: 24),
			"host": try VZSharedNetwork.createNetwork(mode: .host, baseAddress: "172.\(Int.random(in: 16...31))", cidr: 24),
		]
	}

	public init(fromJSON: Data) throws {
		self = try JSONDecoder().decode(VZVMNetConfig.self, from: fromJSON)
	}

	public init(fromURL: URL) throws {
		self = try Self(fromJSON: try Data(contentsOf: fromURL))
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.sharedNetworks = try container.decodeIfPresent([String: VZSharedNetwork].self, forKey: .sharedNetworks) ?? [:]
	}

	public func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encodeIfPresent(sharedNetworks, forKey: .sharedNetworks)
	}

	public func save(toURL: URL) throws {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		try encoder.encode(self).write(to: toURL)
	}
}
