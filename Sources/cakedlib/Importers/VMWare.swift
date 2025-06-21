import Foundation
import Logging
import GRPCLib
import ArgumentParser
import Virtualization

struct VMXMap: Sendable {
	var baseURL: URL
	var keys: [String]
	var values: [String: String]

	/// Represents a network attachment in a VMX file.
	struct EthernetAttachment: Sendable {
		enum AddressType: String {
			case generated = "generated"
			case manual = "static"

			init(argument: String?) {
				guard let argument = argument else {
					self = .generated
					return
				}

				switch argument.lowercased() {
				case "generated":
					self = .generated
				case "static":
					self = .manual
				default:
					self = .generated
				}
			}
		}

		enum ConnectionType: String {
			case bridged = "bridged"
			case nat = "nat"
			case hostOnly = "hostonly"
			case custom = "custom"

			init?(argument: String?) {
				guard let argument = argument else {
					return nil
				}

				switch argument.lowercased() {
				case "bridged":
					self = .bridged
				case "nat":
					self = .nat
				case "hostonly":
					self = .hostOnly
				case "custom":
					self = .custom
				default:
					return nil
				}
			}
		}

		var name: String
		var macAddress: String?
		var addressType: AddressType
		var connectionType: ConnectionType
		var virtualDev: String?
		var unitNumber: Int
	}

	/// Represents a disk attachment in a VMX file.
	struct DiskAttachement: Sendable {
		enum DeviceType: String {
			case disk = "disk"
			case cdrom = "cdrom"
			case floppy = "floppy"

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
				case "floppy":
					self = .floppy
				default:
					self = .disk
				}
			}
		}

		enum ControllerType: String, CaseIterable {
			case nvme = "nvme"
			case scsi = "scsi"
			case sata = "sata"
			case ide = "ide"
		}

		var disk: String
		var deviceType: DeviceType
		var controller: ControllerType
		var controllerNumber: Int
		var unitNumber: Int
		var locked: Bool
	}

	init(baseURL: URL, data: Data) throws {
		try self.init(baseURL: baseURL, content: String(data: data, encoding: .utf8) ?? "")
	}

	init(baseURL: URL, content: String) throws {
		var keys: [String] = []
		var values: [String: String] = [:]
		var whitespacesAndNewlines = CharacterSet.whitespacesAndNewlines

		whitespacesAndNewlines.insert(charactersIn: "\"")

		for line in content.split(separator: "\n") {
			let line = line.trimmingCharacters(in: .whitespacesAndNewlines)

			if line.starts(with: "#!") {
				continue
			}

			if line.starts(with: ".encoding") == false && line.starts(with: "#") == false {
				let parts = line.split(separator: "=", maxSplits: 1)

				if parts.count == 2 {

					let key: String = String(parts[0]).trimmingCharacters(in: whitespacesAndNewlines)
					let value = String(parts[1]).trimmingCharacters(in: whitespacesAndNewlines)

					keys.append(key)
					values[key.lowercased()] = value
				}
			}
		}

		self.baseURL = baseURL
		self.keys = keys
		self.values = values
	}

	init(fromURL url: URL) throws {
		try self.init(baseURL: url, data: try Data(contentsOf: url))
	}

	var cpuCount: Int {
		if let value = values["numvcpus"] {
			return Int(value) ?? 1
		}

		return 1
	}

	var memorySize: UInt64 {
		if let value = values["memsize"] {
			if let memsize = Int(value) {
				return UInt64(memsize) * 1024 * 1024 // Convert MB to bytes
			}
		}

		return 512 * 1024 * 1024 // Default to 512 MB
	}

	var sharedFolders: [DirectorySharingAttachment] {
		var sharedFolders: [DirectorySharingAttachment] = []

		guard let maxNum = Int(values["sharedFolder.maxNum".lowercased()] ?? "0") else {
			return sharedFolders
		}

		for unitNumber in 0..<maxNum {
			let baseKey = "sharedFolder\(unitNumber)"

			guard let present = values["\(baseKey).present".lowercased()] else {
				continue
			}

			guard let enabled = values["\(baseKey).enabled".lowercased()] else {
				continue
			}

			if let present = Bool(present.lowercased()), let enabled = Bool(enabled.lowercased()), present, enabled {
				let guestName = values["\(baseKey).guestName".lowercased()] ?? "shared\(unitNumber)"
				let hostPath = values["\(baseKey).hostPath".lowercased()] ?? ""
				let writeAccess = Bool(values["\(baseKey).writeAccess".lowercased()]?.lowercased() ?? "false") ?? false

				sharedFolders.append(DirectorySharingAttachment(source: hostPath, readOnly: !writeAccess, name: guestName))
			}
		}

		return sharedFolders
	}

	var ethernetAttachements: [EthernetAttachment] {
		var attachments: [EthernetAttachment] = []

		for unitNumber in 0...9 {
			let baseKey = "ethernet\(unitNumber)"

			guard let present = values["\(baseKey).present"] else {
				break
			}

			if let present = Bool(present.lowercased()), present {
				var connectionType = EthernetAttachment.ConnectionType(argument: values["\(baseKey).connectionType".lowercased()]) ?? .nat
				let addressType = EthernetAttachment.AddressType(argument: values["\(baseKey).addressType".lowercased()])
				let virtualDev = values["\(baseKey).virtualDev".lowercased()]
				let vnet = values["\(baseKey).vnet".lowercased()]
				let bsdName = values["\(baseKey).bsdName".lowercased()]
				var address = values["\(baseKey).address".lowercased()]
				let name: String

				let generatedAddress = values["\(baseKey).generatedAddress".lowercased()]

				if connectionType == .custom {
					if let bsdName = bsdName {
						name = bsdName
						connectionType = .bridged
					} else {
						name = vnet!
					}
				} else {
					name = "nat"
				}

				if address == nil {
					if generatedAddress != nil {
						address = generatedAddress
					} else if addressType == .generated {
						address = VZMACAddress.randomLocallyAdministered().string
					}
				}

				attachments.append(EthernetAttachment(name: name, macAddress: address, addressType: addressType, connectionType: connectionType, virtualDev: virtualDev, unitNumber: unitNumber))
			}
		}

		return attachments
	}

	var diskAttachments: [VMXMap.DiskAttachement] {
		var attachments: [VMXMap.DiskAttachement] = []

		VMXMap.DiskAttachement.ControllerType.allCases.forEach { controller in
			for controllerNumber in 0...3 {
				for diskNumber in 0...9 {
					// Construct the key for each disk attachment
					// Example: "ide0:0.fileName", "scsi1:2.fileName", etc.
					// The controllerNumber and diskNumber are used to differentiate between multiple disks on the same controller
					let baseKey = "\(controller.rawValue)\(controllerNumber):\(diskNumber)"

					guard let present = values["\(baseKey).present"] else {
						continue
					}

					if let present = Bool(present.lowercased()), present {
						if let fileName = values["\(baseKey).fileName".lowercased()] {
							let deviceType = VMXMap.DiskAttachement.DeviceType(argument: values["\(baseKey).deviceType".lowercased()])
							let diskURL = URL(fileURLWithPath: fileName, relativeTo: baseURL).absoluteURL

							if diskURL.pathExtension.lowercased() == "vmdk" && !FileManager.default.fileExists(atPath: diskURL.path) {
								Logger("VMXMap").warn("Disk file \(diskURL.path) does not exist, skipping attachment.")
								continue
							}

							let locked = try! diskURL.appendingPathExtension("lck").exists()
							
							attachments.append(DiskAttachement(disk: fileName, deviceType: deviceType, controller: controller, controllerNumber: controllerNumber, unitNumber: diskNumber, locked: locked))
						}
					}
				}
			}
		}

		return attachments
	}
}

struct VMWareImporter: Importer {
	let logger: Logger = .init("VMWareImporter")

	var needSudo: Bool {
		return false
	}

	var name: String {
		return "VMWare"
	}

	struct VMNet {
		var deviceNumber: Int
		var dhcp: Bool = false
		var uuid: String? = nil
		var name: String
		var netmask: String = ""
		var subnet: String = ""
		var virtual: Bool = false
		var nat: Bool = false
		var natIp6Prefix: String? = nil
	}

	func importVM(location: VMLocation, source: String, userName: String, password: String, sshPrivateKey: String? = nil, passphrase: String? = nil, runMode: Utils.RunMode) throws {
		// Logic to import from a VMWare source
		if URL.binary("qemu-img") == nil {
			throw ServiceError("qemu-img binary not found. Please install qemu to import VMWare files.")
		}

		let vmxMap = try locateVM(source: source)
		let ethernetAttachements = vmxMap.ethernetAttachements
		let diskAttachments = vmxMap.diskAttachments

		if let locked = diskAttachments.first(where: { $0.locked }) {
			throw ServiceError("VMX file contains locked disk attachment \(locked.disk). Please unlock the disk or stop virtual machine before importing.")
		}

		try createMissingNetworks(ethernetAttachements: ethernetAttachements, runMode: runMode)

		let networkAttachments: (VZMACAddress?, [BridgeAttachement]) = try importNetworkAttachements(ethernetAttachements: ethernetAttachements)
		let diskAttachements = try importDiskAttachements(diskAttachments: diskAttachments, from: vmxMap.baseURL, to: location)
		let config = CakeConfig(
			location: location.rootURL,
			os: .linux,
			autostart: false,
			configuredUser: userName,
			configuredPassword: password,
			displayRefit: true,
			cpuCountMin: vmxMap.cpuCount,
			memorySizeMin: vmxMap.memorySize)

		config.useCloudInit = true
		config.agent = false
		config.nested = true
		config.attachedDisks = diskAttachements
		config.networks = networkAttachments.1
		config.mounts = vmxMap.sharedFolders
		config.macAddress = networkAttachments.0 ?? VZMACAddress.randomLocallyAdministered()
		config.sshPrivateKeyPath = sshPrivateKey
		config.sshPrivateKeyPassphrase = passphrase
		config.firstLaunch = true

		_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)

		try config.save()
	}

	func importNetworkAttachements(ethernetAttachements: [VMXMap.EthernetAttachment]) throws -> (VZMACAddress?, [GRPCLib.BridgeAttachement]) {
		var macAddress: VZMACAddress? = nil
		let networks: [GRPCLib.BridgeAttachement] = ethernetAttachements.compactMap { ethernet in
			if ethernet.connectionType == .nat {
				if let mac = ethernet.macAddress {
					macAddress = VZMACAddress(string: mac)
				}
				return GRPCLib.BridgeAttachement(network: "nat", mode: .auto, macAddress: nil)
			} else if ethernet.connectionType == .hostOnly {
				return GRPCLib.BridgeAttachement(network: "host", mode: .auto, macAddress: ethernet.macAddress)
			} else if ethernet.connectionType == .bridged {
				return GRPCLib.BridgeAttachement(network: ethernet.name, mode: .auto, macAddress: ethernet.macAddress)
			} else if ethernet.connectionType == .custom {
				return GRPCLib.BridgeAttachement(network: ethernet.name, mode: .auto, macAddress: ethernet.macAddress)
			}

			return nil
		}

		return (macAddress, networks)
	}

	func importDiskAttachements(diskAttachments: [VMXMap.DiskAttachement], from: URL, to location: VMLocation) throws -> [GRPCLib.DiskAttachement]{
		var diskCount = 0
		var result: [GRPCLib.DiskAttachement] = []
		let diskAttachments = diskAttachments.reduce(into: [VMXMap.DiskAttachement.ControllerType:[VMXMap.DiskAttachement]]()) { (attachements, attachment) in
			var controller = attachements[attachment.controller] ?? []

			controller.append(attachment)
			controller.sort { $0.unitNumber < $1.unitNumber && $0.controllerNumber < $1.controllerNumber }

			attachements[attachment.controller] = controller
		}

		try VMXMap.DiskAttachement.ControllerType.allCases.forEach { controllerType in
			if let attachments = diskAttachments[controllerType] {
				for attachment in attachments {
					var sourceURL = from.deletingLastPathComponent().appendingPathComponent(attachment.disk)
					var insideVM = true

					if try sourceURL.exists() == false {
						// If the disk file does not exist at the expected location, try to find it in the same directory as the VMX file
						sourceURL = URL(fileURLWithPath: attachment.disk)
						insideVM = false

						guard try sourceURL.exists() else {
							logger.error("Disk file \(attachment.disk) not found in the VMX directory or the specified path.")
							continue
						}
					}

					if attachment.deviceType == .disk {
						let destinationURL: URL

						if diskCount == 0 {
							destinationURL = location.diskURL
						} else {
							destinationURL = location.rootURL.appendingPathComponent("\(attachment.disk.deletingPathExtension).img")
							result.append(try GRPCLib.DiskAttachement(parseFrom: destinationURL.lastPathComponent))
						}

						logger.info("Converting VMDK disk \(attachment.disk) to raw format at \(destinationURL.path)")

						try CloudImageConverter.convertVmdkToRawQemu(from: sourceURL, to: destinationURL, outputHandle: FileHandle.standardOutput, errorHandle: FileHandle.standardError)

						diskCount += 1
					} else if attachment.deviceType == .cdrom {
						if insideVM {
							let destinationURL = location.rootURL.appendingPathComponent(attachment.disk)

							logger.info("Copying CD-ROM disk \(attachment.disk) to \(destinationURL.path)")

							try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

							result.append(try GRPCLib.DiskAttachement(parseFrom: "\(destinationURL.lastPathComponent):ro"))
						} else {
							logger.info("Add CD-ROM disk from outside the VM at \(sourceURL.path)")
							result.append(try GRPCLib.DiskAttachement(parseFrom: "\(sourceURL.absoluteURL.path):ro"))
						}

					} else if attachment.deviceType == .floppy {
						// Handle floppy disks if needed
						logger.warn("Floppy disk attachments are not supported in this importer.")
					}
				}
			}
		}

		return result
	}

	func natIp6Prefix(vmnet: String) -> String? {
		// This is a placeholder for the actual NAT IPv6 prefix logic.
		// In a real implementation, this would return the NAT IPv6 prefix used by VMware.
		let natPath = "/Library/Preferences/VMware Fusion/\(vmnet)/nat.conf"

		guard FileManager.default.fileExists(atPath: natPath) else {
			return nil
		}

		guard let config = try? INIConfig(from: URL(fileURLWithPath: natPath)) else {
			return nil
		}

		return config["host"]?["natIp6Prefix"]
	}

	func vmnet() throws -> [String:VMNet] {
		let networkConfig = URL(fileURLWithPath: "/Library/Preferences/VMware Fusion/Networking")
		let configContent = try String(contentsOf: networkConfig, encoding: .utf8)
		let lines = configContent.split(separator: "\n")
		var vmnets: [String:VMNet] = [:]
		var whitespacesAndNewlines = CharacterSet.whitespacesAndNewlines

		whitespacesAndNewlines.insert(charactersIn: "\"")

		for line in lines {
			if line.starts(with: "answer") {
				let input = line.split(separator: " ", maxSplits: 3)

				if input.count == 3 {
					let key = String(input[1]).trimmingCharacters(in: whitespacesAndNewlines)
					let value = String(input[2]).trimmingCharacters(in: whitespacesAndNewlines)
					let vmnet = key.split(separator: "_")
					let deviceNumber = Int(vmnet[1]) ?? 0
					let name = "vmnet\(deviceNumber)"
					var config = vmnets[name] ?? VMNet(deviceNumber: deviceNumber, name: name, natIp6Prefix: natIp6Prefix(vmnet: name))

					if vmnet[2] == "DHCP" {
						if vmnet.count == 2 {
							config.dhcp = value == "yes" || value == "1"
						}
					} else if vmnet[2] == "HOSTONLY" {
						if vmnet.count == 4 {
							if vmnet[3] == "UUID" {
								config.uuid = value
							} else if vmnet[3] == "NAME" {
								config.name = value
							} else if vmnet[3] == "NETMASK" {
								config.netmask = value
							} else if vmnet[3] == "SUBNET" {
								config.subnet = value
							}
						} else if vmnet.count == 5 {
							if vmnet[3] == "UUID" && vmnet[4] == "NAME" {
								config.uuid = value
							} else if vmnet[3] == "NETMASK" && vmnet[4] == "SUBNET" {
								config.netmask = value
							}
						}
					} else if vmnet[2] == "VIRTUAL" {
						if vmnet.count == 3 {
							config.virtual = value == "yes" || value == "1"
						}
					} else if vmnet[2] == "NAT" {
						if vmnet.count == 3 {
							config.nat = value == "yes" || value == "1"
						}
					}

					vmnets[name] = config
				}
			}
		}

		return vmnets
	}

	func createMissingNetworks(ethernetAttachements: [VMXMap.EthernetAttachment], runMode: Utils.RunMode) throws {
		struct CreateNetwork {
			var name: String
			var network: VZSharedNetwork
		}

		let networkConfig = try Home(runMode: runMode).sharedNetworks()
		let vmnets = try vmnet()
		let createIt: [CreateNetwork] = try ethernetAttachements.compactMap { ethernet in
			if ethernet.connectionType == .custom {
				if let vmnet = vmnets[ethernet.name] {
					if networkConfig.sharedNetworks[ethernet.name] == nil {
						var dhcpStart = IP.V4(vmnet.subnet)!
						var dhcpEnd = dhcpStart

						dhcpStart.storage += 1
						dhcpEnd.storage += 128

						return CreateNetwork(name: ethernet.name,
						                     network: VZSharedNetwork(
						                     	mode: vmnet.nat ? .shared : .host,
						                     	netmask: vmnet.netmask,
						                     	dhcpStart: dhcpStart.description,
						                     	dhcpEnd: dhcpEnd.description,
						                     	dhcpLease: 300,
						                     	interfaceID: vmnet.uuid ?? UUID().uuidString,
						                     	nat66Prefix: vmnet.natIp6Prefix
						                     ))
					}
				} else {
					throw ServiceError("VMWare network \(ethernet.name) not found in the system.")
				}
			}

			return nil
		}

		try createIt.forEach { network in
			logger.info(try NetworksHandler.create(networkName: network.name, network: network.network, runMode: runMode))
		}
	}

	func locateVM(source: String) throws -> VMXMap {
		var url = URL(fileURLWithPath: source)
		var isDirectory: ObjCBool = false

		if FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory) {
			guard isDirectory.boolValue else {
				guard url.pathExtension.lowercased() == "vmx" else {
					throw ServiceError("The provided path is not a directory or a .vmx file.")
				}

				return try VMXMap(fromURL: url)
			}

			return try findVMX(fromURL: url)
		}

		url = URL(fileURLWithPath: "~/Virtual Machines.localized/\(source).vmwarevm".expandingTildeInPath, isDirectory: true)

		guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
			throw ServiceError("No Virtual Machines directory found at \(url.path).")
		}

		guard isDirectory.boolValue else {
			throw ServiceError("The provided path is not a directory. Please provide a valid Virtual Machines directory.")
		}

		return try findVMX(fromURL: url)
	}

	func findVMX(fromURL url: URL) throws -> VMXMap {
		guard let vmxFile = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).first(where: { $0.pathExtension.lowercased() == "vmx" }) else {
			throw ServiceError("No VMX files found in the specified directory: \(url.path)")
		}

		return try VMXMap(fromURL: vmxFile)
	}

}
