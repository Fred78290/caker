//
//  Root.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/03/2026.
//
import Foundation
import ArgumentParser
import CakeAgentLib
import CakedLib
import GRPCLib
import Logging

struct AuthorizationCommand: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "authorization",
		abstract: String(localized: "Enable or disable privileged operations for Caker"),
		discussion: String(localized: "Allows enabling or disabling privileged operations for Caker."),
		subcommands: [Enable.self, Disable.self],
	)
	struct HelperReply: Codable {
		let success: Bool
		let message: String
	}

	struct Enable: ParsableCommand {
		@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
		var logLevel: CakeAgentLib.Logger.LogLevel = .info

		@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
		var format: Format = .text

		mutating func validate() throws {
			Logger.setLevel(logLevel)
		}

		static let configuration = CommandConfiguration(
			commandName: "enable",
			abstract: String(localized: "Enable privileged operations for Caker"),
			discussion: String(localized: "Enables privileged operations for Caker.")
		)
		
		func run() throws {
			Logger.appendNewLine(self.format.renderSingle(HelperReply(success: DirectAuthorizationHelperConnector.install(), message: String(localized: "Privileged operations enabled successfully."))))
		}
	}
	
	struct Disable: ParsableCommand {
		@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
		var logLevel: CakeAgentLib.Logger.LogLevel = .info
		
		@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
		var format: Format = .text
		
		mutating func validate() throws {
			Logger.setLevel(logLevel)
		}
		static let configuration = CommandConfiguration(
			commandName: "disable",
			abstract: String(localized: "Disable privileged operations for Caker"),
			discussion: String(localized: "Disables privileged operations for Caker.")
		)
		
		func run() throws {
			Logger.appendNewLine(self.format.renderSingle(HelperReply(success: DirectAuthorizationHelperConnector.uninstall(), message: String(localized: "Privileged operations disabled."))))
		}
	}
}

@main
struct Root: ParsableCommand {
	nonisolated(unsafe)
		static var configuration = CommandConfiguration(
			commandName: "\(ProcessInfo.processInfo.processName)",
			version: CI.version,
			subcommands: [
				AuthorizationCommand.self,
			])

	public static func main() async throws {
		do {
			if var command = try? parseAsRoot() {
				if var asyncCommand = command as? AsyncParsableCommand {
					try await asyncCommand.run()
				} else {
					try command.run()
				}
			} else {
				CakeAgentLib.Logger("main").info("Caker is starting...")
				MainApp.main()
			}
		} catch {
			CakeAgentLib.Logger("main").error("Error: \(error.localizedDescription)")
		}
    }
}
