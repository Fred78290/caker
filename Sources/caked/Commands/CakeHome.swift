//
//  CakeHome.swift
//  CakerAppStore
//
//  Created by Frederic BOLTZ on 24/06/2026.
//
import ArgumentParser
import CakedLib
import GRPCLib

struct CakeHome: ParsableCommand {
	static let configuration = CommandConfiguration(commandName: "home", abstract: String(localized: "Get home directory location"))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	func run() throws {
		let home = try Utils.getHome(runMode: self.common.runMode, createItIfNotExists: false)

		print(home.path(percentEncoded: false))
	}
}
