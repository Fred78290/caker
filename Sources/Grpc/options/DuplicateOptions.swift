import ArgumentParser
import Foundation

public struct DuplicateOptions: ParsableArguments {
	public static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Duplicate a VM to a new name")

	@Argument(help: "Source VM name")
	public var from: String

	@Argument(help: "Duplicated VM name")
	public var to: String

	@Option(name: .shortAndLong, help: "Reset mac address")
	public var resetMacAddress: Bool = false

	public init() {
	}
}
