//
//  BridgedNetwork.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//

public struct BridgedNetwork: Codable {
	public var name: String
	public var mode: String
	public var description: String = ""
	public var gateway: String = ""
	public var dhcpEnd = ""
	public var interfaceID: String = ""
	public var endpoint: String = ""
	
	public init(name: String, mode: String, description: String, gateway: String, dhcpEnd: String = "", interfaceID: String, endpoint: String) {
		self.name = name
		self.mode = mode
		self.description = description
		self.gateway = gateway
		self.dhcpEnd = dhcpEnd
		self.interfaceID = interfaceID
		self.endpoint = endpoint
	}

	public init(from: Caked_NetworkInfo) {
		self.name = from.name
		self.mode = from.mode
		self.description = from.description_p
		self.gateway = from.gateway
		self.dhcpEnd = from.dhcpEnd
		self.interfaceID = from.interfaceID
		self.endpoint = from.endpoint
	}

	public func toCaked_NetworkInfo() -> Caked_NetworkInfo {
		Caked_NetworkInfo.with {
			$0.name = self.name
			$0.mode = self.mode
			$0.description_p = self.description
			$0.gateway = self.gateway
			$0.dhcpEnd = self.dhcpEnd
			$0.interfaceID = self.interfaceID
			$0.endpoint = self.endpoint
		}
	}
}

