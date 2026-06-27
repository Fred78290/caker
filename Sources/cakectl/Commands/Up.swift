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
		abstract: String(localized: "Start or create VMs defined in .cakerenv"),
		discussion: String(localized: "Reads .cakerenv from the current directory (or --env-file). Starts all VMs in depends-on order, or only the VMs listed as arguments. Creates VMs that do not yet exist.")
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

	@Argument(help: ArgumentHelp(String(localized: "VM names to start (default: all VMs in .cakerenv)")))
	var names: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let env = try loadEnv()
		let vmsToStart = try env.startOrder(filter: names)
		var output: [String] = []

		for (vmName, vmSpec) in vmsToStart {
			var buildOpts = try vmSpec.toBuildOptions(name: vmName)
			try buildOpts.validate(remote: true)

			let statusReply = try await client.info(
				.with {
					$0.name = vmName
					$0.includeConfig = false
				},
				callOptions: callOptions
			).response.get().vms.status

			if statusReply.success {
				switch statusReply.infos.status {
				case .running:
					output.append(String(localized: "\(vmName) is already running."))
				case .paused:
					output.append(String(localized: "\(vmName) is paused — resume it with `cakectl start \(vmName)`."))
				default:
					let startReply = try await client.start(
						.with {
							$0.name = vmName
							$0.waitIptimeout = Int32(waitIPTimeout)
							$0.recoveryMode = false
						},
						callOptions: callOptions
					).response.get().vms.started
					output.append(options.format.render(startReply))
				}
			} else {
				output.append(try await launchAndStream(buildOpts: buildOpts, name: vmName, waitIPTimeout: waitIPTimeout, client: client, callOptions: callOptions, format: options.format))
			}
		}

		return output.joined(separator: "\n")
	}

	private func loadEnv() throws -> CakerEnv {
		if let path = envFile {
			return try CakerEnv.load(fromFile: path)
		}
		return try CakerEnv.load()
	}
}

// Shared by Up and Compose — drives a launch RPC stream and returns rendered output.
// The defer on continuation.finish() ensures the AsyncStream consumer always unblocks
// even when the RPC throws before emitting all events.
func launchAndStream(
	buildOpts: BuildOptions,
	name: String,
	waitIPTimeout: Int,
	client: CakedServiceClient,
	callOptions: CallOptions?,
	format: Format
) async throws -> String {
	let context = ProgressObserver.ProgressHandlerContext()
	let (stream, continuation) = AsyncStream.makeStream(of: Caked_LaunchStreamReply.OneOf_Current?.self)
	var result = String.empty

	let rpcTask = Task<Void, Error> {
		defer { continuation.finish() }
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
	}

	for await current in stream {
		switch current {
		case .progress(let p):
			ProgressObserver.progressHandler(.progress(context, p.fractionCompleted))
		case .step(let step):
			ProgressObserver.progressHandler(.step(step))
		case .terminated(let status):
			if case .success(let v)? = status.result {
				ProgressObserver.progressHandler(.terminated(.success(name), v))
			} else if case .failure(let v)? = status.result {
				ProgressObserver.progressHandler(.terminated(.failure(GrpcError(code: 1, reason: v)), nil))
			}
		case .launched(let launched):
			result = format.render(LaunchReply(launched))
		default:
			break
		}
	}

	try await rpcTask.value
	return result
}
