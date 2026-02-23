//
//  GrandCentralDispatch.swift
//  Caker
//
//  Created by Frederic BOLTZ on 21/02/2026.
//
import Foundation
import GRPC
import GRPCLib
import CakedLib
import NIO
import Synchronization

typealias AsyncThrowingStreamCakedReply = (
	stream: AsyncThrowingStream<Caked_Reply, Error>,
	continuation: AsyncThrowingStream<Caked_Reply, Error>.Continuation
)

typealias AsyncThrowingStreamCakedStatus = (
	stream: AsyncThrowingStream<Caked_CurrentStatus, Error>,
	continuation: AsyncThrowingStream<Caked_CurrentStatus, Error>.Continuation
)

typealias AsyncThrowingStreamCakedReplyContinuation = AsyncThrowingStream<Caked_Reply, Error>.Continuation
typealias AsyncThrowingStreamCakedReplyContinuations = [AsyncThrowingStreamCakedReplyContinuation]
typealias AsyncThrowingStreamCakedStatusReplyContinuation = AsyncThrowingStream<Caked_CurrentStatusReply, Error>.Continuation

typealias ListenerID = UUID

final class GrandCentralDispatch {
	let runMode: Utils.RunMode
	let group: EventLoopGroup
	let listeners: Mutex<[ListenerID: AsyncThrowingStreamCakedReplyContinuation]>
	var taskQueue: TaskQueue = TaskQueue(label: "GrandCentralDispatch")
	var stream: AsyncThrowingStreamCakedStatus?

	deinit {
		stopGrandCentralDispatch()
	}

	init(group: EventLoopGroup, runMode: Utils.RunMode) {
		self.group = group
		self.runMode = runMode
		self.listeners = .init([:])
	}
	
	func addListener(_ continuation: AsyncThrowingStreamCakedReplyContinuation) -> ListenerID {
		self.listeners.withLock { dict in
			let id = ListenerID()
			
			dict[id] = continuation
			
			return id
		}
	}
	
	@discardableResult
	func removeListener(_ id: ListenerID) -> AsyncThrowingStreamCakedReplyContinuation? {
		self.listeners.withLock { dict in
			dict.removeValue(forKey: id)
		}
	}
	
	func updateStatus(_ status: Caked_CurrentStatus) async throws {
		guard let stream else {
			return
		}

		stream.continuation.yield(status)
	}

	func stopGrandCentralDispatch() {
		guard let stream else {
			return
		}
		
		stream.continuation.finish()
	}

	func startGrandCentralDispatch() async throws {
		guard self.stream == nil else {
			return
		}

		let stream = AsyncThrowingStream.makeStream(of: Caked_CurrentStatus.self)

		self.stream = stream

		self.taskQueue.dispatchSync {
			do {
				for try await status in stream.stream {
					let reply = Caked_Reply.with {
						$0.status = .with {
							$0.statuses = [
								status
							]
						}
					}

					self.listeners.withLock {
						$0.values.forEach { continuation in
							continuation.yield(reply)
						}
					}
				}

				self.listeners.withLock {
					$0.values.forEach { continuation in
						continuation.finish()
					}
					
					$0.removeAll()
				}
			} catch {
				self.listeners.withLock {
					$0.values.forEach { continuation in
						continuation.finish(throwing: error)
					}

					$0.removeAll()
				}
			}

			self.stream = nil
		}
	}
}
