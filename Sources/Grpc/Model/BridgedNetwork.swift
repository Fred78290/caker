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
	public var usedBy: Int = 0

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

	public init(
		name: String,
		mode: BridgedNetworkMode,
		description: String,
		gateway: String,
		dhcpEnd: String = "",
		dhcpLease: String,
		interfaceID: String,
		endpoint: String,
		usedBy: Int
	) {
		self.name = name
		self.mode = mode
		self.description = description
		self.gateway = gateway
		self.dhcpEnd = dhcpEnd
		self.dhcpLease = dhcpLease
		self.interfaceID = interfaceID
		self.endpoint = endpoint
		self.usedBy = usedBy
	}

	public init(from: Caked_NetworkInfo) {
		self.name = from.name
		self.mode = .init(rawValue: from.mode) ?? .shared
		self.description = from.description_p
		self.gateway = from.gateway
		self.dhcpEnd = from.dhcpEnd
		self.interfaceID = from.interfaceID
		self.endpoint = from.endpoint
		self.usedBy = Int(from.used)
	}

	public var caked: Caked_NetworkInfo {
		Caked_NetworkInfo.with {
			$0.name = self.name
			$0.mode = self.mode.rawValue
			$0.description_p = self.description
			$0.gateway = self.gateway
			$0.dhcpEnd = self.dhcpEnd
			$0.interfaceID = self.interfaceID
			$0.endpoint = self.endpoint
			$0.used = Int32(self.usedBy)
		}
	}
}

public struct NetworkInfoReply: Codable {
	public let info: BridgedNetwork
	public let success: Bool
	public let reason: String

	public init(info: BridgedNetwork, success: Bool, reason: String) {
		self.info = info
		self.success = success
		self.reason = reason
	}

	public init(from: Caked_NetworkInfoReply) throws {
		self.info = BridgedNetwork(from: from.info)
		self.success = from.success
		self.reason = from.reason
	}

	public var caked: Caked_NetworkInfoReply {
		Caked_NetworkInfoReply.with {
			$0.info = self.info.caked
			$0.success = self.success
			$0.reason = self.reason
		}
	}
}

public struct ListNetworksReply: Codable {
	public let networks: [BridgedNetwork]
	public let success: Bool
	public let reason: String

	public init(networks: [BridgedNetwork], success: Bool, reason: String) {
		self.networks = networks
		self.success = success
		self.reason = reason
	}

	public init(from: Caked_ListNetworksReply) throws {
		self.networks = from.networks.map(BridgedNetwork.init(from:))
		self.success = from.success
		self.reason = from.reason
	}

	public var caked: Caked_ListNetworksReply {
		Caked_ListNetworksReply.with {
			$0.networks = self.networks.map(\.caked)
			$0.success = self.success
			$0.reason = self.reason
		}
	}
}

public struct StartedNetworkReply: Codable {
	public let name: String
	public let started: Bool
	public let reason: String

	public var caked: Caked_StartedNetworkReply {
		Caked_StartedNetworkReply.with {
			$0.name = self.name
			$0.started = self.started
			$0.reason = self.reason
		}
	}

	public init(name: String, started: Bool, reason: String) {
		self.name = name
		self.started = started
		self.reason = reason
	}

	public init(from: Caked_StartedNetworkReply) {
		self.name = from.name
		self.started = from.started
		self.reason = from.reason
	}
}

public struct StoppedNetworkReply: Codable {
	public let name: String
	public let stopped: Bool
	public let reason: String

	public var caked: Caked_StoppedNetworkReply {
		Caked_StoppedNetworkReply.with {
			$0.name = self.name
			$0.stopped = self.stopped
			$0.reason = self.reason
		}
	}

	public init(name: String, stopped: Bool, reason: String) {
		self.name = name
		self.stopped = stopped
		self.reason = reason
	}

	public init(from: Caked_StoppedNetworkReply) {
		self.name = from.name
		self.stopped = from.stopped
		self.reason = from.reason
	}
}

public struct CreatedNetworkReply: Codable {
	public let name: String
	public let created: Bool
	public let reason: String

	public var caked: Caked_CreatedNetworkReply {
		Caked_CreatedNetworkReply.with {
			$0.name = self.name
			$0.created = self.created
			$0.reason = self.reason
		}
	}

	public init(name: String, created: Bool, reason: String) {
		self.name = name
		self.created = created
		self.reason = reason
	}

	public init(from: Caked_CreatedNetworkReply) {
		self.name = from.name
		self.created = from.created
		self.reason = from.reason
	}
}

public struct ConfiguredNetworkReply: Codable {
	public let name: String
	public let configured: Bool
	public let reason: String

	public var caked: Caked_ConfiguredNetworkReply {
		Caked_ConfiguredNetworkReply.with {
			$0.name = name
			$0.configured = configured
			$0.reason = reason
		}
	}

	public init(name: String, configured: Bool, reason: String) {
		self.name = name
		self.configured = configured
		self.reason = reason
	}

	public init(from: Caked_ConfiguredNetworkReply) {
		self.name = from.name
		self.configured = from.configured
		self.reason = from.reason
	}

}

public struct DeleteNetworkReply: Codable {
	public let name: String
	public let deleted: Bool
	public let reason: String

	public var caked: Caked_DeleteNetworkReply {
		Caked_DeleteNetworkReply.with {
			$0.name = self.name
			$0.deleted = self.deleted
			$0.reason = self.reason
		}
	}

	public init(name: String, deleted: Bool, reason: String) {
		self.name = name
		self.deleted = deleted
		self.reason = reason
	}

	public init(from: Caked_DeleteNetworkReply) {
		self.name = from.name
		self.deleted = from.deleted
		self.reason = from.reason
	}
}
