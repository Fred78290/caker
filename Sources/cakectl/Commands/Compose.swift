//
//  Compose.swift
//  cakectl
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import Yams

// MARK: - Parent command

struct Compose: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "compose",
		abstract: String(localized: "Manage VMs from a compose.yml file"),
		discussion: String(localized: "Reads compose.yml (or docker-compose.yml) and manages VMs as services, with the same CLI as docker compose."),
		subcommands: [ComposeUp.self, ComposeDown.self, ComposePs.self, ComposeRm.self, ComposeLs.self, ComposeEdit.self, ComposeInit.self]
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

	@OptionGroup(title: String(localized: "Compose options"))
	var compose: ComposeOptions

	@Option(
		help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout: Int = 180

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		if let appName = self.compose.name {
			let reply = try await client.compose(
				.with {
					$0.up = .with {
						$0.appName = appName
						$0.waitIptimeout = Int32(waitIPTimeout)
						$0.services = self.compose.services
						$0.replaceDefinition = false  // the file is the user's own definition
					}
				},
				callOptions: callOptions
			).response.get().compose.up

			return options.format.render(ComposeReplyUp(reply))
		} else {
			let compose = try loadCompose()
			let composeDatas = try Data(YAMLEncoder().encode(compose).utf8)

			let reply = try await client.compose(
				.with {
					$0.up = .with {
						$0.datas = composeDatas
						$0.waitIptimeout = Int32(waitIPTimeout)
						$0.services = self.compose.services
						$0.replaceDefinition = true  // the file is the user's own definition
					}
				},
				callOptions: callOptions
			).response.get().compose.up

			return options.format.render(ComposeReplyUp(reply))
		}
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = self.compose.file { return try ComposeFile.load(fromFile: path) }
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

	@OptionGroup(title: String(localized: "Compose options"))
	var compose: ComposeOptions

	@Flag(
		name: [.customLong("force")],
		help: ArgumentHelp(String(localized: "Force stop without graceful shutdown")))
	var force: Bool = false

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let appName = try self.appName()
		let reply = try client.compose(
			.with {
				$0.down = .with {
					$0.name = appName
					$0.services = self.compose.services
					$0.force = force
				}
			},
			callOptions: callOptions
		).response.wait().compose.down

		return options.format.render(ComposeReplyDown(reply))
	}

	private func appName() throws -> String {
		if let name = self.compose.name {
			return name
		} else {
			let compose = try loadCompose()

			return compose.name
		}
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = self.compose.file { return try ComposeFile.load(fromFile: path) }
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

	@OptionGroup(title: String(localized: "Compose options"))
	var compose: ComposeOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let appName = try self.appName()
		let reply = try client.compose(
			.with {
				$0.ps = .with {
					$0.name = appName
					$0.services = self.compose.services
				}
			},
			callOptions: callOptions
		).response.wait().compose.ps

		return options.format.render(ComposeReplyPs(reply))
	}

	private func appName() throws -> String {
		if let name = self.compose.name {
			return name
		} else {
			let compose = try loadCompose()

			return compose.name
		}
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = self.compose.file { return try ComposeFile.load(fromFile: path) }
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

	@OptionGroup(title: String(localized: "Compose options"))
	var compose: ComposeOptions

	@Flag(
		name: [.customLong("stop")],
		help: ArgumentHelp(String(localized: "Stop running services before removing")))
	var stop: Bool = false

	@Flag(
		name: [.customLong("force")],
		help: ArgumentHelp(String(localized: "Force stop without graceful shutdown")))
	var force: Bool = false

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let appName = try self.appName()

		let reply = try client.compose(
			.with {
				$0.delete = .with {
					$0.name = appName
					$0.services = self.compose.services
					$0.force = force
					$0.stop = stop
				}
			},
			callOptions: callOptions
		).response.wait().compose.delete

		return options.format.render(ComposeReplyDelete(reply))
	}

	private func appName() throws -> String {
		if let name = self.compose.name {
			return name
		} else {
			let compose = try loadCompose()

			return compose.name
		}
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = self.compose.file { return try ComposeFile.load(fromFile: path) }
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

// MARK: - Edit

struct ComposeEdit: AsyncGrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "edit",
		abstract: String(localized: "Edit a registered compose project"),
		discussion: String(
			localized:
				"Fetches the project's definition from caked (compose.json), opens it in $VISUAL/$EDITOR and applies it with `compose up` when it changed. With --output the definition is only written to a file. The original compose.yml and its comments are not kept by caked."
		)
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("output"), .customShort("o")],
		help: ArgumentHelp(String(localized: "Write the definition to this file instead of editing it"), valueName: "path"))
	var output: String? = nil

	@Option(
		help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout: Int = 180

	@Argument(help: ArgumentHelp(String(localized: "Name of the registered compose project"), valueName: "name"))
	var name: String

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let list = try await client.compose(.with { $0.ls = .init() }, callOptions: callOptions).response.get().compose.ls

		guard let info = list.composeFiles.map({ ComposeReplyList.ComposeInfo($0) }).first(where: { $0.name == name }) else {
			throw ValidationError(String(format: String(localized: "compose %@ not found"), name))
		}

		// A caked that predates the stored definition in `ls` would only give names and images, and
		// applying that back would wipe the registered definition: refuse instead.
		guard let stored = info.storedComposeFile() else {
			throw ValidationError(String(localized: "This caked does not return the registered definition: update it to use `compose edit`."))
		}

		let yaml = try ComposeFile.editableYAML(for: stored)

		if let output {
			try yaml.write(toFile: output.expandingTildeInPath, atomically: true, encoding: .utf8)
			return String(format: String(localized: "Created %@"), output)
		}

		guard let edited = try ComposeFile.editInEditor(yaml) else {
			return String(localized: "No changes")
		}

		let compose: ComposeFile

		do {
			compose = try ComposeFile.decodeEdited(edited.text, expectedName: name)
		} catch {
			throw ValidationError(String(format: String(localized: "%@\nYour edit was kept in %@"), error.reason, edited.file.path))
		}

		try? FileManager.default.removeItem(at: edited.file)

		let composeDatas = try Data(YAMLEncoder().encode(compose).utf8)
		let reply = try await client.compose(
			.with {
				$0.up = .with {
					$0.datas = composeDatas
					$0.waitIptimeout = Int32(waitIPTimeout)
					$0.replaceDefinition = true  // the edited text is the user's own definition
				}
			},
			callOptions: callOptions
		).response.get().compose.up

		return options.format.render(ComposeReplyUp(reply))
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

		if FileManager.default.fileExists(atPath: dest.path(percentEncoded: false)) && !force {
			throw ValidationError(String(format: String(localized: "%@ already exists — use --force to overwrite."), ComposeFile.filename))
		}

		try ComposeFile.template.write(to: dest, atomically: true, encoding: .utf8)
		print(String(format: String(localized: "Created %@"), dest.path(percentEncoded: false)))
		print(String(localized: "Edit compose.yml then run `cakectl compose up` to start your services."))
	}
}
