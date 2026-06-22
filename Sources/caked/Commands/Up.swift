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
		abstract: String(localized: "Start or create the VM defined in .cakerenv"),
		discussion: String(localized: "Reads .cakerenv from the current directory (or --env-file). If the VM does not exist it is created and started. If it exists but is stopped it is started. If it is already running nothing happens.")
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

	@Argument(help: ArgumentHelp(String(localized: "VM name override (defaults to 'name' in .cakerenv or directory name)")))
	var nameOverride: String?

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() async throws {
		let env = try loadEnv()
		var buildOpts = try env.toBuildOptions(name: env.resolvedName(override: nameOverride))
		try buildOpts.validate(remote: false)

		let storage = StorageLocation(runMode: common.runMode)

		if storage.exists(buildOpts.name) {
			// VM exists — find its location and start it
			let location = try storage.find(buildOpts.name)
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
			// VM doesn't exist — build and launch it
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

	private func loadEnv() throws -> CakerEnv {
		if let path = envFile {
			return try CakerEnv.load(fromFile: path)
		}
		return try CakerEnv.load()
	}
}
