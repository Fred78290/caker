import ArgumentParser
import Foundation

public struct ExecOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "exec", abstract: "Execute a command on a VM")

	@Argument(help: "VM name")
	public var name: String

	@Argument(help: "Command to execute")
	public var arguments: [String]

	@Flag(help: .hidden)
	public var foreground: Bool = false

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	public var waitIPTimeout = 180

	public init() {
	}

	public func validate() throws {
		if arguments.isEmpty {
			throw ValidationError("No command specified")
		}
	}
}
