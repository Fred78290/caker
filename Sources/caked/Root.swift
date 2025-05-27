import ArgumentParser
import Darwin
import Foundation
import GRPC
import GRPCLib
import Logging
import NIO

let delegatedCommand: [String] = [
	"pull",
	"push",
	"import",
	"export",
]

let COMMAND_NAME = "caked"

struct CommonOptions: ParsableArguments {
	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	@Flag(
		name: [.customLong("system"), .customShort("s")],
		help: ArgumentHelp(
			"Act as system agent, need sudo", discussion: "Using this argument tell caked to act as system agent, which means it will run as a daemon. This option is useful when you want to run caked as a launchd service", visibility: .private))
	var asSystem: Bool = false
}

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
				Duplicate.self,
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

	static func environment(asSystem: Bool) throws -> [String: String] {
		var environment = ProcessInfo.processInfo.environment
		let home = try Utils.getHome(asSystem: asSystem)

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
		guard URL.binary("tart") != nil else {
			return false
		}

		return true
	}

	func run() async throws {
		await MainUI.main()
	}

	public static func main() async throws {
		// Set up logging to stderr
		LoggingSystem.bootstrap { label in
			StreamLogHandler.standardError(label: label)
		}

		// Set line-buffered output for stdout
		setlinebuf(stdout)

		// Parse and run command
		do {
			if Self.tartIsPresent {
				configuration.subcommands.append(Clone.self)
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
						try Shell.runTart(command: commandName, arguments: arguments, direct: true, asSystem: geteuid() == 0)
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

			if let err = error as? GRPCStatus {
				let description = err.code == .unavailable || err.code == .cancelled ? "Connection refused" : err.description
				FileHandle.standardError.write("\(description)\n".data(using: .utf8)!)
				Foundation.exit(Int32(err.code.rawValue))
			}

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
