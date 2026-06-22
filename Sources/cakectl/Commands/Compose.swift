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

// MARK: - Parent command

struct Compose: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "compose",
		abstract: String(localized: "Manage VMs from a compose.yml file"),
		discussion: String(localized: "Reads compose.yml (or docker-compose.yml) and manages VMs as services, with the same CLI as docker compose."),
		subcommands: [ComposeUp.self, ComposeDown.self, ComposePs.self, ComposeInit.self]
	)
}

// MARK: - Up

struct ComposeUp: AsyncGrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "up",
		abstract: String(localized: "Create and start services"),
		discussion: String(localized: "Starts services defined in compose.yml in depends_on order. Creates VMs that do not yet exist.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String?

	@Option(
		help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout: Int = 180

	@Argument(help: ArgumentHelp(String(localized: "Services to start (default: all)")))
	var services: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let compose = try loadCompose()
		let toStart = try compose.startOrder(filter: services)
		var output: [String] = []

		for (serviceName, serviceSpec) in toStart {
			var buildOpts = try serviceSpec.toBuildOptions(name: serviceName)
			try buildOpts.validate(remote: true)

			let statusReply = try client.info(
				.with {
					$0.name = serviceName
					$0.includeConfig = false
				},
				callOptions: callOptions
			).response.wait().vms.status

			if statusReply.success {
				switch statusReply.infos.status {
				case .running:
					output.append(String(localized: "\(serviceName) is already running."))
				case .paused:
					output.append(String(localized: "\(serviceName) is paused — resume it with `cakectl start \(serviceName)`."))
				default:
					let startReply = try client.start(
						.with {
							$0.name = serviceName
							$0.waitIptimeout = Int32(waitIPTimeout)
							$0.recoveryMode = false
						},
						callOptions: callOptions
					).response.wait().vms.started
					output.append(options.format.render(startReply))
				}
			} else {
				output.append(try await launchService(buildOpts: buildOpts, serviceName: serviceName, client: client, callOptions: callOptions))
			}
		}

		return output.joined(separator: "\n")
	}

	private func launchService(buildOpts: BuildOptions, serviceName: String, client: CakedServiceClient, callOptions: CallOptions?) async throws -> String {
		return try await withThrowingTaskGroup(of: Void.self, returning: String.self) { group in
			let context = ProgressObserver.ProgressHandlerContext()
			let (stream, continuation) = AsyncStream.makeStream(of: Caked_LaunchStreamReply.OneOf_Current?.self)
			var result = String.empty

			group.addTask {
				let rpc = try client.launch(
					.with {
						$0.options = try Caked_CommonBuildRequest(buildOptions: buildOpts)
						$0.waitIptimeout = Int32(waitIPTimeout)
						$0.recoveryMode = false
					}
				) { reply in
					continuation.yield(reply.current)
				}
				_ = try await rpc.status.get()
				continuation.finish()
			}

			for try await current in stream {
				switch current {
				case .progress(let p):
					ProgressObserver.progressHandler(.progress(context, p.fractionCompleted))
				case .step(let step):
					ProgressObserver.progressHandler(.step(step))
				case .terminated(let status):
					if case .success(let v)? = status.result {
						ProgressObserver.progressHandler(.terminated(.success(serviceName), v))
					} else if case .failure(let v)? = status.result {
						ProgressObserver.progressHandler(.terminated(.failure(GrpcError(code: 1, reason: v)), nil))
					}
				case .launched(let launched):
					result = options.format.render(LaunchReply(launched))
				default:
					break
				}
			}

			return result
		}
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
		abstract: String(localized: "Stop and remove services"),
		discussion: String(localized: "Stops services in reverse depends_on order.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String?

	@Flag(
		name: [.customLong("force")],
		help: ArgumentHelp(String(localized: "Force stop without graceful shutdown")))
	var force: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Services to stop (default: all)")))
	var services: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let compose = try loadCompose()
		let toStop = try compose.downOrder(filter: services)
		var output: [String] = []

		for (serviceName, _) in toStop {
			let result = try client.stop(
				.with {
					$0.force = force
					$0.names = .with { $0.list = [serviceName] }
				},
				callOptions: callOptions
			).response.wait().vms.stop

			if result.success {
				output.append(options.format.render(result.objects))
			} else {
				output.append(options.format.render(result.reason))
			}
		}

		return output.joined(separator: "\n")
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
		discussion: String(localized: "Shows the status of services defined in compose.yml.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String?

	@Argument(help: ArgumentHelp(String(localized: "Services to show (default: all)")))
	var services: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let compose = try loadCompose()
		let resolved = compose.resolvedServices(filter: services)
		var output: [String] = []

		for (serviceName, _) in resolved {
			let reply = try client.info(
				.with {
					$0.name = serviceName
					$0.includeConfig = false
				},
				callOptions: callOptions
			).response.wait().vms.status

			if reply.success {
				output.append("[\(serviceName)]")
				output.append(options.format.render(reply.infos))
			} else {
				output.append("[\(serviceName)] not found")
			}
		}

		return output.joined(separator: "\n")
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
