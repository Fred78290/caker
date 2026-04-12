import ArgumentParser
import Foundation

public struct TemplateCreateOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "create", abstract: String(localized: "Add new remote servers"))

	@Argument(help: ArgumentHelp(String(localized: "Source VM name")))
	public var name: String

	@Argument(help: ArgumentHelp(String(localized: "Template name")))
	public var template: String

	@Flag(help: ArgumentHelp(String(localized: "Create template vm in foreground"), discussion: String(localized: "This option allow display window of running vm to debug it"), visibility: .hidden))
	public var foreground: Bool = false

	public init() {
	}
}

public struct TemplateDeletionOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "delete", abstract: String(localized: "Remove remotes"))

	@Argument(help: ArgumentHelp(String(localized: "Template name")))
	public var name: String

	public init() {
	}
}

public struct TemplateListOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "list", abstract: String(localized: "List the available remotes"))

	public init() {
	}
}
