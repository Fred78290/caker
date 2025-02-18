import ArgumentParser
import Foundation
import Logging
import Virtualization
import GRPCLib
import Cocoa
import NIOPortForwarding
import System

struct VMRun: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "vmrun", abstract: "Run VM", shouldDisplay: false)

	@Argument
	var name: String

	@Option(help: "location of the VM")
	var storage: String = "vms"

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Flag(name: [.customLong("system"), .customShort("s")])
	var asSystem: Bool = false

	@Flag(help: .hidden)
	var display: Bool = false

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

	mutating func run() throws {
		let storageLocation = StorageLocation(asSystem: asSystem, name: storage)
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
				try config.save()
			}
		}

		let (_, vm) = try vmLocation.startVirtualMachine(on: Root.group.next(), config: config, asSystem: asSystem)

		if display {
			MainApp.runUI(name: name, vm: vm, config: config, false, false)
		} else {
			NSApplication.shared.setActivationPolicy(.prohibited)
			NSApplication.shared.run()
		}
	}
}
