//
//  SeamlessTunnel.swift
//  Caker
//
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO
import NIOPosix
import Synchronization

/// Relays the seamless windows channel of a Linux guest to a client that may be on another host.
///
/// The guest compositor dials vsock port 5100, which the VM's socket device bridges to a unix socket in the VM's
/// directory. Whoever shows the windows listens there: Caker.app or a `caked vmrun --ui` on the VM's host, or, for
/// a client that is not on that host (`cakectl seamless`), this tunnel, which listens for as long as the client's
/// stream lasts and carries the guest's byte stream over gRPC, like `VNCTunnel` does for VNC. The compositor
/// retries every second, so it connects as soon as the listener exists, and again after a restart.
final class SeamlessTunnel: @unchecked Sendable {
	/// What the daemon keeps queued for the guest before it gives up on the session: a guest that stops reading must
	/// not make it buffer what the client keeps sending without bound. Dropping bytes from a framed stream would
	/// corrupt it, so the session ends instead and the client connects again.
	private static let maxQueuedBytes = 16 * 1024 * 1024

	/// The byte stream going to the guest: the guest connection gets what the client sends.
	private final class Relay: @unchecked Sendable {
		private let current = Mutex<AsyncStream<ByteBuffer>.Continuation?>(nil)
		private let queued = Mutex<Int>(0)

		/// Set when more than `maxQueuedBytes` are waiting for the guest.
		let overflow: @Sendable () -> Void

		init(overflow: @escaping @Sendable () -> Void) {
			self.overflow = overflow
		}

		func newConnection() -> AsyncStream<ByteBuffer> {
			let (stream, continuation) = AsyncStream.makeStream(of: ByteBuffer.self)

			self.current.withLock {
				$0?.finish()
				$0 = continuation
			}

			self.queued.withLock { $0 = 0 }

			return stream
		}

		func forward(_ buffer: ByteBuffer) {
			let total = self.queued.withLock { (value: inout Int) -> Int in
				value += buffer.readableBytes
				return value
			}

			if total > SeamlessTunnel.maxQueuedBytes {
				self.overflow()
				return
			}

			_ = self.current.withLock { $0?.yield(buffer) }
		}

		/// The guest took `count` bytes.
		func delivered(_ count: Int) {
			self.queued.withLock { $0 = max(0, $0 - count) }
		}

		func finish() {
			self.current.withLock {
				$0?.finish()
				$0 = nil
			}
		}
	}

	/// A value shared between the tasks of one tunnel (a `Mutex` can't be passed around, it can't be copied).
	private final class Shared<Value: Sendable>: @unchecked Sendable {
		private let storage: Mutex<Value>

		init(_ value: Value) {
			self.storage = Mutex(value)
		}

		func withLock<R>(_ body: (inout Value) -> R) -> R {
			self.storage.withLock(body)
		}
	}

	/// A setup failure that retrying can't change, to be returned to the client as it is.
	private struct PermanentListenError: Error {
		let status: GRPCStatus
	}

	private struct State {
		var shutdown = false
		var tunnels: [UUID: Task<Void, Never>] = [:]
	}

	private let group: EventLoopGroup
	private let runMode: Utils.RunMode
	private let logger = Logger("SeamlessTunnel")
	/// Admission and the shutdown snapshot share one lock: a tunnel admitted before `stopSeamlessTunnel()` is in
	/// the set it cancels, one that comes after is refused.
	private let state = Mutex<State>(State())

	/// The process-wide umask is changed while sockets are being created (see `OwnerOnlyUmask`): concurrent tunnels
	/// share one change, so the mask is restored once, by the last one.
	private static let umaskScope = Mutex<(users: Int, saved: mode_t)>((0, 0))

	init(group: EventLoopGroup, runMode: Utils.RunMode) {
		self.group = group
		self.runMode = runMode
	}

	func stopSeamlessTunnel() {
		let tasks = self.state.withLock { (state: inout State) -> [Task<Void, Never>] in
			state.shutdown = true
			return Array(state.tunnels.values)
		}

		tasks.forEach { $0.cancel() }
	}

	func tunnel(requestStream: GRPCAsyncRequestStream<Caked_SeamlessStream>, responseStream: GRPCAsyncResponseStreamWriter<Caked_SeamlessStream>, context: GRPCAsyncServerCallContext) async throws {
		guard self.state.withLock({ !$0.shutdown }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		guard let vmName = context.request.headers.first(name: CakedServiceClient.META_CAKEAGENT_VMNAME) else {
			self.logger.error("no \(CakedServiceClient.META_CAKEAGENT_VMNAME) header")

			throw ServiceError(String(localized: "no \(CakedServiceClient.META_CAKEAGENT_VMNAME) header"))
		}

		// What a client can act on is a status with its message, not an "internal error".
		let config: CakeConfig

		do {
			config = try StorageLocation(runMode: self.runMode).find(vmName).config()
		} catch {
			throw GRPCStatus(code: .notFound, message: error.reason)
		}

		guard config.supportsSeamlessWindows, let path = config.seamlessSocketPath else {
			throw GRPCStatus(code: .failedPrecondition, message: String(format: String(localized: "VM %@ does not have seamless windows enabled"), vmName))
		}

		// Caker.app or a process with a UI already shows them: two listeners would fight over the socket. Only a lock
		// held by another process says that: a lock file that can't be opened is a setup problem to report as such.
		let lock: Int32

		switch SeamlessServer.tryAcquireListenerLock(for: path) {
		case .acquired(let descriptor):
			lock = descriptor
		case .contended:
			throw GRPCStatus(code: .alreadyExists, message: String(format: String(localized: "The windows of VM %@ are already shown by another process"), vmName))
		case .failed(let reason):
			throw GRPCStatus(code: .failedPrecondition, message: String(format: String(localized: "Cannot take the listener lock of VM %@: %@"), vmName, reason))
		}

		// Only a socket this tunnel created is removed: a file that was already there is not ours.
		let socketCreated = Shared<Bool>(false)

		defer {
			if socketCreated.withLock({ $0 }) {
				unlink(path)
			}

			SeamlessServer.releaseListenerLock(lock)
		}

		let id = UUID()
		let ended = Shared<GRPCStatus?>(nil)
		let handle = Mutex<Task<Void, Never>?>(nil)
		let endTunnel: @Sendable () -> Void = { handle.withLock { $0 }?.cancel() }

		let admitted: Task<Void, Never>? = self.state.withLock { (state: inout State) -> Task<Void, Never>? in
			guard !state.shutdown else { return nil }

			let task = Task { await self.run(vmName: vmName, path: path, requestStream: requestStream, responseStream: responseStream, socketCreated: socketCreated, ended: ended, endTunnel: endTunnel) }

			state.tunnels[id] = task
			handle.withLock { $0 = task }

			return task
		}

		guard let task = admitted else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		defer {
			self.state.withLock { _ = $0.tunnels.removeValue(forKey: id) }
		}

		await withTaskCancellationHandler {
			await task.value
		} onCancel: {
			task.cancel()
		}

		// The reason the tunnel ended on the service's side, if it did: the client reads it from the status.
		if let status = ended.withLock({ $0 }) {
			throw status
		}
	}

	private func run(vmName: String, path: String, requestStream: GRPCAsyncRequestStream<Caked_SeamlessStream>, responseStream: GRPCAsyncResponseStreamWriter<Caked_SeamlessStream>, socketCreated: Shared<Bool>, ended: Shared<GRPCStatus?>, endTunnel: @escaping @Sendable () -> Void) async {
		self.logger.debug("Start seamless tunnel for VM \(vmName) on \(path)")

		let end: @Sendable (GRPCStatus) -> Void = { status in
			ended.withLock { if $0 == nil { $0 = status } }
			endTunnel()
		}

		let relay = Relay(overflow: {
			end(GRPCStatus(code: .resourceExhausted, message: String(localized: "The guest does not read the seamless stream")))
		})
		let listener = Mutex<Channel?>(nil)
		let clientGone = Mutex<Bool>(false)

		await withTaskGroup(of: Void.self) { group in
			// The client to the guest. The client going away ends the tunnel: stop accepting, drop the connection.
			group.addTask {
				do {
					for try await message in requestStream {
						try Task.checkCancellation()

						relay.forward(ByteBuffer(data: message.stream))
					}
				} catch is CancellationError {
				} catch {
					self.logger.debug("Seamless request stream of VM \(vmName) ended: \(error)")
				}

				clientGone.withLock { $0 = true }
				relay.finish()
				listener.withLock { $0 }?.close(promise: nil)
			}

			// The guest to the client. A listener that fails (an accepted connection the guest already dropped
			// makes NIO give up) is bound again while the client is still there, except for a failure retrying
			// can't change, which the client gets as a status.
			group.addTask {
				while clientGone.withLock({ $0 }) == false && Task.isCancelled == false {
					do {
						try await self.listen(vmName: vmName, path: path, relay: relay, responseStream: responseStream, socketCreated: socketCreated, guestEnded: {
							// The client's protocol state belongs to one guest connection (its decoder saw that guest's
							// hello): another connection needs a new one, which the client gets by connecting again.
							end(GRPCStatus(code: .unavailable, message: String(localized: "The guest compositor of this VM disconnected")))
						}) { channel in
							listener.withLock { $0 = channel }

							// The client may have left while this was binding.
							if clientGone.withLock({ $0 }) {
								channel.close(promise: nil)
							}
						}
					} catch let error as PermanentListenError {
						end(error.status)
						break
					} catch {
						self.logger.debug("Seamless listener of VM \(vmName) ended: \(error)")

						if let status = Self.permanentStatus(error, path: path, vmName: vmName) {
							end(status)
							break
						}
					}

					if clientGone.withLock({ $0 }) == false && Task.isCancelled == false {
						try? await Task.sleep(for: .milliseconds(200))
					}
				}

				relay.finish()
			}

			await group.waitForAll()
		}

		self.logger.debug("Seamless tunnel closed for VM \(vmName)")
	}

	/// A bind failure that retrying can't change (the socket path is blocked by something that is not a socket, or can't be written).
	private static func permanentStatus(_ error: Error, path: String, vmName: String) -> GRPCStatus? {
		if error is UnixDomainSocketPathWrongType {
			return GRPCStatus(code: .failedPrecondition, message: String(format: String(localized: "The seamless socket path %@ of VM %@ is not a socket"), path, vmName))
		}

		if let io = error as? IOError {
			switch io.errnoCode {
			case ENOENT, ENOTDIR, EACCES, EPERM, EROFS, ENAMETOOLONG, ELOOP:
				return GRPCStatus(code: .failedPrecondition, message: String(format: String(localized: "Cannot listen on %@ for VM %@: %@"), path, vmName, String(cString: strerror(io.errnoCode))))
			default:
				break
			}
		}

		return nil
	}

	private static func enterOwnerOnlyUmask() {
		self.umaskScope.withLock {
			if $0.users == 0 {
				$0.saved = umask(0o177)
			}

			$0.users += 1
		}
	}

	private static func leaveOwnerOnlyUmask() {
		self.umaskScope.withLock {
			$0.users -= 1

			if $0.users == 0 {
				umask($0.saved)
			}
		}
	}

	/// Listens on the seamless socket until the listener closes. One guest connection per tunnel: when it ends, or
	/// another one comes, `guestEnded` is called and the tunnel is over.
	private func listen(vmName: String, path: String, relay: Relay, responseStream: GRPCAsyncResponseStreamWriter<Caked_SeamlessStream>, socketCreated: Shared<Bool>, guestEnded: @escaping @Sendable () -> Void, bound: (Channel) -> Void) async throws {
		// The guest controls what is shown on the desktop, so only this user may connect: the socket is created
		// owner-only whatever the caller's umask (other threads creating files meanwhile only get stricter modes),
		// and the mode is checked again before anything is accepted.
		Self.enterOwnerOnlyUmask()

		let server: NIOAsyncChannel<NIOAsyncChannel<ByteBuffer, ByteBuffer>, Never>

		do {
			server = try await ServerBootstrap(group: self.group)
				.bind(unixDomainSocketPath: path, cleanupExistingSocketFile: true) { channel in
					channel.eventLoop.makeCompletedFuture {
						try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
					}
				}
		} catch {
			Self.leaveOwnerOnlyUmask()
			throw error
		}

		Self.leaveOwnerOnlyUmask()
		socketCreated.withLock { $0 = true }

		guard chmod(path, 0o600) == 0 else {
			let reason = String(cString: strerror(errno))

			server.channel.close(promise: nil)

			throw PermanentListenError(status: GRPCStatus(code: .failedPrecondition, message: String(format: String(localized: "Cannot restrict %@ for VM %@: %@"), path, vmName, reason)))
		}

		bound(server.channel)

		try await server.executeThenClose { inbound in
			await withTaskGroup(of: Void.self) { group in
				var accepted = false

				do {
					for try await connection in inbound {
						// A second guest connection (the compositor restarted): the client's protocol state is the
						// first one's, so the tunnel ends here and the client connects again.
						guard accepted == false else {
							guestEnded()
							break
						}

						accepted = true

						let outgoing = relay.newConnection()

						self.logger.debug("Guest compositor connected for VM \(vmName)")

						group.addTask {
							await self.pump(connection, outgoing: outgoing, relay: relay, responseStream: responseStream, vmName: vmName)
							guestEnded()
						}
					}
				} catch {
					self.logger.debug("Seamless accept loop of VM \(vmName) ended: \(error)")
				}

				group.cancelAll()
			}
		}
	}

	private func pump(_ connection: NIOAsyncChannel<ByteBuffer, ByteBuffer>, outgoing: AsyncStream<ByteBuffer>, relay: Relay, responseStream: GRPCAsyncResponseStreamWriter<Caked_SeamlessStream>, vmName: String) async {
		do {
			try await connection.executeThenClose { inbound, outbound in
				try await withThrowingTaskGroup(of: Void.self) { group in
					group.addTask {
						for try await buffer in inbound {
							try Task.checkCancellation()

							try await responseStream.send(Caked_SeamlessStream.with { $0.stream = Data(buffer: buffer) })
						}
					}

					group.addTask {
						for await buffer in outgoing {
							try await outbound.write(buffer)
							relay.delivered(buffer.readableBytes)
						}
					}

					// Either side ending ends the connection.
					_ = try await group.next()
					group.cancelAll()
				}
			}

			self.logger.debug("Guest compositor of VM \(vmName) disconnected")
		} catch is CancellationError {
		} catch {
			self.logger.debug("Seamless connection of VM \(vmName) ended: \(error)")
		}
	}
}
