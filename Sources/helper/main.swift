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

		#if USE_AUTHORIZATION_HELPER
			let logger = Logger(self)

			logger.info("Starting helper tool...")

			let helper = AuthorizationHelperTool()
			let signals = [SIGINT, SIGTERM, SIGQUIT].map { sig in
				signal(sig, SIG_IGN)

				let sig = DispatchSource.makeSignalSource(signal: sig)

				sig.setEventHandler {
					logger.info("Will Helper tool exit with code 128 due to signal \(sig.handle)")

					helper.stop()

					Foundation.exit(128)
				}

				return sig
			}.map { sig in
				sig.activate()

				return sig
			}

			defer {
				signals.forEach { sig in
					sig.cancel()
				}
			}

			// Serves the privileged operations over the Mach service until launchd stops the helper.
			helper.run()
		#endif
	}
}

Helper.main()
