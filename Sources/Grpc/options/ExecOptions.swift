import ArgumentParser
import Foundation

public struct ExecOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "exec", abstract: String(localized: "Execute a command on a VM"), aliases: ["run"])

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	public var name: String

	@Argument(help: ArgumentHelp(String(localized: "Command to execute")))
	public var arguments: [String]

	@Flag(help: .hidden)
	public var foreground: Bool = false

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	public var waitIPTimeout = 180

	public init() {
	}

	public func validate() throws {
		if arguments.isEmpty {
			throw ValidationError(String(localized: "No command specified"))
		}
	}
}
