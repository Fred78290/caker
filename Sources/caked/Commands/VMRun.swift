import ArgumentParser
import Foundation
import Logging
import Virtualization
import GRPCLib
import Cocoa
import NIOPortForwarding
import System

struct VMRun: AsyncParsableCommand {
	static var launchedFromService = false

	static let configuration = CommandConfiguration(commandName: "vmrun", abstract: "Run VM", shouldDisplay: false)

	@OptionGroup var common: CommonOptions

	@Argument(help: "Path to the VM disk.img or his name")
	var path: String

	@Flag(name: [.customLong("service"), .customShort("l")], help: .hidden)
	var launchedFromService: Bool = false

	@Flag(name: [.customLong("lima"), .customShort("m")], help: .hidden)
	var useLimaVMNet: Bool = false

	@Flag(help: .hidden)
	var display: Bool = false

	var locations: (StorageLocation, VMLocation) {
		if StorageLocation(asSystem: self.common.asSystem).exists(path) {
			let storageLocation = StorageLocation(asSystem: self.common.asSystem)
			let vm = try! storageLocation.find(path)

			return (storageLocation, vm)
		} else {
			let u: URL = URL(fileURLWithPath: path)
			let parent = u.deletingLastPathComponent()
			let storage = parent.deletingLastPathComponent()
			let storageLocation = StorageLocation(asSystem: self.common.asSystem, name: storage.lastPathComponent)
			let vm = VMLocation(rootURL: parent, template: storageLocation.template)

			return (storageLocation, vm)
		}
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let (_, vmLocation) = self.locations

		Self.launchedFromService = self.launchedFromService

		if vmLocation.inited == false {
			throw ValidationError("VM at \(path) does not exist")
		}

		if vmLocation.status == .running {
			throw ValidationError("VM at \(path) is already running")
		}

		phUseLimaVMNet = self.useLimaVMNet

		let config = try vmLocation.config()

		try config.sockets.forEach {
			try $0.validate()
		}

		if let console = config.console {
			try console.validate()
		}
	}

	@MainActor
	mutating func run() async throws {
		let (storageLocation, vmLocation) = self.locations
		let config = try vmLocation.config()

		let handler = VMRunHandler(storageLocation: storageLocation,
		                           vmLocation: vmLocation,
		                           name: vmLocation.name,
								   asSystem: self.common.asSystem,
		                           display: display,
		                           config: config)

		try handler.run()
	}
}
