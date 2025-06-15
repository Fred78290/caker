import ArgumentParser
import Cocoa
import Foundation
import GRPCLib
import Logging
import NIOPortForwarding
import System
import Virtualization
import CakedLib

struct VMRun: AsyncParsableCommand {
	static let configuration = CommandConfiguration(commandName: "vmrun", abstract: "Run VM", shouldDisplay: false)

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Argument(help: "Path to the VM disk.img or his name")
	var path: String

	@Flag(name: [.customLong("service"), .customShort("l")], help: ArgumentHelp("VM running from service", discussion: "This option tell that vm run from service", visibility: .private))
	var launchedFromService: Bool = false

	@Flag(name: [.customLong("lima"), .customShort("m")], help: ArgumentHelp("Use socket-vmnet for network", visibility: .private))
	var useLimaVMNet: Bool = false

	@Flag(help: ArgumentHelp("Show UI", discussion: "This option allow display window of running vm to debug it", visibility: .hidden))
	var display: Bool = false

	var locations: (StorageLocation, VMLocation) {
		if StorageLocation(runMode: self.common.runMode).exists(path) {
			let storageLocation = StorageLocation(runMode: self.common.runMode)
			let vm = try! storageLocation.find(path)

			return (storageLocation, vm)
		} else {
			let u: URL = URL(fileURLWithPath: path)
			let parent = u.deletingLastPathComponent()
			let storage = parent.deletingLastPathComponent()
			let storageLocation = StorageLocation(runMode: self.common.runMode, name: storage.lastPathComponent)
			let vm = VMLocation(rootURL: parent, template: storageLocation.template)

			return (storageLocation, vm)
		}
	}

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let (_, vmLocation) = self.locations

		CakedLib.VMRunHandler.launchedFromService = self.launchedFromService

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
	func run() async throws {
		let (storageLocation, vmLocation) = self.locations
		let config = try vmLocation.config()

		let handler = CakedLib.VMRunHandler(
			storageLocation: storageLocation,
			vmLocation: vmLocation,
			name: vmLocation.name,
			runMode: self.common.runMode,
			display: display,
			config: config)

		try handler.run { vm in
			if display {
				MainApp.runUI(name: vmLocation.name, vm: vm, config: config)
			} else {
				NSApplication.shared.setActivationPolicy(.prohibited)
				NSApplication.shared.run()
			}
		}
	}
}
