import Foundation
import ArgumentParser

public struct RenameOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: "Rename a local VM")
	
	@Argument(help: "VM name")
	public var name: String
	
	@Argument(help: "New VM name")
	public var newName: String
	
	public init() {
	}
}
