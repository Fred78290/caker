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
	static let configuration = CommandConfiguration(abstract: String(localized: "Restart VM(s)"))
	
	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Argument(help: ArgumentHelp(String(localized: "VM names to restart")))
	var names: [String] = []
	
	@Flag(help: ArgumentHelp(String(localized: "Force restart")))
	public var force: Bool = false
	
	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout = 180

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.restart(Caked_RestartRequest(command: self), callOptions: callOptions).response.wait().vms.restarted

		if result.success {
			return self.options.format.render(result.objects)
		} else {
			return self.options.format.render(result.reason)
		}
	}
}
