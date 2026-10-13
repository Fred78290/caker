//
//  CheckUpdate.swift
//  Caker
//
//  Shared by caked and cakectl. Compiled only where Caker.app embeds Sparkle (the SPARKLE flag,
//  i.e. not the App Store build, which gets its updates from the App Store).
//

#if SPARKLE
	import ArgumentParser
	import Foundation
	import GRPCLib
	import CakeAgentLib

	public struct CheckUpdate: AsyncParsableCommand {
		public static let configuration = CommandConfiguration(
			commandName: "check-update",
			abstract: String(localized: "Check whether a newer Caker release is available"),
			discussion: String(localized: "Reads the release feed used by Caker.app's \"Check for Updates…\" and compares its newest release with this version. caked and cakectl ship inside Caker.app: install the new release, or use \"Check for Updates…\" in Caker.app, to update all three.")
		)

		@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
		var logLevel: CakeAgentLib.Logger.LogLevel = .info

		@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
		var format: Format = .text

		public init() {

		}

		public func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		public func run() async throws {
			let status = try await ReleaseUpdateChecker.check()

			Logger.appendNewLine(self.format == .json ? self.format.renderSingle(status) : status.description)
		}
	}
#endif
