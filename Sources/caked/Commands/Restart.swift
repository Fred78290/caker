//
//  Restart.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//

import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib

struct Restart: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Restart VM(s)")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Argument(help: "VM names to restart")
	var names: [String] = []

	@Flag(help: "Force restart")
	public var force: Bool = false

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var waitIPTimeout = 180

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		let result = CakedLib.RestartHandler.restart(names: names, force: self.force, waitIPTimeout: waitIPTimeout, runMode: self.common.runMode)

		if result.success {
			Logger.appendNewLine(self.common.format.render(result.objects))
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}
