import CakeAgentLib
import CakedLib
//
//  GrandCentralDispatch.swift
//  Caker
//
//  Created by Frederic BOLTZ on 21/02/2026.
//
import Foundation
import GRPC
import GRPCLib
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

final class GrandCentralDispatch {
	typealias ListenerID = UUID

	let runMode: Utils.RunMode
	let group: EventLoopGroup
	let listeners: Mutex<[ListenerID: AsyncThrowingStreamCakedReplyContinuation]>
	let logger = Logger("GrandCentralDispatch")
	let shutdown = Mutex<Bool>(false)
	var taskQueue: TaskQueue = TaskQueue(label: "GrandCentralDispatch")
	var stream: AsyncThrowingStreamCakedStatus?
	var filesWatcher: DirWatcher? = nil
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

		var startUpdates = false
		let id = self.listeners.withLock { dict in
			let empty = dict.isEmpty
			let id = ListenerID()

			self.logger.info("Adding listener: \(id)")

			dict[id] = continuation

			if empty {
				startUpdates = true
			}

			return id
		}

		if startUpdates {
			do {
				let runningVirtualMachines = try StorageLocation(runMode: runMode).list().values.compactMap {
					if case .running = $0.status {
						return $0
					}

					return nil
				}

				runningVirtualMachines.forEach {
					self.startGrandCentralUpdate(location: $0)
				}
			} catch {
				self.logger.error("Unable to list virtual machines before adding listener: \(error)")
			}

		}

		return id
	}

	@discardableResult
	func removeListener(_ id: ListenerID) -> AsyncThrowingStreamCakedReplyContinuation? {
		var shouldStop = false

		let value = self.listeners.withLock { (dict) -> AsyncThrowingStreamCakedReplyContinuation? in
			self.logger.info("Removing listener: \(id)")

			guard let value = dict.removeValue(forKey: id) else {
				return nil
			}

			if self.shutdown.withLock({ !$0 }) && dict.isEmpty {
				self.logger.info("No more listeners, stop all Grand Central Updates")
				shouldStop = true
			}

			return value
		}

		let stopFuture = shouldStop ? self.stopGrandCentralUpdate() : nil

		if let stopFuture {
			stopFuture.whenComplete { result in
				if case .failure(let error) = result {
					self.logger.error("Failed to stop Grand Central update after removing listener: \(error)")
				}
			}
		}

		return value
	}

	func updateStatus(_ status: Caked_CurrentStatus) async throws {
		guard let stream else {
			return
		}

		stream.continuation.yield(status)
	}

	func stopGrandCentralDispatch() {
		self.stopFilesMonitor()

		guard let stream else {
			return
		}

		func shutdownStream() {
			stream.continuation.finish()
			
			self.stream = nil
		}

		self.shutdown.withLock { $0 = true }

		self.listeners.withLock { listeners in
			listeners.values.forEach {
				$0.finish()
			}
		}

		if let future = self.stopGrandCentralUpdate() {
			future.whenComplete { _ in
				shutdownStream()
			}
		} else {
			shutdownStream()
		}
	}

	func stopGrandCentralUpdate(location: VMLocation) -> EventLoopFuture<(success: Bool, reason: String)> {
		self.logger.info("Stop Grand Central Update for \(location.name)")

		let future = self.group.next().submit {
			try VMRunHandler.serviceMode.client(location: location, runMode: self.runMode).stopGrandCentralUpdate()
		}

		future.whenComplete { result in
			switch result {
			case .success((let success, let reason)):
				if success {
					self.logger.debug("Grand Central Update stopped for \(location.name)")
				} else {
					self.logger.error("Failed to stop Grand Central Update for \(location.name): \(reason)")
				}
			case .failure(let error):
				self.logger.error("Failed to stop Grand Central Update for \(location.name): \(error)")
			}
		}

		return future
	}

	func stopGrandCentralUpdate() -> EventLoopFuture<Void>? {
		guard let vms = try? StorageLocation(runMode: runMode).list() else {
			return nil
		}

		let futures = vms.values.compactMap {
			if case .running = $0.status {
				return self.stopGrandCentralUpdate(location: $0)
			}

			return nil
		}
		
		guard futures.isEmpty == false else {
			return nil
		}

		return EventLoopFuture.andAllComplete(futures, on: self.group.next())
	}

	func startGrandCentralUpdate(location: VMLocation) {
		self.logger.info("Start Grand Central Update for \(location.name)")

		let future = self.group.next().submit {
			try VMRunHandler.serviceMode.client(location: location, runMode: self.runMode).startGrandCentralUpdate(frequency: 1)
		}

		future.whenComplete { result in
			switch result {
			case .success((let success, let reason)):
				if success {
					self.logger.debug("Grand Central Update started for \(location.name)")
				} else {
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

		self.startFilesMonitor()

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
		guard self.shutdown.withLock({ !$0 }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		self.logger.info("Processing Grand Central Dispatch")

		try await self.startGrandCentralDispatch()

		let (stream, continuation) = AsyncThrowingStream.makeStream(of: Caked_Reply.self)
		let id = self.addListener(continuation)

		defer {
			continuation.finish()
			self.removeListener(id)
		}

		let vms = try StorageLocation(runMode: runMode).list()

		let initialStatus = vms.map { (name: String, location: VMLocation) in
			return Caked_CurrentStatus.with {
				$0.name = name
				$0.status = .init(location.status)
			}
		}

		try await responseStream.send(
			Caked_Reply.with {
				$0.status = .with {
					$0.statuses = initialStatus
				}
			})

		for try await reply in stream {
			try await responseStream.send(reply)
		}
	}

	func processUpdate(requestStream: GRPCAsyncRequestStream<Caked_CurrentStatus>) async throws -> Caked_Empty {
		guard self.shutdown.withLock({ !$0 }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		if self.haveListeners {
			for try await status in requestStream {
				try await self.updateStatus((status))
			}
		}

		return Caked_Empty()
	}
}

extension GrandCentralDispatch {
	func stopFilesMonitor() {
		guard let filesWatcher else {
			return
		}

		self.filesWatcher = nil
		filesWatcher.stop()
	}

	func updateStatusNetworks() async {
		try? await self.updateStatus(.with {
			$0.name = Home.networksFilename
			$0.networkInfos = .with {
				$0.networks = CakedLib.NetworksHandler.networks(runMode: self.runMode).caked.networks
			}
		})
	}

	func updateStatusRemotes() async {
		let list = CakedLib.RemoteHandler.listRemote(runMode: self.runMode)
		
		if list.success {
			try? await self.updateStatus(.with {
				$0.name = "remote"
				$0.remotesInfos = .with {
					$0.remotes = list.remotes.map(\.caked)
				}
			})
		}
	}

	func updateStatusTemplates() async {
		let list = CakedLib.TemplateHandler.listTemplate(runMode: self.runMode)
		
		if list.success {
			try? await self.updateStatus(.with {
				$0.name = "templates"
				$0.templateInfos = .with {
					$0.templates = list.templates.map(\.caked)
				}
			})
		}
	}

	func updateStatusNetwork(_ fileURL: URL) async {
		let networkName = fileURL.deletingLastPathComponent().lastPathComponent
		
		try? await self.updateStatus(.with {
			$0.name = networkName
			$0.network = .with {
				$0.name = networkName
				$0.running = fileURL.isPIDRunning().running
			}
		})
	}

	func startFilesMonitor() {
		guard self.filesWatcher == nil else {
			return
		}

		guard let home = try? Home(runMode: self.runMode) else {
			return
		}

		let templateStorage = StorageLocation(runMode: self.runMode, template: true)
		let templatesRoot = templateStorage.rootURL.lastPathComponent
		let logger = self.logger
		let watcher = DirWatcher([
			home.remoteDb.path(percentEncoded: false),
			home.networkDirectory.path(percentEncoded: false),
			templateStorage.rootURL.path(percentEncoded: false)])

		self.filesWatcher = watcher

		watcher.queue = DispatchQueue.global(qos: .utility)
		watcher.callback = { [weak self] event in
			guard let self else { return }

			#if DEBUG
			logger.debug("VM directory change: \(event.path) flags: 0x\(String(format: "%X", event.flags)), fileChange: \(event.fileChange), dirChange: \(event.dirChange)")
			#endif

			let fileURL = URL(filePath: event.path).resolvingSymlinksInPath()

			if event.dirChange {
				// Watch templates directory
				if fileURL.pathExtension == Home.vmExtension && fileURL.deletingLastPathComponent().lastPathComponent == templatesRoot {
					Task {
						await self.updateStatusTemplates()
					}
				}
			} else if event.fileChange {
				// Watch remote.json
				if fileURL.lastPathComponent == Home.remoteFilename {
					Task {
						await self.updateStatusRemotes()
					}
				}
				// Watch networks/networks.json
				else if fileURL.lastPathComponent == Home.networksFilename {
					Task {
						await self.updateStatusNetworks()
					}
				// Watch networks/<network dir>/vmnet.pid
				} else if fileURL.lastPathComponent == "vmnet.pid" {
					Task {
						await self.updateStatusNetwork(fileURL)
					}
				}
			}
		}

		watcher.start()
	}

}
