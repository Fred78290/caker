//
//  main.swift
//  helper
//
//  Created by Frederic BOLTZ on 03/11/2026.
//

import ArgumentParser
import CakeAgentLib
import Foundation

struct Helper: ParsableCommand {
	@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
	var logLevel: CakeAgentLib.Logger.LogLevel = .info

	func run() throws {
		CakeAgentLib.Logger.setLevel(self.logLevel)

		// Serves the privileged operations over the Mach service until launchd stops the helper.
		AuthorizationHelperTool().run()
	}
}

Helper.main()
