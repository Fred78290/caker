//
//  Seamless.swift
//  Caker
//
import AppKit
import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct Seamless: GrpcParsableCommand {
	static var configuration = CommandConfiguration(
		commandName: "seamless",
		abstract: String(localized: "Show the windows of a Linux VM's applications on this desktop"),
		discussion: String(localized: "The guest's windows are relayed by caked over gRPC, so the VM can run under a caked on another host. The command runs until it is interrupted (Ctrl-C) or the service ends the stream.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let config = try client.info(name: self.name, includeConfig: true).vms.status.config

		guard config.seamless else {
			throw ValidationError(String(format: String(localized: "VM %@ does not have seamless windows enabled"), self.name))
		}

		let name = self.name

		// Ctrl-C ends the command like closing the last window would: the stream is closed and the service stops listening.
		Client.sigintSrc.cancel()

		try MainActor.assumeIsolated {
			let app = NSApplication.shared

			app.setActivationPolicy(.regular)

			let manager = SeamlessWindowManager(vmName: name)
			let tunnel = SeamlessTunnelClient()
			let descriptor = try tunnel.open(client: client, vmName: name) { error in
				DispatchQueue.main.async {
					// terminate() ends the process without returning to run(): report the failure here.
					if let error {
						fputs("Error: \(error.reason)\n", stderr)
						Foundation.exit(1)
					}

					NSApplication.shared.terminate(nil)
				}
			}

			manager.attach(fd: descriptor)

			let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)

			signal(SIGINT, SIG_IGN)
			source.setEventHandler {
				tunnel.close()
				NSApplication.shared.terminate(nil)
			}
			source.resume()

			fputs(String(format: String(localized: "Showing the windows of %@, press Ctrl-C to stop\n"), name), stderr)

			app.activate(ignoringOtherApps: true)
			app.run()

			source.cancel()
			tunnel.close()
			manager.stop()
		}

		return String.empty
	}
}
