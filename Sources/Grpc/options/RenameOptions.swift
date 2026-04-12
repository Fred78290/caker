import ArgumentParser
import Foundation

public struct RenameOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "rename", abstract: String(localized: "Rename a local VM"), aliases: ["mv"])

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	public var name: String

	@Argument(help: ArgumentHelp(String(localized: "New VM name")))
	public var newName: String

	public init() {
	}
}
