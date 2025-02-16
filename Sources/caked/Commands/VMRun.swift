import ArgumentParser
import Foundation
import Logging
import Virtualization
import GRPCLib
import Cocoa
import NIOPortForwarding
import System

extension CakeConfig {
	func collectNetworks() throws -> [NetworkAttachement] {
		if networks.isEmpty {
			if let macAddress = self.macAddress {
				return [SharedNetworkInterface(macAddress: macAddress)]
			}

			return [SharedNetworkInterface(macAddress: VZMACAddress.randomLocallyAdministered())]
		}

		return networks.compactMap { inf in
			if inf.network == "nat" || inf.network == "NAT shared network" {
				if let macAddress = self.macAddress {
					return SharedNetworkInterface(macAddress: macAddress)
				}

				return SharedNetworkInterface(macAddress: VZMACAddress.randomLocallyAdministered())
			}

			let foundInterface = VZBridgedNetworkInterface.networkInterfaces.first {
				$0.identifier == inf.network || $0.localizedDisplayName == inf.network
			}

			if let interface = foundInterface {
				if let macAddress = inf.macAddress, let mac = VZMACAddress(string: macAddress) {
					return BridgedNetworkInterface(interface: interface, macAddress: mac)
				}

				return BridgedNetworkInterface(interface: interface, macAddress: VZMACAddress.randomLocallyAdministered())	
			}

			Logger.warn("Network interface \(inf.network) not found")

			return nil
		}
	}

	func additionalDiskAttachments() throws -> [VZStorageDeviceConfiguration] {
		let cloudInit = URL(fileURLWithPath: "cloud-init.iso", relativeTo: self.location).absoluteURL
		var attachedDisks: [VZStorageDeviceConfiguration] = []

		attachedDisks.append(contentsOf: self.disks.compactMap { try? $0.configuration() })

		if try cloudInit.exists() {
			let attachment = try VZDiskImageStorageDeviceAttachment(url: cloudInit, readOnly: true, cachingMode: .cached, synchronizationMode: VZDiskImageSynchronizationMode.none)

			let cdrom = VZVirtioBlockDeviceConfiguration(attachment: attachment)

			cdrom.blockDeviceIdentifier = "CIDATA"

			attachedDisks.append(cdrom)
		}

		return attachedDisks
	}

	func directorySharingAttachments() throws -> [VZDirectorySharingDeviceConfiguration] {
		return Dictionary(grouping: self.mounts, by: {$0.mountTag}).map { (mountTag: String, directoryShares: [DirectorySharingAttachment]) in
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
		var sockets: [SocketDevice] = [SocketDevice(mode: SocketMode.bind, port: 5000, bind: vsock)]

		if FileManager.default.fileExists(atPath: vsock) {
			try FileManager.default.removeItem(atPath: vsock)
		}

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

struct VMRun: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "vmrun", abstract: "Run VM", shouldDisplay: false)

	@Argument
	var name: String

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Flag(name: [.customLong("system"), .customShort("s")])
	var asSystem: Bool = false

	mutating func validate() throws {
		Logger.setLevel(self.logLevel)

		runAsSystem = asSystem

		let storageLocation = StorageLocation(asSystem: asSystem)

		if storageLocation.exists(name) == false {
			throw ValidationError("VM \(name) does not exist")
		}

		let vmLocation = try storageLocation.find(name)

		if vmLocation.status == .running {
			throw ValidationError("VM \(name) is already running")
		}
	}

//	@MainActor
	mutating func run() throws {
		let storageLocation = StorageLocation(asSystem: asSystem)
		let vmLocation = try storageLocation.find(name)
		let config = try vmLocation.config()

		defer {
			vmLocation.removePID()
		}

		if let macAddress = config.macAddress {
			let vmHavingSameMacAddress = try storageLocation.list().first {
				var result = false

				if let addr = $1.macAddress {
					result = $1.status == .running && addr.string == macAddress.string
				}

				return result
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

		let task = Task {
			try vmLocation.writePID()

			do {
				try await vm.start()
				try await vm.run()
		
		        Foundation.exit(0)

			} catch {
		        Foundation.exit(1)
			}
		}

		vm.catchUserSignals(task)

		MainApp.runUI(vm: vm, false, false)
		NSApplication.shared.setActivationPolicy(.prohibited)
		NSApplication.shared.run()
	}
}
