//
//  CurrentStatusHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO


struct CurrentStatusHandler: CakedCommandAsync {
	private let request: Caked_CurrentStatusRequest
	private let responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>

	init(provider: CakedProvider, request: Caked_CurrentStatusRequest, responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>) throws {
		self.request = request
		self.responseStream = responseStream
	}

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.unexpected = "\(error)"
		}
	}
	
	mutating func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
		do {
			try await CakedLib.CurrentStatusHandler.currentStatus(on: on, vmname: self.request.name, frequency: self.request.frequency, responseStream: self.responseStream, runMode: runMode)
		} catch {
			try? await self.responseStream.send(replyError(error: error))
		}
		
		return .init()
	}
}
