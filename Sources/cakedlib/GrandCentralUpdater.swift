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
import CakeAgentLib

typealias AsyncThrowingStreamCurrentStatusReply = (
	stream: AsyncThrowingStream<CurrentStatusHandler.CurrentStatusReply, Error>,
	continuation: AsyncThrowingStream<CurrentStatusHandler.CurrentStatusReply, Error>.Continuation
)

public class GrandCentralUpdater {
	let location: VMLocation
	let runMode: Utils.RunMode
	let client: CakedServiceClient
	var taskQueue: TaskQueue?
	var stream: AsyncThrowingStreamCurrentStatusReply?

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
			do {
				for try await status in asyncStream.stream {
					try await grpcStream.sendMessage(.with {
						$0.name = self.location.name
						switch status {
						case .usage(let usage):
							$0.usage = usage
						case .error(let error):
							$0.failure = "\(error)"
						case .status(let status):
							$0.status = .init(from: status)
						case .screenshot(let png):
							$0.screenshot = png
						}
					}).get()
				}
			} catch is CancellationError {
				// Silent
			} catch {
				Logger("GrandCentralUpdater").error("Unexpected error: \(error)")
			}

			cancelable.cancel()

			try await grpcStream.sendEnd().get()
		}
	}

	public func stop() {
		guard let stream, let taskQueue else {
			return
		}
		
		stream.continuation.finish(throwing: CancellationError())
		taskQueue.close()
		
		self.taskQueue = nil
		self.stream = nil
	}
}

