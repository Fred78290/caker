//
//  Up.swift
//  caked
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import ArgumentParser
import CakedLib
import Foundation
import CakeAgentLib

struct Up: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "up",
		abstract: String(localized: "Start or create VMs defined in .cakerenv"),
		discussion: String(localized: "Reads .cakerenv from the current directory (or --env-file). Starts all VMs in depends-on order, or only the VMs listed as arguments. Creates VMs that do not yet exist.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("env-file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to the environment file"), valueName: "path"))
	var envFile: String?

	@Option(
		help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout: Int = 180

	@Argument(help: ArgumentHelp(String(localized: "VM names to start (default: all VMs in .cakerenv)")))
	var names: [String] = []

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() async throws {
		let env = try loadEnv()
		let vmsToStart = try env.startOrder(filter: names)

		for (vmName, vmSpec) in vmsToStart {
			var buildOpts = try vmSpec.toBuildOptions(name: vmName)
			try buildOpts.validate(remote: false)

			let storage = StorageLocation(runMode: common.runMode)

			if storage.exists(vmName) {
				let location = try storage.find(vmName)
				let reply = StartHandler.startVM(
					location: location,
					screenSize: nil,
					vncPassword: nil,
					vncPort: nil,
					waitIPTimeout: waitIPTimeout,
					startMode: .background,
					gcd: false,
					recoveryMode: false,
					runMode: common.runMode
				)
				Logger.appendNewLine(common.format.render(reply))
			} else {
				let reply = await LaunchHandler.buildAndLaunchVM(
					runMode: common.runMode,
					options: buildOpts,
					waitIPTimeout: waitIPTimeout,
					startMode: .background,
					gcd: false,
					recoveryMode: false,
					progressHandler: ProgressObserver.progressHandler
				)
				Logger.appendNewLine(common.format.render(reply))
			}
		}
	}

	private func loadEnv() throws -> CakerEnv {
		if let path = envFile {
			return try CakerEnv.load(fromFile: path)
		}
		return try CakerEnv.load()
	}
}
