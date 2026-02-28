import ArgumentParser
import Foundation

public struct ShellOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "shell", abstract: "Run a shell on a VM", aliases: ["sh"])

	@Argument(help: "VM name")
	public var name: String = ""

	@Flag(help: .hidden)
	public var foreground: Bool = false

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	public var waitIPTimeout = 180

	public init() {
	}
}
