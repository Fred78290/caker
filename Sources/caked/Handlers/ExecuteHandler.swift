//
//  ExecuteHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/04/2025.
//

import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO

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

	static func execute(on: EventLoop, runMode: Utils.RunMode, requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, vmname: String, client: CakeAgentConnection) -> EventLoopFuture<
		Caked_Reply
	> {
		var vmname = vmname

		return on.makeFutureWithTask {
			if vmname == "" {
				vmname = "primary"

				if StorageLocation(runMode: runMode).exists(vmname) == false {
					Logger(self).info("Creating primary VM")
					try await BuildHandler.build(name: vmname, options: .init(name: vmname), runMode: runMode)
				}
			}

			let vmLocation: VMLocation = try StorageLocation(runMode: runMode).find(vmname)

			if vmLocation.status != .running {
				Logger(self).info("Starting \(vmname)")

				_ = try StartHandler(location: vmLocation, waitIPTimeout: 180, startMode: .background).run(on: Root.group.next(), runMode: runMode)
			}

			try await client.execute(requestStream: requestStream, responseStream: responseStream)

			return Caked_Reply()
		}
	}

	mutating func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return Self.execute(on: on, runMode: runMode, requestStream: requestStream, responseStream: responseStream, vmname: vmname, client: client)
	}
}
