//
//  Sandbox.swift
//  CakerAppStore
//
//  Created by Frederic BOLTZ on 05/06/2026.
//

import ArgumentParser
import Foundation
import GRPCLib
import CakeAgentLib
import TextTable

public struct Sandbox: ParsableCommand {
	struct Result: Codable {
		var sandboxed: Bool
	}

	public static let configuration = CommandConfiguration(abstract: String(localized: "Tell if caker is sandboxed or not"))

	@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
	var logLevel: CakeAgentLib.Logger.LogLevel = .info
	
	@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
	var format: Format = .text

	public init() {

	}

	public func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	public func run() throws {
		let result: Result = Result(sandboxed: Bundle.isApplicationSandboxed)

		Logger.appendNewLine(self.format.renderSingle(result))
	}
}
