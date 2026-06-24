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

	func run() throws {
		let home = try Utils.getHome(runMode: .user)
		
		print(home.path(percentEncoded: false))
	}
}
