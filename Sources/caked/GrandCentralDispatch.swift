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
import CakeAgentLib

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
	let logger = Logger("GrandCentralDispatch")
	var taskQueue: TaskQueue = TaskQueue(label: "GrandCentralDispatch")
	var stream: AsyncThrowingStreamCakedStatus?
	var haveListeners: Bool {
		self.listeners.withLock { dict in
			dict.isEmpty == false
		}
	}
	
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
			let empty = dict.isEmpty
			let id = ListenerID()

			self.logger.debug("Adding listener: \(id)")

			dict[id] = continuation
			
			if empty {
				if let vms = try? StorageLocation(runMode: runMode).list() {
					vms.values.compactMap {
						if $0.status == .running {
							return $0
						}
						
						return nil
					}.forEach {
						self.startGrandCentralUpdate(location: $0)
					}
				}
			}
			
			return id
		}
	}
	
	@discardableResult
	func removeListener(_ id: ListenerID) -> AsyncThrowingStreamCakedReplyContinuation? {

		self.listeners.withLock { dict in
			self.logger.info("Removing listener: \(id)")

			guard let value = dict.removeValue(forKey: id) else {
				return nil
			}
	
			if dict.isEmpty {
				if let vms = try? StorageLocation(runMode: runMode).list() {
					vms.values.compactMap {
						if $0.status == .running {
							return $0
						}
						
						return nil
					}.forEach {
						self.stopGrandCentralUpdate(location: $0)
					}
				}
			}
			
			return value
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
	
	func stopGrandCentralUpdate(location: VMLocation) {
		self.logger.info("Stop Grand Central Update for \(location.name)")

		let future = self.group.next().submit {
			try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: self.runMode).stopGrandCentralUpdate()
		}
		
		future.whenComplete { result in
			switch result {
			case .success((let success, let reason)):
				if success == false {
					self.logger.error("Failed to stop Grand Central Update for \(location.name): \(reason)")
				}
			case .failure(let error):
				self.logger.error("Failed to stop Grand Central Update for \(location.name): \(error)")
			}
		}
	}
	
	func startGrandCentralUpdate(location: VMLocation) {
		self.logger.info("Start Grand Central Update for \(location.name)")

		let future = self.group.next().submit {
			try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: self.runMode).startGrandCentralUpdate(frequency: 1)
		}
		
		future.whenComplete { result in
			switch result {
			case .success((let success, let reason)):
				if success == false {
					self.logger.error("Failed to start Grand Central Update for \(location.name): \(reason)")
				}
			case .failure(let error):
				self.logger.error("Failed to start Grand Central Update for \(location.name): \(error)")
			}
		}
	}
	
	func startGrandCentralDispatch() async throws {
		guard self.stream == nil else {
			return
		}
		
		self.logger.info("Starting Grand Central Dispatch")

		let stream = AsyncThrowingStream.makeStream(of: Caked_CurrentStatus.self)
		
		self.stream = stream
		
		self.taskQueue.dispatchSync {
			defer {
				self.logger.info("Stopping Grand Central Dispatch")
				self.stream = nil
			}

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
		}
	}

	func processDispatch(responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>) async throws {
		self.logger.info("Processing Grand Central Dispatch")

		try await self.startGrandCentralDispatch()

		let (stream, continuation) = AsyncThrowingStream.makeStream(of: Caked_Reply.self)
		let id = self.addListener(continuation)
		
		defer {
			continuation.finish()
			self.self.removeListener(id)
		}

		let vms = try StorageLocation(runMode: runMode).list()

		let initialStatus = vms.map { (name: String, location: VMLocation) in
			return Caked_CurrentStatus.with {
				$0.name = name
				$0.status = .init(from: location.status)
			}
		}

		try await responseStream.send(Caked_Reply.with {
			$0.status = .with {
				$0.statuses = initialStatus
			}
		})
	
		for try await reply in stream {
			try await responseStream.send(reply)
		}
	}

	func processUpdate(requestStream: GRPCAsyncRequestStream<Caked_CurrentStatus>) async throws -> Caked_Empty {
		if self.haveListeners {
			for try await status in requestStream {
				try await self.updateStatus((status))
			}
		}

		return Caked_Empty()
	}
}
