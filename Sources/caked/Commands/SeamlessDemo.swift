import AppKit
import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib

/// Developer aid for the seamless windows feature: listens like a VM's seamless channel would and shows the
/// guest's windows as native ones, with an in-process fake guest standing in for the real compositor.
struct SeamlessDemo: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "seamless-demo",
		abstract: String(localized: "Show a fake guest's windows through the seamless windows channel"),
		discussion: String(
			localized:
				"Opens the host side of the seamless windows protocol on a unix socket and, unless --no-guest is given, connects an in-process demo guest that draws an animated window. With --no-guest, point a real guest compositor (through a connect://vsock:5100/<socket> socket device) at the printed socket."
		),
		shouldDisplay: false
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(help: ArgumentHelp(String(localized: "Unix socket to listen on"), valueName: "path"))
	var socket: String?

	@Flag(help: ArgumentHelp(String(localized: "Don't start the in-process demo guest")))
	var noGuest: Bool = false

	mutating func run() throws {
		Logger.setLevel(self.common.logLevel)

		let path = self.socket ?? NSTemporaryDirectory() + "caker-seamless-\(getpid()).sock"
		let withGuest = !self.noGuest

		try MainActor.assumeIsolated {
			let app = NSApplication.shared

			app.setActivationPolicy(.regular)

			let manager = SeamlessWindowManager(vmName: "demo", socketPath: path)
			let guest = SeamlessDemoGuest(socketPath: path)
			var sawSession = false

			manager.onSessionChange = { active in
				if active {
					sawSession = true
				} else if sawSession && withGuest {
					// The demo guest closed its window: nothing left to show.
					app.terminate(nil)
				}
			}

			try manager.start()

			print("Seamless channel listening on \(path)")

			if withGuest {
				try guest.connect()
				try guest.start()
			}

			app.activate(ignoringOtherApps: true)
			app.run()

			guest.stop()
			manager.stop()
		}
	}
}
