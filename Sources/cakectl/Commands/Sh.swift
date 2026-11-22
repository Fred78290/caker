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
	/// The terminal as it is before the shell stream makes it raw, to give it back when the process ends by `exit`
	/// (which skips the stream's own restoration).
	static func saveTerminal() -> termios? {
		let input = FileHandle.standardInput

		guard input.isTTY() else { return nil }

		return try? input.getState()
	}

	static func restoreTerminal(_ terminal: termios?) {
		if var terminal {
			try? FileHandle.standardInput.restoreState(&terminal)
		}
	}

	static func exit(_ code: Int32, restoring terminal: termios?) -> Never {
		Self.restoreTerminal(terminal)

		Foundation.exit(code)
	}

	@MainActor
	static func seamless(_ name: String, client: CakedServiceClient, terminal: termios? = nil) throws {
		let app = NSApplication.shared

		app.setActivationPolicy(.accessory)

		let connection = SeamlessConnection(name: name, client: client, terminal: terminal)

		try connection.connect()

		app.run()

		connection.stop()
	}

	@MainActor
	final class SeamlessConnection {
		let name: String
		let client: CakedServiceClient
		let displayMode: VMRunHandler.DisplayMode
		let announceWaiting: Bool
		/// `false` ends the process, successfully, when another process already shows the windows: `app run` only has to start the application.
		let waitsForOwner: Bool
		let terminal: termios?
		var manager: SeamlessWindowManager?
		var tunnel: SeamlessTunnelClient?
		var stopped = false
		var waitingAnnounced = false

		init(name: String, client: CakedServiceClient, displayMode: VMRunHandler.DisplayMode = .none, announceWaiting: Bool = false, waitsForOwner: Bool = true, terminal: termios? = nil) {
			self.name = name
			self.client = client
			self.displayMode = displayMode
			self.announceWaiting = announceWaiting
			self.waitsForOwner = waitsForOwner
			self.terminal = terminal
		}

		func connect() throws {
			guard self.stopped == false else { return }

			let manager = SeamlessWindowManager(vmName: self.name, displayMode: self.displayMode)
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

			// Retrying can change these: someone else shows the windows (until they let go), or the guest
			// compositor went away or restarted (the client's protocol state belongs to one guest connection).
			if let status = error as? GRPCStatus, status.code == .alreadyExists || status.code == .unavailable {
				self.release()

				if status.code == .alreadyExists && self.waitsForOwner == false {
					// terminate() ends the process without returning to run(): give the terminal back first.
					Sh.restoreTerminal(self.terminal)
					NSApplication.shared.terminate(nil)

					return
				}

				if status.code == .alreadyExists && self.announceWaiting && self.waitingAnnounced == false {
					self.waitingAnnounced = true
					fputs(String(format: String(localized: "The windows of VM %@ are shown by another process, waiting for it to let them go\n"), self.name), stderr)
				}

				DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
					MainActor.assumeIsolated {
						do {
							try self.connect()
						} catch {
							fputs("Error: \(error.reason)\n", stderr)
							Sh.exit(1, restoring: self.terminal)
						}
					}
				}

				return
			}

			// terminate() ends the process without returning to run(): report the failure here.
			if let error {
				fputs("Error: \(error.reason)\n", stderr)
				Sh.exit(1, restoring: self.terminal)
			}

			Sh.restoreTerminal(self.terminal)
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
			let terminal = Self.saveTerminal()

			// The seamless task blocks the main thread in NSApplication.run(), so a task group
			// can't cancel it (the group waits for every child). Whichever side ends first
			// ends the process instead, which kills the other one.
			let shellTask = Task {
				do {
					Self.exit(try await client.shell(name: name, shellUser: self.shell.shellUser, callOptions: callOptions), restoring: terminal)
				} catch {
					fputs("Error: \(error)\n", stderr)
					Self.exit(1, restoring: terminal)
				}
			}

			// Returns once the seamless windows are closed
			// ArgumentParser runs the command on the main thread
			try MainActor.assumeIsolated {
				try Self.seamless(name, client: client, terminal: terminal)
			}

			shellTask.cancel()
			Self.exit(0, restoring: terminal)
		} else {
			try Task.sync {
				Foundation.exit(try await client.shell(name: self.shell.name, shellUser: self.shell.shellUser, callOptions: callOptions))
			}
		}
	}
}
