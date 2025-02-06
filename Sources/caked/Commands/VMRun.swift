import ArgumentParser
import Foundation
import Logging
import Virtualization
import GRPCLib
import Cocoa
import NIOPortForwarding

extension CakeConfig {
	func additionalDiskAttachments() throws -> [VZStorageDeviceConfiguration] {
		let cloudInit = URL(fileURLWithPath: "cloud-init.iso", relativeTo: self.location).absoluteURL
		var attachedDisks: [VZStorageDeviceConfiguration] = []
		
		attachedDisks.append(contentsOf: self.disks)
		
		if cloudInit.exists() {
			let attachment = try VZDiskImageStorageDeviceAttachment(url: cdromURL, readOnly: true, cachingMode: .cached, synchronizationMode: VZDiskImageSynchronizationMode.none)

			let cdrom = VZVirtioBlockDeviceConfiguration(attachment: attachment)

			cdrom.blockDeviceIdentifier = "CIDATA"
			
			attachedDisks.append(cdrom)
		}

		return attachedDisks
	}
	
	func directorySharingAttachments() throws -> [VZDirectorySharingDeviceConfiguration] {
		return Dictionary(grouping: self.mounts, by: {$0.mountTag}).map { mountTag, directoryShares in
			let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: mountTag)
			var directories: [String : VZSharedDirectory] = [:]
			
			directoryShares.forEach {
				if let config = $0.configuration {
					directories[$0.name] = config
				}
			}
			
			sharingDevice.share = VZMultipleDirectoryShare(directories: directories)
			
			return sharingDevice
		}
	}
	
	func socketDeviceAttachments() throws -> [SocketDevice] {
		let vsock = URL(fileURLWithPath: "agent.sock", relativeTo: self.location).absoluteURL.path()
		let agent = try SocketDevice(parseFrom: "--vsock=bind://any:5000\(vsock)")
		var sockets: [SocketDevice] = [agent]

		FileManager.default.removeItem(atPath: vsock)
		
		sockets.append(contentsOf: self.sockets)
		
		return sockets
	}
	
	func consoleAttachment() throws -> URL? {
		if let console = self.console {
			return try console.consoleURL(vmDir: self.location)
		}

		return nil
	}
}

struct VMRun: AsyncParsableCommand {
	static var configuration = CommandConfiguration(commandName: "vmrun", abstract: "Run VM", shouldDisplay: false)

	@Argument
	var name: String

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Flag(name: [.customLong("system"), .customShort("s")])
	var asSystem: Bool = false

	mutating func validate() throws {
		Logger.setLevel(self.logLevel)

		let storageLocation = StorageLocation(asSystem: asSystem)

		if storageLocation.exists(name) == false {
			throw ValidationError("VM \(name) does not exist")
		}

		let vmLocation = try storageLocation.find(name)

		if vmLocation.status == .running {
			throw ValidationError("VM \(name) is already running")
		}
	}

	@MainActor
	mutating func run() async throws {
		let storageLocation = StorageLocation(asSystem: asSystem)
		let vmLocation = try storageLocation.find(name)

		try vmLocation.writePID()

		defer {
			vmLocation.removePID()
		}

		var config = try vmLocation.loadConfig()
		
		if let macAddress = config.macAddress {
			let vmHavingSameMacAddress = try storageLocation.list().first {
				if let addr = $1.macAddress {
					return $1.status == .running && addr.string == macAddress.string
				}

				return false
			}

			if vmHavingSameMacAddress != nil {
				Logger.warn("This VM \(vmHavingSameMacAddress!.value.name) is running with the same mac address. Generating a new mac address")
				config.resetMacAddress()
			}
		}

		let vm = try VirtualMachine(vmLocation: vmLocation,
									networks: try config.collectNetworks(),
									additionalDiskAttachments: try config.additionalDiskAttachments(),
									directorySharingAttachments: try config.directorySharingAttachments(),
									socketDeviceAttachments: try config.socketDeviceAttachments(),
									consoleURL: try config.consoleAttachment(),
									nested: config.nested)

		let task: Task<Void, Error> = Task {
			try await vm.start()
			try await vm.run()
		}

		vm.catchSIGINT(task)
		vm.catchSIGUSR1(task)
		vm.catchSIGUSR2(task)

		NSApplication.shared.setActivationPolicy(.prohibited)
		NSApplication.shared.run()
	}
}
