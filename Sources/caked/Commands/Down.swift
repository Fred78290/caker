//
//  Down.swift
//  caked
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import ArgumentParser
import CakedLib
import Foundation
import CakeAgentLib

struct Down: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "down",
		abstract: String(localized: "Stop the VM defined in .cakerenv"),
		discussion: String(localized: "Reads the VM name from .cakerenv in the current directory (or --env-file) and stops it.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("env-file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to the environment file"), valueName: "path"))
	var envFile: String?

	@Flag(
		name: [.customLong("force")],
		help: ArgumentHelp(String(localized: "Force stop without waiting for graceful shutdown")))
	var force: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "VM name override")))
	var nameOverride: String?

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() throws {
		let env = try loadEnv()
		let vmName = env.resolvedName(override: nameOverride)
		let reply = StopHandler.stopVM(name: vmName, force: force, runMode: common.runMode)
		Logger.appendNewLine(common.format.render([reply]))
	}

	private func loadEnv() throws -> CakerEnv {
		if let path = envFile {
			return try CakerEnv.load(fromFile: path)
		}
		return try CakerEnv.load()
	}
}
