//
//  ExecuteHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/04/2025.
//

import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct ExecuteHandler: CakedCommandAsync {
	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with { _ in
		}
	}

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

	mutating func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
		do {
			try await CakedLib.ExecuteHandler.execute(on: on, runMode: runMode, requestStream: requestStream, responseStream: responseStream, vmname: vmname, client: client)
		} catch {
			return replyError(error: error)
		}
		
		return .init()
	}
}
