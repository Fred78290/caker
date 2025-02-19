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

		let handler = VMRunHandler(storageLocation: storageLocation,
		                           vmLocation: vmLocation,
		                           name: name, asSystem: asSystem,
		                           display: display,
		                           config: config)

		try handler.handle()
	}
}
