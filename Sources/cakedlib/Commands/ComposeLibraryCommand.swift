//
//  ComposeLibraryCommand.swift
//  CakedLib
//
//  `compose library` — shared by caked and cakectl (registered under their `compose` command).
//
//  Unlike the rest of `cakectl compose`, it works on the machine the command is typed on and never
//  talks to caked: the library is a set of files in `<CAKE_HOME>` (see `ComposeLibrary`), and `clone`
//  writes a compose.yml into the *caller's* directory, which is where `cakectl compose up` reads it.
//

import ArgumentParser
import CakeAgentLib
import Foundation
import GRPCLib

public struct ComposeLibraryCommand: ParsableCommand {
	public static let configuration = CommandConfiguration(
		commandName: "library",
		abstract: String(localized: "Browse and clone ready-to-use compose templates"),
		discussion: String(localized: "A library of compose.yml templates for what developers set up most often (databases, web stacks, a Docker host…). It ships with Caker and `library sync` updates it from the GitHub repository into the cake home."),
		subcommands: [ComposeLibraryList.self, ComposeLibraryShow.self, ComposeLibraryClone.self, ComposeLibrarySync.self],
		defaultSubcommand: ComposeLibraryList.self
	)

	public init() {}
}

/// Options every `compose library` subcommand takes.
public struct ComposeLibraryOptions: ParsableArguments {
	@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
	var logLevel: CakeAgentLib.Logger.LogLevel = .info

	// An option rather than the usual `--text`/`--json` flags: caked's and cakectl's own global
	// options claim those before a shared command can see them.
	@Option(name: [.customLong("format")], help: ArgumentHelp(String(localized: "Output format: text or json"), valueName: "format"))
	var format: Format = .text

	public init() {}

	func apply() {
		Logger.setLevel(self.logLevel)
	}
}

/// One row of `compose library list`.
struct ComposeLibraryEntry: Codable {
	let id: String
	let name: String
	let category: String
	let services: String
	let summary: String

	init(_ template: ComposeLibraryTemplate) {
		self.id = template.id
		self.name = template.name
		self.category = template.category
		self.services = template.serviceNames.joined(separator: ", ")
		self.summary = template.summary
	}
}

// MARK: - List

public struct ComposeLibraryList: ParsableCommand {
	public static let configuration = CommandConfiguration(
		commandName: "list",
		abstract: String(localized: "List the templates of the library"),
		discussion: String(localized: "Lists the templates, optionally only those of a category or matching every search word (in the id, name, summary, category or tags).")
	)

	@OptionGroup(title: String(localized: "Library options"))
	var options: ComposeLibraryOptions

	@Option(name: [.customLong("category"), .customShort("c")], help: ArgumentHelp(String(localized: "Only the templates of this category"), valueName: "category"))
	var category: String? = nil

	@Argument(help: ArgumentHelp(String(localized: "Words to search for"), valueName: "search"))
	var search: [String] = []

	public init() {}

	public func validate() throws {
		self.options.apply()
	}

	public func run() throws {
		let library = ComposeLibrary.reloadIfChanged()
		let templates = library.search(self.search.joined(separator: " "), category: self.category)

		if templates.isEmpty {
			Logger.appendNewLine(self.options.format == .json ? self.options.format.renderList([ComposeLibraryEntry]()) : String(localized: "No template matches."))
		} else {
			Logger.appendNewLine(self.options.format.renderList(templates.map(ComposeLibraryEntry.init)))
		}
	}
}

// MARK: - Show

public struct ComposeLibraryShow: ParsableCommand {
	public static let configuration = CommandConfiguration(
		commandName: "show",
		abstract: String(localized: "Print a template"),
		discussion: String(localized: "Prints the compose.yml of a template without writing anything, to read it before cloning it.")
	)

	@OptionGroup(title: String(localized: "Library options"))
	var options: ComposeLibraryOptions

	@Argument(help: ArgumentHelp(String(localized: "Id of the template, as listed by `library list`"), valueName: "id"))
	var id: String

	public init() {}

	public func validate() throws {
		self.options.apply()
	}

	public func run() throws {
		let template = try ComposeLibraryCommand.template(self.id)

		Logger.appendNewLine(self.options.format == .json ? self.options.format.renderSingle(template) : ((try? template.composeText(projectName: nil)) ?? template.compose))
	}
}

// MARK: - Clone

public struct ComposeLibraryClone: ParsableCommand {
	public static let configuration = CommandConfiguration(
		commandName: "clone",
		abstract: String(localized: "Create a compose.yml from a template"),
		discussion: String(localized: "Writes the template as compose.yml in the current directory (or at --output). Edit it, then run `compose up`. With --name the project is renamed, including the compose DNS names its services use to find each other.")
	)

	@OptionGroup(title: String(localized: "Library options"))
	var options: ComposeLibraryOptions

	@Option(name: [.customLong("name"), .customShort("n")], help: ArgumentHelp(String(localized: "Name of the compose project"), valueName: "name"))
	var name: String? = nil

	@Option(name: [.customLong("output"), .customShort("o")], help: ArgumentHelp(String(localized: "File to write, or directory to write compose.yml into"), valueName: "path"))
	var output: String? = nil

	@Flag(name: [.customLong("force"), .customShort("f")], help: ArgumentHelp(String(localized: "Overwrite an existing file")))
	var force: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Id of the template, as listed by `library list`"), valueName: "id"))
	var id: String

	public init() {}

	public func validate() throws {
		self.options.apply()
	}

	public func run() throws {
		let template = try ComposeLibraryCommand.template(self.id)
		let destination = ComposeLibrary.destination(output: self.output)

		try ComposeLibrary.clone(template, projectName: self.name, to: destination, force: self.force)

		Logger.appendNewLine(String(format: String(localized: "Created %@"), destination.path(percentEncoded: false)))
		Logger.appendNewLine(String(localized: "Edit it, then run `compose up` to start your services."))
	}
}

// MARK: - Sync

public struct ComposeLibrarySync: AsyncParsableCommand {
	public static let configuration = CommandConfiguration(
		commandName: "sync",
		abstract: String(localized: "Update the library from the GitHub repository"),
		discussion: String(localized: "Downloads the library published on the main branch of the Caker repository into the cake home, where it replaces the copy bundled with this version. Until the templates are published there, the bundled copy stays in use."),
		aliases: ["update"]
	)

	@OptionGroup(title: String(localized: "Library options"))
	var options: ComposeLibraryOptions

	public init() {}

	public func validate() throws {
		self.options.apply()
	}

	public func run() async throws {
		let result = try await ComposeLibrary.refreshFromGitHub()

		if self.options.format == .json {
			Logger.appendNewLine(self.options.format.renderSingle(result))
			return
		}

		guard result.changed else {
			Logger.appendNewLine(String(format: String(localized: "The compose library is up to date (%d templates)."), result.templates))
			return
		}

		Logger.appendNewLine(String(format: String(localized: "The compose library was updated (%d templates)."), result.templates))

		for (label, ids) in [(String(localized: "added"), result.added), (String(localized: "updated"), result.updated), (String(localized: "removed"), result.removed)] where ids.isEmpty == false {
			Logger.appendNewLine("  \(label): \(ids.joined(separator: ", "))")
		}
	}
}

extension ComposeLibraryCommand {
	/// The template with this id, or an error that names what is available.
	static func template(_ id: String) throws -> ComposeLibraryTemplate {
		let library = ComposeLibrary.reloadIfChanged()

		guard let template = library.template(id: id) else {
			throw ValidationError(String(format: String(localized: "No template '%@' in the compose library. Available: %@"), id, library.templates.map(\.id).joined(separator: ", ")))
		}

		return template
	}
}
