//
//  Compose.swift
//  cakectl
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import ArgumentParser
import CakedLib
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib
import Yams

// MARK: - Parent command

struct Compose: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "compose",
		abstract: String(localized: "Manage VMs from a compose.yml file"),
		discussion: String(localized: "Reads compose.yml (or docker-compose.yml) and manages VMs as services, with the same CLI as docker compose."),
		subcommands: [ComposeUp.self, ComposeDown.self, ComposePs.self, ComposeRm.self, ComposeLs.self, ComposeInit.self]
	)
}

// MARK: - Up

struct ComposeUp: AsyncGrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "up",
		abstract: String(localized: "Create and start services"),
		discussion: String(localized: "Encodes compose.yml and sends it to caked, which provisions networks and starts VMs in depends_on order.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Option(
		help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout: Int = 180

	@Argument(help: ArgumentHelp(String(localized: "Services to start (default: all)")))
	var services: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let compose = try loadCompose()
		let composeDatas = try Data(YAMLEncoder().encode(compose).utf8)

		let reply = try await client.compose(
			.with {
				$0.up = .with {
					$0.composeDatas = composeDatas
					$0.waitIptimeout = Int32(waitIPTimeout)
				}
			},
			callOptions: callOptions
		).response.get().compose.up

		return options.format.render(ComposeReplyUp(reply))
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Down

struct ComposeDown: GrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "down",
		abstract: String(localized: "Stop services"),
		discussion: String(localized: "Stops services registered under this compose project in reverse depends_on order.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Argument(help: ArgumentHelp(String(localized: "Services to stop (default: all)")))
	var services: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let compose = try loadCompose()

		let reply = try client.compose(
			.with { $0.down = .with { $0.name = compose.name } },
			callOptions: callOptions
		).response.wait().compose.down

		return options.format.render(ComposeReplyDown(reply))
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Ps

struct ComposePs: GrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "ps",
		abstract: String(localized: "List service status"),
		discussion: String(localized: "Shows the status of services registered under this compose project.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Argument(help: ArgumentHelp(String(localized: "Services to show (default: all)")))
	var services: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let compose = try loadCompose()

		let reply = try client.compose(
			.with { $0.ps = .with { $0.name = compose.name } },
			callOptions: callOptions
		).response.wait().compose.ps

		return options.format.render(ComposeReplyPs(reply))
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Rm

struct ComposeRm: GrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "rm",
		abstract: String(localized: "Remove and unregister services"),
		discussion: String(localized: "Stops and deletes VMs for services in this compose project, then removes the project from the registry.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Argument(help: ArgumentHelp(String(localized: "Services to remove (default: all)")))
	var services: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let compose = try loadCompose()

		let reply = try client.compose(
			.with { $0.delete = .with { $0.name = compose.name } },
			callOptions: callOptions
		).response.wait().compose.delete

		return options.format.render(ComposeReplyDelete(reply))
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Ls

struct ComposeLs: GrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "ls",
		abstract: String(localized: "List registered compose projects"),
		discussion: String(localized: "Shows all compose projects registered with caked and their service status.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let reply = try client.compose(
			.with { $0.ls = .init() },
			callOptions: callOptions
		).response.wait().compose.ls

		return options.format.render(ComposeReplyList(reply))
	}
}

// MARK: - Init

struct ComposeInit: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "init",
		abstract: String(localized: "Create a compose.yml template"),
		discussion: String(localized: "Writes a commented compose.yml with example services. Edit it then run `cakectl compose up`.")
	)

	@Flag(
		name: [.customLong("force"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Overwrite an existing compose.yml")))
	var force: Bool = false

	func run() throws {
		let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
		let dest = cwd.appendingPathComponent(ComposeFile.filename)

		if FileManager.default.fileExists(atPath: dest.path) && !force {
			throw ValidationError(String(localized: "\(ComposeFile.filename) already exists — use --force to overwrite."))
		}

		try ComposeFile.template.write(to: dest, atomically: true, encoding: .utf8)
		print(String(localized: "Created \(dest.path)"))
		print(String(localized: "Edit compose.yml then run `cakectl compose up` to start your services."))
	}
}
