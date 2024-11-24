import ArgumentParser
import Darwin
import Foundation
import ShellOut

var runAsSystem: Bool = false

let COMMAND_NAME="tartd"
@main
struct Root: AsyncParsableCommand {
	static var configuration = CommandConfiguration(
		commandName: "\(COMMAND_NAME)",
		usage: "\(COMMAND_NAME) <subcommand or tart subcommand>",
		discussion: "\(COMMAND_NAME) is a tool to wrap tart command and add some features like run as daemon, build VM from cloud image",
		version: CI.version,
		subcommands: [
			Service.self,
			Certificates.self,
			Build.self,
			Start.self,
			Launch.self,
			Purge.self
		])

	static func parse() throws -> ParsableCommand? {
		do {
			return try parseAsRoot()
		} catch {
			return nil
		}
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

		// Set line-buffered output for stdout
		setlinebuf(stdout)

		// Parse and run command
		do {
			guard var command = try parse() else {
                var commandName: String?
                var arguments: [String] = []
                for argument in CommandLine.arguments.dropFirst() {
                    if argument.hasPrefix("-") || commandName != nil {
                        arguments.append(argument)
                    } else if commandName == nil {
                        commandName = argument
                    }
                }

				try Shell.runTart(command: commandName ?? "", arguments: arguments, direct: true)

				return
			}

			if var asyncCommand = command as? AsyncParsableCommand {
				try await asyncCommand.run()
			} else {
				try command.run()
			}
		} catch {
			if let shellOutError = error as? ShellOutError {
				fputs("\(shellOutError.message)\n", stderr)
				Foundation.exit(shellOutError.terminationStatus)
			}

			// Handle any other exception, including ArgumentParser's ones
			exit(withError: error)
		}
	}
}
