//
//  Restart.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//

import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Restart: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Restart VM(s)")
	
	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "VM names to restart")
	var names: [String] = []
	
	@Flag(help: "Force restart")
	public var force: Bool = false
	
	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var waitIPTimeout = 180

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.restart(Caked_RestartRequest(command: self), callOptions: callOptions).response.wait().vms.restarted

		if result.success {
			return self.format.render(result.objects)
		} else {
			return self.format.render(result.reason)
		}
	}
}
