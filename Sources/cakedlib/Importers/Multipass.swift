import Foundation
import GRPCLib

typealias MultipassRegisteredInstances = [String: MultipassRegisteredInstance] // /var/root/Library/Application Support/multipassd/qemu/vault/multipassd-instance-image-records.json
typealias MultipassInstances = [String: MultipassInstance] // /var/root/Library/Application Support/multipassd/qemu/multipassd-vm-instances.json

extension MultipassRegisteredInstances {
	init(data: Data) throws {
		self = try newJSONDecoder().decode(MultipassRegisteredInstances.self, from: data)
	}

	init(_ json: String, using encoding: String.Encoding = .utf8) throws {
		guard let data = json.data(using: encoding) else {
			throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
		}

		try self.init(data: data)
	}

	init(fromURL url: URL) throws {
		try self.init(data: try Data(contentsOf: url))
	}
}

struct MultipassRegisteredInstance: Codable, Sendable {
	var image: MultipassRegisteredInstanceImage
	var lastAccessed: Int
	var query: MultipassRegisteredInstanceQuery

	struct MultipassRegisteredInstanceImage: Codable, Sendable {
		var aliases: [String]?
		var currentRelease: String
		var id: String
		var originalRelease: String
		var path: String
		var releaseDate: String

		enum CodingKeys: String, CodingKey {
			case aliases
			case currentRelease = "current_release"
			case id
			case originalRelease = "original_release"
			case path
			case releaseDate = "release_date"
		}
	}

	struct MultipassRegisteredInstanceQuery: Codable, Sendable {
		var persistent: Bool
		var queryType: Int
		var release: String
		var remoteName: String

		enum CodingKeys: String, CodingKey {
			case persistent
			case queryType = "query_type"
			case release
			case remoteName = "remote_name"
		}
	}

	enum CodingKeys: String, CodingKey {
		case image
		case lastAccessed = "last_accessed"
		case query
	}
}

extension MultipassInstances {
	init(data: Data) throws {
		self = try newJSONDecoder().decode(MultipassInstances.self, from: data)
	}

	init(_ json: String, using encoding: String.Encoding = .utf8) throws {
		guard let data = json.data(using: encoding) else {
			throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
		}
		try self.init(data: data)
	}

	init(fromURL url: URL) throws {
		try self.init(data: try Data(contentsOf: url))
	}
}

struct MultipassInstance: Codable, Sendable {
	var cloneCount: Int
	var deleted: Bool
	var diskSpace: String
	var extraInterfaces: [ExtraInterface]
	var macAddr, memSize: String
	var metadata: Metadata
	var mounts: [Mount]
	var numCores: Int
	var sshUsername: String
	var state: State

	enum State: Int, Codable, Sendable {
		case off
		case stopped
		case starting
		case restarting
		case running
		case delayed_shutdown
		case suspending
		case suspended
		case unknown
	}

	enum CodingKeys: String, CodingKey {
		case cloneCount = "clone_count"
		case deleted
		case diskSpace = "disk_space"
		case extraInterfaces = "extra_interfaces"
		case macAddr = "mac_addr"
		case memSize = "mem_size"
		case metadata, mounts
		case numCores = "num_cores"
		case sshUsername = "ssh_username"
		case state
	}

	struct ExtraInterface: Codable, Sendable {
		var autoMode: Bool
		var id: String
		var macAddress: String

		enum CodingKeys: String, CodingKey {
			case autoMode = "auto_mode"
			case id
			case macAddress = "mac_address"
		}
	}

	struct Metadata: Codable, Sendable {
		var arguments: [String]
		var machineType: String
//		var mountData: MountData

		enum CodingKeys: String, CodingKey {
			case arguments
			case machineType = "machine_type"
//			case mountData = "mount_data"
		}
	}

	struct Mount: Codable, Sendable {
		var gidMappings: [GidMapping]
		var mountType: Int
		var sourcePath: String
		var targetPath: String
		var uidMappings: [UidMapping]

		struct GidMapping: Codable, Sendable {
			var hostGid: Int
			var instanceGid: Int

			enum CodingKeys: String, CodingKey {
				case hostGid = "host_gid"
				case instanceGid = "instance_gid"
			}
		}

		struct UidMapping: Codable, Sendable {
			var hostUid: Int
			var instanceUid: Int

			enum CodingKeys: String, CodingKey {
				case hostUid = "host_uid"
				case instanceUid = "instance_uid"
			}
		}

		enum CodingKeys: String, CodingKey {
			case gidMappings = "gid_mappings"
			case mountType = "mount_type"
			case sourcePath = "source_path"
			case targetPath = "target_path"
			case uidMappings = "uid_mappings"
		}
	}
}

func newJSONDecoder() -> JSONDecoder {
	let decoder = JSONDecoder()
	if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
		decoder.dateDecodingStrategy = .iso8601
	}
	return decoder
}

func newJSONEncoder() -> JSONEncoder {
	let encoder = JSONEncoder()
	if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
		encoder.dateEncodingStrategy = .iso8601
	}
	return encoder
}

struct MultipassImporter: Importer {
	func importVM(location: VMLocation, source: String, userName: String, password: String, sshPrivateKey: String? = nil, runMode: Utils.RunMode) throws {
		// Logic to import a VM from Multipass
		throw ServiceError("Unimplemented import logic for Multipass files.")
	}
}
