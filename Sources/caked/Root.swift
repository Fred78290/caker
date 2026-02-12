import ArgumentParser
import CakedLib
import Darwin
import Foundation
import GRPC
import GRPCLib
import NIO
import CakeAgentLib
import Logging

struct CommonOptions: ParsableArguments {
	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: CakeAgentLib.Logger.LogLevel = .info

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	@Flag(
		name: [.customLong("system"), .customShort("s")],
		help: ArgumentHelp(
			"Act as system agent, need sudo", discussion: "Using this argument tell caked to act as system agent, which means it will run as a daemon. This option is useful when you want to run caked as a launchd service", visibility: .private))
	var asSystem: Bool = false

	var runMode: Utils.RunMode {
		self.asSystem ? .system : .user
	}
}

@main
struct Root: ParsableCommand {
	static let sigintSrc: any DispatchSourceSignal = {
		signal(SIGINT, SIG_IGN)
		let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)

		sigintSrc.setEventHandler {
			Utilities.group.shutdownGracefully { error in
				if let error = error {
					exit(withError: error)
				}
			}

			Foundation.exit(130)
		}

		sigintSrc.activate()

		return sigintSrc
	}()

	nonisolated(unsafe)
		static var configuration = CommandConfiguration(
			commandName: "\(Home.cakedCommandName)",
			usage: "\(Home.cakedCommandName) <subcommand>",
			discussion: "\(Home.cakedCommandName) is an hypervisor running VM",
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
				ListObjects.self,
				Mount.self,
				Networks.self,
				Purge.self,
				Remote.self,
				Rename.self,
				Service.self,
				Sh.self,
				Start.self,
				Stop.self,
				Suspend.self,
				Restart.self,
				Template.self,
				Umount.self,
				VMRun.self,
				WaitIP.self,
				Import.self,
				Login.self,
				Logout.self,
				Push.self,
				Pull.self,
			])

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

	public static func main() async throws {
		#if DEBUG
			Self.configuration.subcommands.append(VNC.self)
		#endif

		// Set up logging to stderr
		LoggingSystem.bootstrap { label in
			StreamLogHandler.standardError(label: label)
		}

		// Set line-buffered output for stdout
		setlinebuf(stdout)

		// Parse and run command
		do {
			var command = try parseAsRoot()

			if var asyncCommand = command as? AsyncParsableCommand {
				try await asyncCommand.run()
			} else {
				try command.run()
			}

			try? await Utilities.group.shutdownGracefully()
		} catch {
			try? await Utilities.group.shutdownGracefully()

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
