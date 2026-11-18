import AppKit
import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
@preconcurrency import GRPC
import GRPCLib
import NIO
import NIOPosix
import NIOSSL
import Logging

struct Sh: GrpcParsableCommand {
	static let configuration = ShellOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Shell options"))
	var shell: ShellOptions

	@Flag(name: .customLong("seamless"), help: ArgumentHelp(String(localized: "Disable seamless mode if the VM supports it")))
	var disableSeamless: Bool = false

	static var disableLoggingOutput = false

	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		try? CakeServiceClientInterceptorFactory(inputHandle: FileHandle.standardInput)
	}

	func logHandler(_ label: String) -> LogHandler {
		if Self.disableLoggingOutput {
			SwiftLogNoOpLogHandler()
		} else {
			StreamLogHandler.standardError(label: label)
		}
	}

	@MainActor
	static func seamless(_ name: String, client: CakedServiceClient) throws {
		let app = NSApplication.shared

		app.setActivationPolicy(.accessory)

		let manager = SeamlessWindowManager(vmName: name, displayMode: .none)
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

		app.run()

		tunnel.close()
		manager.stop()
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let config = try client.info(name: self.shell.name, includeConfig: true).vms.status.config

		if config.seamless && disableSeamless == false {
			Self.disableLoggingOutput = true

			let name = self.shell.name

			// The seamless task blocks the main thread in NSApplication.run(), so a task group
			// can't cancel it (the group waits for every child). Whichever side ends first
			// ends the process instead, which kills the other one.
			let shellTask = Task {
				do {
					Foundation.exit(try await client.shell(name: name, callOptions: callOptions))
				} catch {
					fputs("Error: \(error)\n", stderr)
					Foundation.exit(1)
				}
			}

			// Returns once the seamless windows are closed
			// ArgumentParser runs the command on the main thread
			try MainActor.assumeIsolated {
				try Self.seamless(name, client: client)
			}

			shellTask.cancel()
			Foundation.exit(0)
		} else {
			try Task.sync {
				Foundation.exit(try await client.shell(name: self.shell.name, callOptions: callOptions))
			}
		}
	}
}
