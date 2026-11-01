import ArgumentParser
import Foundation
import Virtualization

public enum NetworkMode: Int, CaseIterable, CustomStringConvertible, ExpressibleByArgument, Codable, Sendable {
	case manual, auto

	public init?(argument: String) {
		switch argument {
		case "manual":
			self = .manual
		case "auto":
			self = .auto
		default:
			return nil
		}
	}

	public var description: String {
		switch self {
		case .manual:
			return "manual"
		case .auto:
			return "auto"
		}
	}
}

public struct BridgeAttachement: CustomStringConvertible, ExpressibleByArgument, Codable, Hashable, Identifiable, Sendable {
	public static var defaultNetworkName = "default"
	/// Names the default shared network had before it was renamed to `defaultNetworkName`
	/// (Apple's `VZNATNetworkDeviceAttachment` was called "nat"). Still found in existing
	/// `config.json` files and scripts, so they are mapped to the new name instead of being dropped.
	public static let legacyNetworkNames: Set<String> = ["nat", "NAT shared network"]
	public static var defaultNetworkUUID = "E20D7252-ED0D-4FF0-83CE-DEB180EA6EE4"
	public static var defaultNetworkDescription: String { String(localized: "Default shared network") }
	public static var defaultNetworkGateway: String {
		let defaultNetwork = {
			guard let defaultNetwork = CakedKeyConfig.defaultNetwork.string() else {
				return CakedKeyConfig.defaultNatNetwork
			}
			
			return defaultNetwork
		}()

		return defaultNetwork.stringBeforeLast(before: ".") + ".1/\(defaultNetwork.stringAfter(after: "/"))"
	}

	public var network: String
	public var mode: NetworkMode?
	public var macAddress: String?
	
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.description == rhs.description
	}
	
	public var defaultValueDescription: String {
		"name=<network|bridged|nat|shared|host>,[mode=<auto|manual>,[mac=<mac>]]"
	}
	
	public var description: String {
		var value: [String] = ["name=\(network)"]
		
		if let mode = mode {
			value.append("mode=\(mode)")
		}
		
		if let macAddress = macAddress {
			value.append("mac=\(macAddress)")
		}
		
		return value.joined(separator: ",")
	}
	
	public var id: String {
		self.description
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.network = Self.normalized(try container.decode(String.self, forKey: .network))
		self.mode = try container.decodeIfPresent(NetworkMode.self, forKey: .mode)
		self.macAddress = try container.decodeIfPresent(String.self, forKey: .macAddress)
	}

	private enum CodingKeys: String, CodingKey {
		case network, mode, macAddress
	}

	private static func normalized(_ network: String) -> String {
		Self.legacyNetworkNames.contains(network) ? Self.defaultNetworkName : network
	}

	public init(network: String, mode: NetworkMode? = nil, macAddress: String? = nil) {
		self.network = Self.normalized(network)
		self.mode = mode
		self.macAddress = macAddress
	}
	
	public init?(argument: String) {
		do {
			try self.init(parseFrom: argument)
		} catch {
			return nil
		}
	}
	
	public init(parseFrom: String) throws {
		let parts = parseFrom.split(separator: ",")
		var network: String = String.empty
		var mode: NetworkMode?
		var macAddress: VZMACAddress?
		
		guard parts.count <= 3 else {
			throw ValidationError(String(localized: "Invalid network attachment: \(parseFrom)"))
		}
		
		try parts.forEach { part in
			if part.starts(with: "name=") {
				network = String(part.dropFirst("name=".count))
			} else if part.starts(with: "mode=") {
				mode = NetworkMode(argument: String(part.dropFirst("mode=".count)))
			} else if part.starts(with: "mac=") {
				macAddress = VZMACAddress(string: String(part.dropFirst("mac=".count)))
			} else if network.isEmpty {
				network = String(part)
			} else {
				throw ValidationError(String(localized: "Invalid network attachment: \(parseFrom)"))
			}
		}
		
		network = Self.normalized(network)

		if macAddress == nil && network != BridgeAttachement.defaultNetworkName {
			macAddress = VZMACAddress.randomLocallyAdministered()
		}
		
		self.network = network
		self.macAddress = macAddress?.string
		self.mode = mode
	}
	
	public func clone() -> BridgeAttachement {
		if macAddress != nil {
			return .init(network: network, mode: mode, macAddress: VZMACAddress.randomLocallyAdministered().string)
		}
		
		return .init(network: network, mode: mode, macAddress: nil)
	}
	
	public func isNAT() -> Bool {
		return self.network == BridgeAttachement.defaultNetworkName
	}
	
	public func isBridged() -> Bool {
		return self.network == "bridged"
	}
	
	public static func bridgedNetwork() -> BridgeAttachement {
		.init(network: "bridged", mode: .auto, macAddress: VZMACAddress.randomLocallyAdministered().string)
	}
}

extension BridgeAttachement: Validatable {
	public func validate() -> Bool {
		if network.isEmpty {
			return false
		}

		return true
	}
}
