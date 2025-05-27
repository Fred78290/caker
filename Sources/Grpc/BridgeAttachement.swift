import ArgumentParser
import Foundation
import Virtualization

public enum NetworkMode: Int, CaseIterable, CustomStringConvertible, ExpressibleByArgument, Codable {
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

public struct BridgeAttachement: CustomStringConvertible, ExpressibleByArgument, Codable {
	public let network: String
	public let mode: NetworkMode?
	public let macAddress: String?

	public var defaultValueDescription: String {
		"name=<network|nat|shared|host>,[mode=<auto|manual>,[mac=<mac>]]"
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

	public init(network: String, mode: NetworkMode?, macAddress: String?) {
		self.network = network
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
		var network: String = ""
		var mode: NetworkMode?
		var macAddress: VZMACAddress?

		guard parts.count <= 3 else {
			throw ValidationError("Invalid network attachment: \(parseFrom)")
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
				throw ValidationError("Invalid network attachment: \(parseFrom)")
			}
		}

		if macAddress == nil && network != "nat" && network != "NAT shared network" {
			macAddress = VZMACAddress.randomLocallyAdministered()
		}

		self.network = network
		self.macAddress = macAddress?.string
		self.mode = mode
	}

	public func isNAT() -> Bool {
		return self.network == "nat" || self.network == "NAT shared network"
	}
}
