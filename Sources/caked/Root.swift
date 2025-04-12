import ArgumentParser
import Darwin
import Foundation
import Logging
import NIO
import GRPCLib

nonisolated(unsafe) var runAsSystem: Bool = geteuid() == 0

let delegatedCommand: [String] = [
	"clone",
	"pull",
	"push",
	"import",
	"export"
]

let COMMAND_NAME="caked"

@main
struct Root: AsyncParsableCommand {
	static let tartIsPresent = checkIfTartPresent()
	static let sigintSrc: any DispatchSourceSignal = {
		signal(SIGINT, SIG_IGN)
		let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)

		sigintSrc.setEventHandler {
			Self.group.shutdownGracefully { error in
				if let error = error {
					exit(withError: error)
				}
			}

			Foundation.exit(130)
		}

		sigintSrc.activate()

		return sigintSrc
	}()

	static let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
	nonisolated(unsafe)
	static var configuration = CommandConfiguration(
		commandName: "\(COMMAND_NAME)",
		usage: "\(COMMAND_NAME) <subcommand>",
		discussion: "\(COMMAND_NAME) is an hypervisor running VM",
		version: CI.version,
		subcommands: [
			Build.self,
			Certificates.self,
			Configure.self,
			Delete.self,
			Exec.self,
			ImagesManagement.self,
			Infos.self,
			Launch.self,
			List.self,
			Mount.self,
			Networks.self,
			Purge.self,
			Remote.self,
			Rename.self,
			Service.self,
			Sh.self,
			Start.self,
			Stop.self,
			Template.self,
			Umount.self,
			VMRun.self,
			WaitIP.self,
		])

	static func environment() throws -> [String: String] {
		var environment = ProcessInfo.processInfo.environment
		let home = try Utils.getHome(asSystem: runAsSystem)

		environment["TART_HOME"] = home.path

		if environment["CAKE_HOME"] == nil {
			environment["CAKE_HOME"] = home.path
		}

		return environment
	}

	static func vmrunAvailable() -> Bool {
		Self.configuration.subcommands.first { cmd in
			cmd.configuration.commandName == "vmrun"
		} != nil
	}

	static func parse() throws -> ParsableCommand? {
		do {
			return try parseAsRoot()
		} catch {
			if let e: ValidationError = error as? ValidationError {
				Logger.appendNewLine("ValidationError: \(e.localizedDescription)")
			} else {
				Logger.appendNewLine(error.localizedDescription)
			}
			return nil
		}
	}

	private static func checkIfTartPresent() -> Bool {
		guard let _ = URL.binary("tart") else {
			return false
		}

		return true
	}

	func run() async throws {
		await MainUI.main()
	}

	public static func main() async throws {
		// Set up logging to stderr
		LoggingSystem.bootstrap{ label in
			StreamLogHandler.standardError(label: label)
		}

		// Set line-buffered output for stdout
		setlinebuf(stdout)

		// Parse and run command
		do {
			if Self.tartIsPresent {
				configuration.subcommands.append(Login.self)
				configuration.subcommands.append(Logout.self)

				var commandName: String?
				var arguments: [String] = []
				for argument in CommandLine.arguments.dropFirst() {
					if argument.hasPrefix("-") || commandName != nil {
						arguments.append(argument)
					} else if commandName == nil {
						commandName = argument
					}
				}

				if let commandName = commandName {
					if delegatedCommand.contains(commandName) {
						try Shell.runTart(command: commandName, arguments: arguments, direct: true)
						try? await Self.group.shutdownGracefully()
						return
					}
				}
			}

			var command = try parseAsRoot()

			if var asyncCommand = command as? AsyncParsableCommand {
				try await asyncCommand.run()
			} else {
				try command.run()
			}

			try? await Self.group.shutdownGracefully()
		} catch {
			try? await Self.group.shutdownGracefully()

			if let shellError = error as? ShellError {
				//fputs("\(shellError.error)\n", stderr)

				Foundation.exit(shellError.terminationStatus)
			}

			if let errorWithExitCode = error as? HasExitCode {
				Foundation.exit(errorWithExitCode.exitCode)
			}

			// Handle any other exception, including ArgumentParser's ones
			exit(withError: error)
		}
	}
}
