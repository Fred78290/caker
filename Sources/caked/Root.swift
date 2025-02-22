import ArgumentParser
import Darwin
import Foundation
import Logging
import NIO

var runAsSystem: Bool = false

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

	static var group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
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
			Networks.self,
			Purge.self,
			Remote.self,
			Rename.self,
			Service.self,
			Sh.self,
			Start.self,
			Stop.self,
			Template.self,
			VMRun.self,
			WaitIP.self
		])

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
				print("ValidationError: \(e.localizedDescription)")
			} else {
				print(error.localizedDescription)
			}
			return nil
		}
	}

	private static func checkIfTartPresent() -> Bool {
		let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/usr/local/bin:/bin:/sbin:/usr/sbin:/opt/bin"

		return path.split(separator: ":").first { dir in
			FileManager.default.isExecutableFile(atPath: "\(dir)/tart")
		} != nil
	}

	public static func main() async throws {
		// Ensure the default SIGINT handled is disabled,
		// otherwise there's a race between two handlers
		signal(SIGINT, SIG_IGN)
		// Handle cancellation by Ctrl+C ourselves
		let task = withUnsafeCurrentTask { $0 }!
		let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
		sigintSrc.setEventHandler {
			task.cancel()
		}
		sigintSrc.activate()

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
