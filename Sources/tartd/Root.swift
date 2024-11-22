import ArgumentParser
import Darwin
import Foundation

@main
struct Root: AsyncParsableCommand {
	static var configuration = CommandConfiguration(
		commandName: "tartd",
		version: CI.version,
		subcommands: [
			Service.self,
			Certificates.self,
			Build.self,
			Start.self
		])

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
			guard var command: any ParsableCommand = try parseAsRoot() as any ParsableCommand else {
                var commandName: String?
                var arguments: [String] = []
                for argument in CommandLine.arguments.dropFirst() {
                    if argument.hasPrefix("-") || commandName != nil {
                        arguments.append(argument)
                    } else if commandName == nil {
                        commandName = argument
                    }
                }

				defaultLogger.appendNewLine(try Shell.runTart(command: commandName ?? "", arguments: arguments))

				return
			}

			if var asyncCommand = command as? AsyncParsableCommand {
				try await asyncCommand.run()
			} else {
				try command.run()
			}
		} catch {
			// Handle a non-ArgumentParser's exception that requires a specific exit code to be set
			if let errorWithExitCode = error as? HasExitCode {
				fputs("\(error)\n", stderr)

				Foundation.exit(errorWithExitCode.exitCode)
			}

			// Handle any other exception, including ArgumentParser's ones
			exit(withError: error)
		}
	}
}
