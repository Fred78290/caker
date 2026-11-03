//
//  main.swift
//  helper
//
//  Created by Frederic BOLTZ on 03/11/2026.
//

import Foundation
import ArgumentParser
import CakeAgentLib


struct Helper: ParsableCommand {
	@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
	var logLevel: CakeAgentLib.Logger.LogLevel = .info

	public static func main() async throws {
	}
}

