//
//  GrandCentralUpdater.swift
//  Caker
//
//  Created by Frederic BOLTZ on 21/02/2026.
//

import Foundation
import GRPC
import GRPCLib
import NIO
import Combine

public class GrandCentralUpdater {
	let location: VMLocation
	let runMode: Utils.RunMode
	let client: CakedServiceClient
	var taskQueue: TaskQueue?
	var stream: AsyncThrowingStreamCakedCurrentStatusReply?

	public init(location: VMLocation, runMode: Utils.RunMode) throws {
		self.location = location
		self.runMode = runMode
		self.client = try ServiceHandler.serviceClient(runMode: runMode)!
	}
	
	public func start(frequency: Int32) async throws {
		guard self.taskQueue == nil else {
			return
		}

		let grpcStream = client.grandCentralUpdate(callOptions: .init(timeLimit: .none))
		let asyncStream = AsyncThrowingStream.makeStream(of: CurrentStatusHandler.CurrentStatusReply.self)
		let cancelable = try await CurrentStatusHandler.currentStatus(location: self.location, frequency: frequency, statusStream: asyncStream.continuation, runMode: self.runMode)
		
		self.stream = asyncStream
		self.taskQueue = TaskQueue.dispatch {
			for try await status in asyncStream.stream {
				try await grpcStream.sendMessage(status)
			}
			
			try await grpcStream.sendEnd().get()
		}
	}

	public func stop() {
		
	}
}
