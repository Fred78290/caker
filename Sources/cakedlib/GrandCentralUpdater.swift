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
	private let location: VMLocation
	private let runMode: Utils.RunMode
	private let client: CakedServiceClient
	private var taskQueue: TaskQueue?
	private var stream: AsyncThrowingStreamCurrentStatusReply?
	private let logger = Logger("GrandCentralUpdater")
	private var lastStatus = VMLocation.Status.stopped

	public init(location: VMLocation, runMode: Utils.RunMode) throws {
		self.location = location
		self.runMode = runMode
		self.client = try ServiceHandler.createCakedServiceClient(runMode: runMode)
	}
	
	public func start(frequency: Int32, onclose: @escaping () -> Void) async throws {
		guard self.taskQueue == nil else {
			onclose()
			return
		}

		self.logger.info("Starting Grand Central Updater for VM: \(self.location.name)")

		let logger = self.logger
		let vmName = self.location.name
		let grpcStream = client.grandCentralUpdate(callOptions: .init(timeLimit: .none))
		let asyncStream = AsyncThrowingStream.makeStream(of: CurrentStatusHandler.CurrentStatusReply.self)
		let cancelable = try await CurrentStatusHandler.currentStatus(location: self.location, frequency: frequency, statusStream: asyncStream.continuation, runMode: self.runMode)

		grpcStream.status.whenComplete { result in
			switch result {
			case .failure( let error):
				asyncStream.continuation.finish(throwing: error)
				logger.info("Grand Central Updater failed for VM: \(vmName), with error: \(error)")

			case .success(let status):
				if status.isOk == false {
					asyncStream.continuation.finish(throwing: status)
					logger.info("Grand Central Updater completed for VM: \(vmName), with status: \(status)")
				} else {
					logger.info("Grand Central Updater completed for VM: \(vmName)")
				}
			}
		}

		self.stream = asyncStream
		self.taskQueue = TaskQueue.dispatch {
			defer {
				onclose()
				cancelable.cancel()

				self.taskQueue = nil
				self.stream = nil
				self.logger.info("Grand Central Updater stopped for VM: \(vmName)")
			}

			do {
				for try await status in asyncStream.stream {
					var firstMessage = true

					if firstMessage {
						if case .usage = status {
							firstMessage = false
							try await grpcStream.sendMessage(.with {
								$0.name = self.location.name
								$0.status = .agentReady
							}).get()
						}
					}

					try await grpcStream.sendMessage(.with {
						$0.name = self.location.name

						switch status {
						case .usage(let usage):
							$0.usage = usage
						case .error(let error):
							$0.failure = "\(error)"
						case .status(let status):
							$0.status = .init(status)
						case .screenshot(let png):
							$0.screenshot = png
						}
					}).get()
				}

				try? await grpcStream.sendEnd().get()
			} catch is CancellationError {
				// Silent
				try? await grpcStream.sendEnd().get()
			} catch is GRPCStatusTransformable {
				// Silent
			} catch {
				self.logger.error("Unexpected error: \(error)")
			}
		}
	}

	public func stop() {
		guard let stream, let taskQueue else {
			return
		}
		
		self.logger.info("Stopping Grand Central Updater for VM: \(self.location.name)")

		stream.continuation.finish(throwing: CancellationError())
		taskQueue.close()
		
		self.taskQueue = nil
		self.stream = nil
	}

	public func setStatus(_ status: VMLocation.Status) {
		if status != self.lastStatus {
			self.lastStatus = status

			if let stream {
				self.logger.debug("VM \(self.location.name) send status: \(status)")

				stream.continuation.yield(.status(status))
			} else {
				self.logger.debug("VM \(self.location.name) can't send status: \(status), stream closed")
			}
		}
	}
}

