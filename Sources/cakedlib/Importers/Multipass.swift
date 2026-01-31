import Foundation
import GRPCLib
import Virtualization
import CakeAgentLib

private typealias MultipassRegisteredInstances = [String: MultipassRegisteredInstance]  // /var/root/Library/Application Support/multipassd/qemu/vault/multipassd-instance-image-records.json
private typealias MultipassInstances = [String: MultipassInstance]  // /var/root/Library/Application Support/multipassd/qemu/multipassd-vm-instances.json

private let multipass_ssh_key_path: String = "/var/root/Library/Application Support/multipassd/ssh-keys/id_rsa"

extension MultipassRegisteredInstances {
	fileprivate init(data: Data) throws {
		self = try newJSONDecoder().decode(MultipassRegisteredInstances.self, from: data)
	}

	fileprivate init(_ json: String, using encoding: String.Encoding = .utf8) throws {
		guard let data = json.data(using: encoding) else {
			throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
		}

		try self.init(data: data)
	}

	fileprivate init(fromURL url: URL) throws {
		try self.init(data: try Data(contentsOf: url))
	}
}

private struct MultipassRegisteredInstance: Codable, Sendable {
	var image: MultipassRegisteredInstanceImage
	var lastAccessed: Int
	var query: MultipassRegisteredInstanceQuery

	struct DiskAttachement: Sendable {
		enum DeviceType: String {
			case disk = "disk"
			case cdrom = "cdrom"

			init(argument: String?) {
				guard let argument = argument else {
					self = .disk
					return
				}

				switch argument.lowercased() {
				case "disk":
					self = .disk
				case "cdrom-image":
					self = .cdrom
				default:
					self = .disk
				}
			}
		}

		var diskURL: URL
		var deviceType: DeviceType
	}

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

	func diskAttachments() throws -> [MultipassRegisteredInstance.DiskAttachement] {
		let location = URL(fileURLWithPath: self.image.path).deletingLastPathComponent()

		guard let disks = try? FileManager.default.contentsOfDirectory(at: location, includingPropertiesForKeys: nil).filter({ $0.pathExtension.lowercased() == "img" || $0.pathExtension.lowercased() == "iso" }) else {
			throw ServiceError("No disk files found in the specified directory: \(location.path)")
		}

		return disks.compactMap { diskURL in
			return MultipassRegisteredInstance.DiskAttachement(diskURL: diskURL, deviceType: diskURL.pathExtension.lowercased() == "iso" ? .cdrom : .disk)
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
	fileprivate init(data: Data) throws {
		self = try newJSONDecoder().decode(MultipassInstances.self, from: data)
	}

	fileprivate init(_ json: String, using encoding: String.Encoding = .utf8) throws {
		guard let data = json.data(using: encoding) else {
			throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
		}
		try self.init(data: data)
	}

	fileprivate init(fromURL url: URL) throws {
		try self.init(data: try Data(contentsOf: url))
	}
}

struct MultipassInstance: Codable, Sendable {
	var cloneCount: Int
	var deleted: Bool
	var diskSpace: String
	var extraInterfaces: [ExtraInterface]
	var macAddr: String
	var memSize: String
	var metadata: Metadata
	var mounts: [Mount]?
	var numCores: Int
	var sshUsername: String?
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
		var gidMappings: [GidMapping]?
		var mountType: Int
		var sourcePath: String
		var targetPath: String
		var uidMappings: [UidMapping]?

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

	var sharedFolders: DirectorySharingAttachments {
		guard let mounts = self.mounts else {
			return []
		}

		return mounts.compactMap {
			return DirectorySharingAttachment(source: $0.sourcePath, destination: $0.targetPath)
		}
	}

	var networkAttachments: (VZMACAddress?, [BridgeAttachement]) {
		var attachements: [BridgeAttachement] = []

		attachements.append(BridgeAttachement(network: "nat", mode: .auto, macAddress: nil))  // Default NAT network

		for extraInterface in self.extraInterfaces {
			attachements.append(BridgeAttachement(network: extraInterface.id, mode: extraInterface.autoMode ? .auto : .manual, macAddress: extraInterface.macAddress))
		}

		return (VZMACAddress(string: self.macAddr), attachements)
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
	var needSudo: Bool {
		return true  // Multipass operations typically require elevated privileges
	}

	var name: String {
		return "Multipass Importer"
	}

	func importVM(location: VMLocation, source: String, userName: String, password: String, sshPrivateKey: String? = nil, passphrase: String? = nil, runMode: Utils.RunMode) throws {
		let registeredInstances: MultipassRegisteredInstances = try MultipassRegisteredInstances(fromURL: URL(fileURLWithPath: "/var/root/Library/Application Support/multipassd/qemu/vault/multipassd-instance-image-records.json"))

		guard let registeredInstance = registeredInstances[source] else {
			throw ServiceError("No registered instance found for source: \(source)")
		}

		let instances: MultipassInstances = try MultipassInstances(fromURL: URL(fileURLWithPath: "/var/root/Library/Application Support/multipassd/qemu/multipassd-vm-instances.json"))

		guard let instance = instances[source] else {
			throw ServiceError("No instance found: \(source)")
		}

		if instance.deleted {
			throw ServiceError("Instance \(source) is deleted and cannot be imported.")
		}

		if instance.state != .off && instance.state != .stopped {
			throw ServiceError("Instance \(source) is not in a stopped state, current state: \(instance.state)")
		}

		guard let memorySize = UInt64(instance.memSize) else {
			throw ServiceError("Invalid memory size for instance \(source).")
		}

		let networkAttachments = instance.networkAttachments
		let userName = instance.sshUsername ?? userName

		let config = CakeConfig(
			location: location.rootURL,
			os: .linux,
			autostart: false,
			configuredUser: userName,
			configuredPassword: password,
			configuredGroup: "adm",
			configuredGroups: ["sudo"],
			configuredPlatform: .ubuntu,
			displayRefit: true,
			ifname: false,
			cpuCountMin: instance.numCores,
			memorySize: memorySize,
			memorySizeMin: VMBuilder.memoryMinSize,
			screenSize: .standard
		)

		if let sshPrivateKey = sshPrivateKey {
			config.sshPrivateKeyPath = sshPrivateKey
		} else {
			config.sshPrivateKeyPath = "id_rsa"

			let keyModel = try PrivateKeyModel(from: URL(fileURLWithPath: multipass_ssh_key_path))

			try keyModel.save(privateURL: location.rootURL.appendingPathComponent("id_rsa"), publicURL: location.rootURL.appendingPathComponent("id_rsa.pub"))
		}

		config.sshPrivateKeyPassphrase = passphrase
		config.useCloudInit = true
		config.agent = false
		config.nested = true
		config.attachedDisks = try importDiskAttachements(diskAttachments: registeredInstance.diskAttachments(), to: location)
		config.networks = networkAttachments.1
		config.mounts = instance.sharedFolders
		config.macAddress = networkAttachments.0
		config.firstLaunch = true

		_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)

		try config.save()
	}

	private func importDiskAttachements(diskAttachments: [MultipassRegisteredInstance.DiskAttachement], to location: VMLocation) throws -> [GRPCLib.DiskAttachement] {
		var diskCount = 0

		return try diskAttachments.compactMap { disk in
			let destinationURL: URL
			var result: GRPCLib.DiskAttachement? = nil

			if disk.deviceType == .disk {

				if diskCount == 0 {
					destinationURL = location.diskURL
				} else {
					destinationURL = location.rootURL.appendingPathComponent(disk.diskURL.lastPathComponent)
					result = try GRPCLib.DiskAttachement(parseFrom: destinationURL.lastPathComponent)
				}

				diskCount += 1

				try CloudImageConverter.convertCloudImageToRaw(from: disk.diskURL, to: destinationURL, progressHandler: ProgressObserver.progressHandler)
			} else {
				if disk.diskURL.lastPathComponent == "cloud-init-config.iso" {
					destinationURL = location.rootURL.appendingPathComponent(cloudInitIso)
				} else {
					destinationURL = location.rootURL.appendingPathComponent(disk.diskURL.lastPathComponent)
					result = try GRPCLib.DiskAttachement(parseFrom: "\(destinationURL.lastPathComponent):ro")
				}

				try FileManager.default.copyItem(at: disk.diskURL, to: destinationURL)
			}

			return result
		}
	}
}
