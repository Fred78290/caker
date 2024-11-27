//
//  Tart.swift
//  TartHelper
//
//  Created by Frederic BOLTZ on 22/11/2024.
//
import ArgumentParser
import Foundation
import GRPCLib

struct Tart: GrpcParsableCommand {
	static var configuration = CommandConfiguration(
		abstract: "Catch all tart commands", shouldDisplay: false)

	@Argument(help: "command")
	var command: String?

	init() {

	}

	init(command: String?) {
		self.command = command
	}

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: self.command ?? "", arguments: arguments)).response.wait()
	}
}
