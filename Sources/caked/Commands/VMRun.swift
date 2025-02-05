import ArgumentParser
import Foundation
import Logging
import Virtualization
import GRPCLib
import Cocoa
import NIOPortForwarding

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

		if nested && Utils.isNestedVirtualizationSupported() == false {
			self.nested = false
		}

		if self.consoleURL == "file" {
			let  console = URL(fileURLWithPath: "console.log", relativeTo: vmLocation.diskURL).absoluteURL

			self.consoleURL = console.absoluteString
		} else if self.consoleURL == "unix" {
			let  console = URL(fileURLWithPath: "console.sock", relativeTo: vmLocation.diskURL).absoluteURL

			self.consoleURL = console.absoluteString.replacingOccurrences(of: "file:/", with: "unix:/")
		}

		if let consoleURL = consoleURL {
			guard let u: URL = URL(string: consoleURL) else {
				throw ValidationError("Invalid serial console URL")
			}

			if u.scheme != "unix" && u.scheme != "fd" && u.isFileURL == false {
				throw ValidationError("Invalid serial console URL scheme: must be unix, fd or file")
			}

			if u.scheme == "fd" {
				let host = u.host?.split(separator: ",")

				if host == nil || host!.count == 0 {
					throw ValidationError("Invalid console URL: file descriptor is not specified")
				}

				for fd in host! {
					guard let fd = Int32(fd) else {
						throw ValidationError("Invalid console URL: file descriptor \(fd) is not a number")
					}

					if fcntl(fd, F_GETFD) == -1 {
						throw ValidationError("Invalid console URL: file descriptor \(fd) is not valid errno=\(errno)")
					}
				}
			} else {
				if u.path == "" {
					throw ValidationError("Invalid console URL")
				}

				if u.scheme == "unix" && u.path.utf8.count > 103 {
					throw ValidationError("The unix socket is too long")
				}
			}
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

		if var config = vmLocation.config, let macAddress = config.macAddress {
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
		                            networks: try collectNetworks(),
		                            additionalDiskAttachments: try additionalDiskAttachments(),
		                            directorySharingAttachments: directorySharingAttachments(),
		                            socketDeviceAttachments: try socketDeviceAttachments(),
		                            consoleURL: consoleURL.flatMap { URL(string: $0) },
		                            nested: nested)

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

	func socketDeviceAttachments() throws -> [SocketDevice] {
		try vsocks.map {
			try SocketDevice(description: $0)
		}
	}

	func collectNetworks() throws -> [NetworkAttachement] {
		var networks: [NetworkAttachement] = [SharedNetworkInterface()]

		networks.append(contentsOf: netBridged.compactMap { inf in
			let foundInterface = VZBridgedNetworkInterface.networkInterfaces.first {
				$0.identifier == inf || $0.localizedDisplayName == inf
			}

			if let interface = foundInterface {
				return BridgedNetworkInterface(interface: interface)
			} else {
				Logger.warn("Network interface \(inf) not found")
			}

			return nil
		})

		return networks
	}

	func additionalDiskAttachments() throws -> [VZStorageDeviceConfiguration] {
		return try disk.compactMap {
			try DiskAttachement(parseFrom: $0).configuration
		}
	}

	func directorySharingAttachments() throws -> [VZDirectorySharingDeviceConfiguration] {
		let allDirectoryShares = try dir.compactMap { 
			try DirectorySharingAttachment(parseFrom: $0)
		}

		return Dictionary(grouping: allDirectoryShares, by: {$0.mountTag}).map { mountTag, directoryShares in
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
}
