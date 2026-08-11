//
//  Relocate.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/08/2026.
//
import ArgumentParser
import CakeAgentLib
import CakedLib
import GRPCLib

struct Relocate: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "relocate",
		abstract: String(localized: "Move the cake home directory to another location"),
		discussion: String(localized: "Moves CAKE_HOME (VMs, images, caches, ...) to a new path and remembers it for subsequent runs. Not available in the App Store build. Refused while the caked daemon, any virtual machine or any network is running."))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Argument(help: ArgumentHelp(String(localized: "The new location for the cake home directory")))
	var path: String

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		let destination = try CakedLib.CakeHomeHandler.relocate(to: self.path, runMode: self.common.runMode)

		print(destination.path(percentEncoded: false))
	}
}
