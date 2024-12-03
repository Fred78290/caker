import ArgumentParser
import Darwin
import Foundation

var runAsSystem: Bool = false

let delegatedCommand: [String] = [
	"create",
	"clone",
	"run",
	"set",
	"get",
	"list",
	"login",
	"logout",
	"ip",
	"pull",
	"push",
	"import",
	"export",
	"prune",
	"rename",
	"stop",
	"delete",
	"suspend"
]

let COMMAND_NAME="caked"
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
			Configure.self,
			Remote.self,
			Purge.self
		])

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

					return
				}
			}

			var command = try parseAsRoot()

			if var asyncCommand = command as? AsyncParsableCommand {
				try await asyncCommand.run()
			} else {
				try command.run()
			}
		} catch {
			if let shellError = error as? ShellError {
				fputs("\(shellError.error)\n", stderr)

				Foundation.exit(shellError.terminationStatus)
			}

			// Handle any other exception, including ArgumentParser's ones
			exit(withError: error)
		}
	}
}
