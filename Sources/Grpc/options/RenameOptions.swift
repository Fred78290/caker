import ArgumentParser
import Foundation

public struct RenameOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "rename", abstract: "Rename a local VM", aliases: ["mv"])

	@Argument(help: "VM name")
	public var name: String

	@Argument(help: "New VM name")
	public var newName: String

	public init() {
	}
}
