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

    @Argument(help: "arguments")
    var arguments: [String]

    init() {

    }

    init(command: String?, arguments: [String]) {
        self.command = command
        self.arguments = arguments
    }

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
        return try await client.tart(
            Tartd_TartRequest(command: self.command ?? "", arguments: self.arguments)
        ).response.get()
    }
}
