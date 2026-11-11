//
//  AuthorizationCommand.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/11/2026.
//
#if USE_AUTHORIZATION_HELPER
import ArgumentParser
import Foundation
import CakeAgentLib
import CakedLib

struct AuthorizationCommand: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "authorization",
		abstract: String(localized: "Enable or disable privileged operations for Caker"),
		discussion: String(localized: "Allows enabling or disabling privileged operations for Caker."),
		subcommands: [Enable.self, Disable.self],
	)

	struct Enable: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "enable",
			abstract: String(localized: "Enable privileged operations for Caker"),
			discussion: String(localized: "Enables privileged operations for Caker.")
		)
		
		func run() throws {
			try DirectAuthorizationHelperConnector.install()
		}
	}
	
	struct Disable: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "disable",
			abstract: String(localized: "Disable privileged operations for Caker"),
			discussion: String(localized: "Disables privileged operations for Caker.")
		)
		
		func run() throws {
			try DirectAuthorizationHelperConnector.uninstall()
		}
	}
}
#endif
