//
//  Down.swift
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

struct Down: GrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "down",
		abstract: String(localized: "Stop VMs defined in .cakerenv"),
		discussion: String(localized: "Reads .cakerenv from the current directory (or --env-file) and stops VMs in reverse depends-on order.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(
		name: [.customLong("env-file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to the environment file"), valueName: "path"))
	var envFile: String?

	@Flag(
		name: [.customLong("force")],
		help: ArgumentHelp(String(localized: "Force stop without waiting for graceful shutdown")))
	var force: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "VM names to stop (default: all VMs in .cakerenv)")))
	var names: [String] = []

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let env = try loadEnv()
		let vmsToStop = try env.downOrder(filter: names)
		var output: [String] = []

		for (vmName, _) in vmsToStop {
			let result = try client.stop(
				.with {
					$0.force = force
					$0.names = .with { $0.list = [vmName] }
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

	private func loadEnv() throws -> CakerEnv {
		if let path = envFile {
			return try CakerEnv.load(fromFile: path)
		}
		return try CakerEnv.load()
	}
}
