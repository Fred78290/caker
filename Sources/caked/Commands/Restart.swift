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
	static let configuration = CommandConfiguration(abstract: String(localized: "Restart VM(s)"),  aliases: ["rs"])

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Flag(help: ArgumentHelp(String(localized: "Force restart")))
	public var force: Bool = false

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout = 180

	@Argument(help: ArgumentHelp(String(localized: "VM names to restart")))
	var names: [String] = []

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		let result = CakedLib.RestartHandler.restart(names: names, startMode: .background, gcd: false, force: self.force, waitIPTimeout: waitIPTimeout, runMode: self.common.runMode)

		if result.success {
			Logger.appendNewLine(self.common.format.render(result.objects))
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}
