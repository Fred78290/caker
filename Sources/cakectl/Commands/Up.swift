//
//  Up.swift
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

struct Up: AsyncGrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "up",
		abstract: String(localized: "Start or create the VM defined in .cakerenv"),
		discussion: String(localized: "Reads .cakerenv from the current directory (or --env-file). If the VM does not exist it is created and started. If it exists but is stopped it is started. If it is already running nothing happens.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("env-file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to the environment file"), valueName: "path"))
	var envFile: String?

	@Option(
		help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout: Int = 180

	@Argument(help: ArgumentHelp(String(localized: "VM name override (defaults to 'name' in .cakerenv or directory name)")))
	var nameOverride: String?

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let env = try loadEnv()
		var buildOpts = try env.toBuildOptions(name: env.resolvedName(override: nameOverride))
		try buildOpts.validate(remote: true)

		// Query current VM status
		let statusReply = try client.info(
			.with {
				$0.name = buildOpts.name
				$0.includeConfig = false
			},
			callOptions: callOptions
		).response.wait().vms.status

		if statusReply.success {
			switch statusReply.infos.status {
			case .running:
				return String(localized: "\(buildOpts.name) is already running.")
			case .paused:
				return String(localized: "\(buildOpts.name) is paused — resume it with `cakectl start \(buildOpts.name)`.")
			default:
				// stopped or unknown → start existing VM
				let startReply = try client.start(
					.with {
						$0.name = buildOpts.name
						$0.waitIptimeout = Int32(waitIPTimeout)
						$0.recoveryMode = false
					},
					callOptions: callOptions
				).response.wait().vms.started
				return options.format.render(startReply)
			}
		}

		// VM doesn't exist → create and start it
		return try await launchVM(buildOpts: buildOpts, client: client, callOptions: callOptions)
	}

	private func launchVM(buildOpts: BuildOptions, client: CakedServiceClient, callOptions: CallOptions?) async throws -> String {
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
						ProgressObserver.progressHandler(.terminated(.success(buildOpts.name), v))
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

	private func loadEnv() throws -> CakerEnv {
		if let path = envFile {
			return try CakerEnv.load(fromFile: path)
		}
		return try CakerEnv.load()
	}
}
