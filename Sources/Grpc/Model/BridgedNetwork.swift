//
//  BridgedNetwork.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//

public enum BridgedNetworkMode: String, Codable, CaseIterable {
	case nat
	case bridged
	case shared
	case host
}

public struct BridgedNetwork: Codable, Hashable, Identifiable, Comparable {
	public static func < (lhs: BridgedNetwork, rhs: BridgedNetwork) -> Bool {
		return lhs.id < rhs.id
	}
	
	public typealias ID = String

	public var name: String
	public var mode: BridgedNetworkMode
	public var description: String = ""
	public var gateway: String = ""
	public var dhcpEnd = ""
	public var dhcpLease: String = ""
	public var interfaceID: String = ""
	public var endpoint: String = ""

	public var id: String {
		"\(self.mode).\(self.name)"
	}

	public var dhcpStart: String {
		guard let value = self.gateway.split(separator: "/").first else {
			return ""
		}

		return String(value)
	}

	public var netmask: String {
		guard let value = self.gateway.split(separator: "/").last else {
			return ""
		}

		var cidr = Int(value) ?? 0
		cidr = 0xFFFF_FFFF ^ ((1 << (32 - cidr)) - 1)

		return "\((cidr >> 24) & 0xFF).\((cidr >> 16) & 0xFF).\((cidr >> 8) & 0xFF).\(cidr & 0xFF)"
	}

	public init(name: String, mode: BridgedNetworkMode, description: String, gateway: String, dhcpEnd: String = "", dhcpLease: String, interfaceID: String, endpoint: String) {
		self.name = name
		self.mode = mode
		self.description = description
		self.gateway = gateway
		self.dhcpEnd = dhcpEnd
		self.dhcpLease = dhcpLease
		self.interfaceID = interfaceID
		self.endpoint = endpoint
	}

	public init(from: Caked_NetworkInfo) {
		self.name = from.name
		self.mode = .init(rawValue: from.mode) ?? .shared
		self.description = from.description_p
		self.gateway = from.gateway
		self.dhcpEnd = from.dhcpEnd
		self.interfaceID = from.interfaceID
		self.endpoint = from.endpoint
	}

	public func toCaked_NetworkInfo() -> Caked_NetworkInfo {
		Caked_NetworkInfo.with {
			$0.name = self.name
			$0.mode = self.mode.rawValue
			$0.description_p = self.description
			$0.gateway = self.gateway
			$0.dhcpEnd = self.dhcpEnd
			$0.interfaceID = self.interfaceID
			$0.endpoint = self.endpoint
		}
	}
}
