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

	@Option(name: .customLong("seamless"), help: ArgumentHelp(String(localized: "Allows seamless mode if the VM supports it")))
	var allowSeamless: Bool = true

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

	/// Shows the guest's windows while the shell runs. Only one process can own the windows of a VM: when another one
	/// already does (a first `sh`, `exec` or `seamless`), this one keeps its shell and waits, taking the windows over
	/// as soon as the other lets them go, instead of failing.
	@MainActor
	static func seamless(_ name: String, client: CakedServiceClient) throws {
		let app = NSApplication.shared

		app.setActivationPolicy(.accessory)

		let connection = SeamlessConnection(name: name, client: client)

		try connection.connect()

		app.run()

		connection.stop()
	}

	@MainActor
	private final class SeamlessConnection {
		let name: String
		let client: CakedServiceClient
		var manager: SeamlessWindowManager?
		var tunnel: SeamlessTunnelClient?
		var stopped = false

		init(name: String, client: CakedServiceClient) {
			self.name = name
			self.client = client
		}

		func connect() throws {
			guard self.stopped == false else { return }

			let manager = SeamlessWindowManager(vmName: self.name, displayMode: .none)
			let tunnel = SeamlessTunnelClient()
			let descriptor = try tunnel.open(client: self.client, vmName: self.name) { [weak self] error in
				DispatchQueue.main.async {
					MainActor.assumeIsolated {
						self?.ended(error)
					}
				}
			}

			self.manager = manager
			self.tunnel = tunnel

			manager.attach(fd: descriptor)
		}

		private func ended(_ error: Error?) {
			guard self.stopped == false else { return }

			if let status = error as? GRPCStatus, status.code == .alreadyExists {
				// Someone else shows the windows: try again until they let go.
				self.release()

				DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
					MainActor.assumeIsolated {
						do {
							try self.connect()
						} catch {
							fputs("Error: \(error.reason)\n", stderr)
							Foundation.exit(1)
						}
					}
				}

				return
			}

			// terminate() ends the process without returning to run(): report the failure here.
			if let error {
				fputs("Error: \(error.reason)\n", stderr)
				Foundation.exit(1)
			}

			NSApplication.shared.terminate(nil)
		}

		private func release() {
			self.tunnel?.close()
			self.manager?.stop()
			self.tunnel = nil
			self.manager = nil
		}

		func stop() {
			self.stopped = true
			self.release()
		}
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let config = try client.info(name: self.shell.name, includeConfig: true).vms.status.config

		if config.seamless && allowSeamless {
			Self.disableLoggingOutput = true

			let name = self.shell.name

			// The seamless task blocks the main thread in NSApplication.run(), so a task group
			// can't cancel it (the group waits for every child). Whichever side ends first
			// ends the process instead, which kills the other one.
			let shellTask = Task {
				do {
					Foundation.exit(try await client.shell(name: name, shellUser: self.shell.shellUser, callOptions: callOptions))
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
				Foundation.exit(try await client.shell(name: self.shell.name, shellUser: self.shell.shellUser, callOptions: callOptions))
			}
		}
	}
}
