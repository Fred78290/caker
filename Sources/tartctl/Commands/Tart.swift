//
//  Tart.swift
//  TartHelper
//
//  Created by Frederic BOLTZ on 22/11/2024.
//
import ArgumentParser
import Foundation
import GRPCLib

struct Tart: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Catch all tart commands", shouldDisplay: false)

    @Argument(help: "command")
    var command: String?

    init() {

    }

    init(command: String?) {
        self.command = command
    }

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient, arguments: [String]) async throws -> Tartd_TartReply {
        return try await client.tartCommand(
            Tartd_TartCommandRequest(command: self.command ?? "", arguments: arguments)
        ).response.get()
    }
}
