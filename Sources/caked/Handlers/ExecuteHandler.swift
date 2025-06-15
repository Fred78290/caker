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
import CakedLib


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

	mutating func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return CakedLib.ExecuteHandler.execute(on: on, runMode: runMode, requestStream: requestStream, responseStream: responseStream, vmname: vmname, client: client)
	}
}
