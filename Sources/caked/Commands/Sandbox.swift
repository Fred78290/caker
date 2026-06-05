//
//  Sandbox.swift
//  CakerAppStore
//
//  Created by Frederic BOLTZ on 05/06/2026.
//

import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import CakeAgentLib
import TextTable

struct Sandbox: ParsableCommand {
	struct Result: Codable {
		var sandboxed: Bool
	}

	static let configuration = CommandConfiguration(abstract: String(localized: "Tell if caker is sandboxed or not"))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		let result: Result = Result(sandboxed: Bundle.isApplicationSandboxed)

		Logger.appendNewLine(self.common.format.renderSingle(result))
	}
}
