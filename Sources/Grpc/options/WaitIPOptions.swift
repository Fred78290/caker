import ArgumentParser
import Foundation

public struct WaitIPOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "waitip", abstract: String(localized: "Wait for ip of a running VM"), aliases: ["ip"])

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	public var name: String

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	public var wait: Int = 0

	public init() {
	}
}
