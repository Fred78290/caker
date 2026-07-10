import ArgumentParser
import Foundation

public struct TemplateCreateOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "create", abstract: String(localized: "Add new remote servers"))

	@Flag(help: ArgumentHelp(String(localized: "Create template vm in foreground"), discussion: String(localized: "This option allows display window of running vm to debug it"), visibility: .hidden))
	public var foreground: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Source VM name")))
	public var name: String

	@Argument(help: ArgumentHelp(String(localized: "Template name")))
	public var template: String

	public init() {
	}
}

public struct TemplateDuplicateOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "duplicate", abstract: String(localized: "Clone a template"), aliases: ["clone"])

	@Argument(help: ArgumentHelp(String(localized: "Source template name")))
	public var name: String

	@Argument(help: ArgumentHelp(String(localized: "New template name")))
	public var template: String

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

public struct TemplateInfosOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "infos", abstract: String(localized: "Get info for template"))

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
