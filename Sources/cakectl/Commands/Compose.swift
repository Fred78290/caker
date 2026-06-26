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
		subcommands: [ComposeUp.self, ComposeDown.self, ComposePs.self, ComposeRm.self, ComposeInit.self]
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
	var file: String? = nil

	@Option(
		help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout: Int = 180

	@Argument(help: ArgumentHelp(String(localized: "Services to start (default: all)")))
	var services: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let compose = try loadCompose()
		let toStart = try compose.startOrder(filter: services)
		var output: [String] = []

		// Provision missing networks before starting services
		if let composeNetworks = compose.networks {
			let listReply = try await client.networks(
				.with { $0.command = .infos },
				callOptions: callOptions
			).response.get().networks.list

			let existingNetworks = Set(listReply.success ? listReply.networks.map(\.name) : [])
			let builtins: Set<String> = ["nat", "default", "host", "none"]

			for (networkName, networkConfig) in composeNetworks.sorted(by: { $0.key < $1.key }) {
				guard let networkConfig else { continue }
				guard networkConfig.external != true else { continue }
				guard networkConfig.driver == .bridge else { continue }
				guard !builtins.contains(networkName) else { continue }
				guard networkConfig.driver == .bridge else { throw ServiceError(String(localized: "Only bridge driver is supported")) }
				guard !existingNetworks.contains(networkName) else { continue }

				let network = networkConfig.composeNetworkSubnet(name: networkName)
				let created = try await client.networks(
					.with {
						$0.command = .new
						$0.create = .with {
							$0.name = networkName
							$0.mode = .init(network.mode)
							$0.gateway = network.dhcpStart
							$0.dhcpEnd = network.dhcpEnd
							$0.netmask = network.netmask
							$0.uuid = UUID().uuidString
						}
					},
					callOptions: callOptions
				).response.get().networks.created
				output.append(options.format.render(created))
			}
		}

		for (serviceName, serviceSpec) in toStart {
			var buildOpts = try serviceSpec.toBuildOptions(name: serviceName)
			try buildOpts.validate(remote: true)

			let statusReply = try await client.info(
				.with {
					$0.name = serviceName
					$0.includeConfig = false
				},
				callOptions: callOptions
			).response.get().vms.status

			if statusReply.success {
				switch statusReply.infos.status {
				case .running:
					output.append(String(localized: "\(serviceName) is already running."))
				case .paused:
					output.append(String(localized: "\(serviceName) is paused — resume it with `cakectl start \(serviceName)`."))
				default:
					let startReply = try await client.start(
						.with {
							$0.name = serviceName
							$0.waitIptimeout = Int32(waitIPTimeout)
							$0.recoveryMode = false
						},
						callOptions: callOptions
					).response.get().vms.started
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

	/// Derives a deterministic /24 subnet for a compose network from its name.
	/// Uses the range 192.168.100.x – 192.168.199.x to avoid conflicts with Caker defaults.
	private func composeNetworkSubnet(_ name: String) -> (gateway: String, dhcpEnd: String) {
		let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
		let subnet = 100 + (hash % 100)
		return ("192.168.\(subnet).1", "192.168.\(subnet).254")
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
	var file: String? = nil

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
	var file: String? = nil

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

// MARK: - Rm

struct ComposeRm: GrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "rm",
		abstract: String(localized: "Remove stopped services"),
		discussion: String(localized: "Deletes VMs for services defined in compose.yml, in reverse depends_on order. Use --stop to stop running services first.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

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

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let compose = try loadCompose()
		let toRemove = try compose.downOrder(filter: services)
		var output: [String] = []

		for (serviceName, _) in toRemove {
			if stop {
				_ = try? client.stop(
					.with {
						$0.force = true
						$0.names = .with { $0.list = [serviceName] }
					},
					callOptions: callOptions
				).response.wait()
			}

			let result = try client.delete(
				.with { $0.names = .with { $0.list = [serviceName] } },
				callOptions: callOptions
			).response.wait().vms.delete

			if result.success {
				output.append(options.format.render(result.objects))
			} else if !force {
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
