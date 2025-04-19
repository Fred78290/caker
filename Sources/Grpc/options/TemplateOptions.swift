import Foundation
import ArgumentParser

public struct TemplateCreateOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "create", abstract: "Add new remote servers")
	
	@Argument(help: "Source VM name")
	public var name: String
	
	@Argument(help: "Template name")
	public var template: String
	
	public init() {
	}
}

public struct TemplateDeletionOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "delete", abstract: "Remove remotes")
	
	@Argument(help: "Template name")
	public var name: String
	
	public init() {
	}
}

public struct TemplateListOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "list", abstract: "List the available remotes")
	
	public init() {
	}
}
