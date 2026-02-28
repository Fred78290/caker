import ArgumentParser
import Foundation

public struct TemplateCreateOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "create", abstract: "Add new remote servers")

	@Argument(help: "Source VM name")
	public var name: String

	@Argument(help: "Template name")
	public var template: String

	@Flag(help: ArgumentHelp("Create template vm in foreground", discussion: "This option allow display window of running vm to debug it", visibility: .hidden))
	public var foreground: Bool = false

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
