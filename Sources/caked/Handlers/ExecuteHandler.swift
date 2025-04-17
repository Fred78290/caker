//
//  ExecuteHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/04/2025.
//

import Foundation
import NIO
import GRPC
import GRPCLib
import CakeAgentLib

struct ExecuteHandler: CakedCommandAsync {
	let requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>
	let responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>
	let vmname: String
	let client: CakeAgentConnection

	init(provider: CakedProvider, requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, context: GRPCAsyncServerCallContext) throws {

		guard let vmname = context.request.headers.first(name: "CAKEAGENT_VMNAME") else {
			Logger("ExecuteHandler").error(ServiceError("no CAKEAGENT_VMNAME header"))

			throw ServiceError("no CAKEAGENT_VMNAME header")
		}

		self.client = try provider.createCakeAgentConnection(vmName: vmname)
		self.requestStream = requestStream
		self.responseStream = responseStream
		self.vmname = vmname
	}

	static func execute(on: EventLoop, asSystem: Bool, requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, vmname: String, client: CakeAgentConnection) -> EventLoopFuture<Caked_Reply> {
		var vmname = vmname

		return on.makeFutureWithTask {
			if vmname == "" {
				vmname = "primary"

				if StorageLocation(asSystem: runAsSystem).exists(vmname) == false {
					Logger(self).info("Creating primary VM")
					try await BuildHandler.build(name: vmname, options: .init(name: vmname), asSystem: false)
				}
			}

			let vmLocation: VMLocation = try StorageLocation(asSystem: runAsSystem).find(vmname)

			if vmLocation.status != .running {
				Logger(self).info("Starting \(vmname)")

				_ = try StartHandler(location: vmLocation, waitIPTimeout: 180, startMode: .background).run(on: Root.group.next(), asSystem: runAsSystem)
			}

			try await client.execute(requestStream: requestStream, responseStream: responseStream)

			return Caked_Reply()
		}
	}

	mutating func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<Caked_Reply> {
		return Self.execute(on: on, asSystem: asSystem, requestStream: requestStream, responseStream: responseStream, vmname: vmname, client: client)
	}
}
