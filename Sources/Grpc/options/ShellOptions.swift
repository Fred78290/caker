import ArgumentParser
import Foundation

public struct ShellOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "shell", abstract: String(localized: "Run a shell on a VM"), aliases: ["sh"])

	@Flag(help: .hidden)
	public var foreground: Bool = false

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	public var waitIPTimeout = 180

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	public var name: String = String.empty

	public init() {
	}
}
