//
//  Compose.swift
//  caked
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib

// MARK: - Parent command

struct Compose: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "compose",
		abstract: String(localized: "Manage VMs from a compose.yml file"),
		discussion: String(localized: "Reads compose.yml (or docker-compose.yml) and manages VMs as services."),
		subcommands: [ComposeUp.self, ComposeDown.self, ComposePs.self, ComposeRm.self, ComposeInit.self]
	)
}

// MARK: - Up

struct ComposeUp: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "up",
		abstract: String(localized: "Create and start services"),
		discussion: String(localized: "Starts services defined in compose.yml in depends_on order. Creates VMs that do not yet exist.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Option(
		help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout: Int = 180

	@Argument(help: ArgumentHelp(String(localized: "Services to start (default: all)")))
	var services: [String] = []

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() async throws {
		let composeFileDatabase = try Home(runMode: common.runMode).composeFileDatabase()
		let compose = try loadCompose()

		guard compose.name.isEmpty == false else {
			throw ServiceError(String(localized: "compose name must not be empty"))
		}

		var composeStatus: ComposeFileDatabase.ComposeFileStatus

		if let existingStatus = composeFileDatabase.get(compose.name) {
			composeStatus = existingStatus
		} else {
			composeStatus = ComposeFileDatabase.ComposeFileStatus(composeFile: compose)
		}

		let reply = await CakedLib.ComposeHandler.up(compose: &composeStatus, services: services, waitIPTimeout: waitIPTimeout, runMode: common.runMode)

		if reply.success {
			composeFileDatabase.applications[compose.name] = composeStatus
			try composeFileDatabase.save()
		}

		Logger.appendNewLine(self.common.format.render(reply))
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Down

struct ComposeDown: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "down",
		abstract: String(localized: "Stop services"),
		discussion: String(localized: "Stops services in reverse depends_on order.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Flag(
		name: [.customLong("force")],
		help: ArgumentHelp(String(localized: "Force stop without graceful shutdown")))
	var force: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Services to stop (default: all)")))
	var services: [String] = []

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() throws {
		let composeFileDatabase = try Home(runMode: common.runMode).composeFileDatabase()
		let appName = try loadCompose().name

		guard let compose = composeFileDatabase.get(appName) else {
			throw ServiceError(String(localized: "Composition is not registered"))
		}

		Logger.appendNewLine(self.common.format.render(CakedLib.ComposeHandler.down(compose: compose, services: services, force: force, runMode: common.runMode)))
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Ps

struct ComposePs: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "ps",
		abstract: String(localized: "List service status"),
		discussion: String(localized: "Shows which services defined in compose.yml are provisioned on this host.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Argument(help: ArgumentHelp(String(localized: "Services to show (default: all)")))
	var services: [String] = []

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() throws {
		let composeDatabase = try Home(runMode: common.runMode).composeFileDatabase()
		let compose = try loadCompose()

		guard composeDatabase.get(compose.name) != nil else {
			throw ServiceError(String(localized: "Composition is not registered"))
		}

		Logger.appendNewLine(self.common.format.render(CakedLib.ComposeHandler.ps(compose: compose, services: services, runMode: common.runMode)))
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Rm

struct ComposeRm: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "rm",
		abstract: String(localized: "Remove stopped services"),
		discussion: String(localized: "Deletes VMs for services defined in compose.yml, in reverse depends_on order. Use --stop to stop running services first.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Flag(
		name: [.customShort("s"), .customLong("stop")],
		help: ArgumentHelp(String(localized: "Stop running services before removing")))
	var stop: Bool = false

	@Flag(
		name: [.customLong("force")],
		help: ArgumentHelp(String(localized: "Do not error if a service VM is not found")))
	var force: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Services to remove (default: all)")))
	var services: [String] = []

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() throws {
		let composeFileDatabase = try Home(runMode: common.runMode).composeFileDatabase()
		let appName = try loadCompose().name

		guard var compose = composeFileDatabase.get(appName) else {
			throw ServiceError(String(localized: "Composition is not registered"))
		}

		let reply = CakedLib.ComposeHandler.rm(compose: &compose, services: services, stop: stop, force: force, runMode: common.runMode)

		if reply.success {
			composeFileDatabase.remove(appName)
			try composeFileDatabase.save()
		}

		Logger.appendNewLine(self.common.format.render(reply))
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Init

struct ComposeInit: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "init",
		abstract: String(localized: "Create a compose.yml template"),
		discussion: String(localized: "Writes a commented compose.yml with example services. Edit it then run `caked compose up`.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Flag(
		name: [.customLong("force"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Overwrite an existing compose.yml")))
	var force: Bool = false

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() throws {
		let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
		let dest = cwd.appendingPathComponent(ComposeFile.filename)

		if FileManager.default.fileExists(atPath: dest.path) && !force {
			throw ValidationError(String(localized: "\(ComposeFile.filename) already exists — use --force to overwrite."))
		}

		try ComposeFile.template.write(to: dest, atomically: true, encoding: .utf8)
		Logger.appendNewLine(String(localized: "Created \(dest.path)"))
		Logger.appendNewLine(String(localized: "Edit compose.yml then run `caked compose up` to start your services."))
	}
}
