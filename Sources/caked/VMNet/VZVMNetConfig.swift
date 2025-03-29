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

struct VZVMNetConfig: Codable {
	var sharedNetworks: [String:VZSharedNetwork]

	var sharedNetworkNames: [String] {
		return Array(sharedNetworks.keys)
	}

	private enum CodingKeys : String, CodingKey {
		case sharedNetworks = "networks"
	}

	init() {
		self.sharedNetworks = [:]
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