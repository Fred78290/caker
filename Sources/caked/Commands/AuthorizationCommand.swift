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
	import Subprocess
	import System

	struct AuthorizationCommand: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "authorization",
			abstract: String(localized: "Enable or disable privileged operations for Caker"),
			discussion: String(localized: "Allows enabling or disabling privileged operations for Caker."),
			subcommands: [Enable.self, Disable.self])

		private static func cakerPathExecutable() -> FilePath {
			let executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])

			return FilePath(
				stringLiteral:
					executableURL
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.deletingLastPathComponent()
					.appendingPathComponent("MacOS/Caker")
					.path(percentEncoded: false))
		}

		struct Enable: AsyncParsableCommand {
			static let configuration = CommandConfiguration(
				commandName: "enable",
				abstract: String(localized: "Enable privileged operations for Caker"),
				discussion: String(localized: "Enables privileged operations for Caker.")
			)

			@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
			var logLevel: CakeAgentLib.Logger.LogLevel = .info

			@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
			var format: Format = .text

			mutating func validate() throws {
				Logger.setLevel(logLevel)
			}

			func run() async throws {
				let maxSubprocessOutputSize = 100 * 1024 * 1024
				let arguments: Arguments = [
					"authorization",
					"enable",
					"--\(self.format.rawValue)",
				]

				let result = try await Subprocess.run(
					.path(AuthorizationCommand.cakerPathExecutable()),
					arguments: arguments,
					output: .string(limit: maxSubprocessOutputSize),
					error: .string(limit: maxSubprocessOutputSize))

				let stdout = result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty
				let stderr = result.standardError?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty

				if stdout.isEmpty == false {
					FileHandle.standardOutput.write(stdout.data(using: .utf8) ?? Data())
				}

				if stderr.isEmpty == false {
					FileHandle.standardError.write(stderr.data(using: .utf8) ?? Data())
				}
			}
		}

		struct Disable: AsyncParsableCommand {
			static let configuration = CommandConfiguration(
				commandName: "disable",
				abstract: String(localized: "Disable privileged operations for Caker"),
				discussion: String(localized: "Disables privileged operations for Caker.")
			)

			@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
			var logLevel: CakeAgentLib.Logger.LogLevel = .info

			@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
			var format: Format = .text

			mutating func validate() throws {
				Logger.setLevel(logLevel)
			}

			func run() async throws {
				let maxSubprocessOutputSize = 100 * 1024 * 1024
				let arguments: Arguments = [
					"authorization",
					"disable",
					"--\(self.format.rawValue)",
				]

				let result = try await Subprocess.run(
					.path(AuthorizationCommand.cakerPathExecutable()),
					arguments: arguments,
					output: .string(limit: maxSubprocessOutputSize),
					error: .string(limit: maxSubprocessOutputSize))

				let stdout = result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty
				let stderr = result.standardError?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty

				if stdout.isEmpty == false {
					FileHandle.standardOutput.write(stdout.data(using: .utf8) ?? Data())
				}

				if stderr.isEmpty == false {
					FileHandle.standardError.write(stderr.data(using: .utf8) ?? Data())
				}
			}
		}
	}
#endif
