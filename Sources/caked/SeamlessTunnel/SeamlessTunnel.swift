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
import Synchronization

/// Relays the seamless windows channel of a Linux guest to a client that may be on another host.
///
/// The guest compositor dials vsock port 5100, which the VM's socket device bridges to a unix socket in the VM's
/// directory. Whoever shows the windows listens there: Caker.app or a `caked vmrun --ui` on the VM's host, or, for
/// a client that is not on that host (`cakectl seamless`), this tunnel, which listens for as long as the client's
/// stream lasts and carries the guest's byte stream over gRPC, like `VNCTunnel` does for VNC. The compositor
/// retries every second, so it connects as soon as the listener exists, and again after a restart.
final class SeamlessTunnel: @unchecked Sendable {
	/// The byte stream going to the guest: whichever connection is the current one gets what the client sends.
	private final class Relay: @unchecked Sendable {
		private let current = Mutex<AsyncStream<ByteBuffer>.Continuation?>(nil)

		/// A new guest connection replaces the previous one (the compositor restarted).
		func newConnection() -> AsyncStream<ByteBuffer> {
			let (stream, continuation) = AsyncStream.makeStream(of: ByteBuffer.self)

			self.current.withLock {
				$0?.finish()
				$0 = continuation
			}

			return stream
		}

		func forward(_ buffer: ByteBuffer) {
			_ = self.current.withLock { $0?.yield(buffer) }
		}

		func finish() {
			self.current.withLock {
				$0?.finish()
				$0 = nil
			}
		}
	}

	private let group: EventLoopGroup
	private let runMode: Utils.RunMode
	private let logger = Logger("SeamlessTunnel")
	private let shutdown = Mutex<Bool>(false)
	private let tunnels = Mutex<[UUID: Task<Void, Never>]>([:])

	init(group: EventLoopGroup, runMode: Utils.RunMode) {
		self.group = group
		self.runMode = runMode
	}

	func stopSeamlessTunnel() {
		self.shutdown.withLock { $0 = true }

		let tasks = self.tunnels.withLock { $0 }

		tasks.values.forEach { $0.cancel() }
	}

	func tunnel(requestStream: GRPCAsyncRequestStream<Caked_SeamlessStream>, responseStream: GRPCAsyncResponseStreamWriter<Caked_SeamlessStream>, context: GRPCAsyncServerCallContext) async throws {
		guard self.shutdown.withLock({ !$0 }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		guard let vmName = context.request.headers.first(name: "CAKEAGENT_VMNAME") else {
			self.logger.error("no CAKEAGENT_VMNAME header")

			throw ServiceError(String(localized: "no CAKEAGENT_VMNAME header"))
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

		// Caker.app or a process with a UI already shows them: two listeners would fight over the socket.
		guard let lock = SeamlessServer.acquireListenerLock(for: path) else {
			throw GRPCStatus(code: .alreadyExists, message: String(format: String(localized: "The windows of VM %@ are already shown by another process"), vmName))
		}

		defer {
			unlink(path)
			SeamlessServer.releaseListenerLock(lock)
		}

		let id = UUID()
		let task = Task { await self.run(vmName: vmName, path: path, requestStream: requestStream, responseStream: responseStream) }

		self.tunnels.withLock { $0[id] = task }

		defer {
			self.tunnels.withLock { _ = $0.removeValue(forKey: id) }
		}

		await withTaskCancellationHandler {
			await task.value
		} onCancel: {
			task.cancel()
		}
	}

	private func run(vmName: String, path: String, requestStream: GRPCAsyncRequestStream<Caked_SeamlessStream>, responseStream: GRPCAsyncResponseStreamWriter<Caked_SeamlessStream>) async {
		self.logger.debug("Start seamless tunnel for VM \(vmName) on \(path)")

		let relay = Relay()
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
			// makes NIO give up) is bound again while the client is still there.
			group.addTask {
				while clientGone.withLock({ $0 }) == false && Task.isCancelled == false {
					do {
						try await self.listen(vmName: vmName, path: path, relay: relay, responseStream: responseStream) { channel in
							listener.withLock { $0 = channel }

							// The client may have left while this was binding.
							if clientGone.withLock({ $0 }) {
								channel.close(promise: nil)
							}
						}
					} catch {
						self.logger.debug("Seamless listener of VM \(vmName) ended: \(error)")
					}

					if clientGone.withLock({ $0 }) == false {
						try? await Task.sleep(for: .milliseconds(200))
					}
				}

				relay.finish()
			}

			await group.waitForAll()
		}

		self.logger.debug("Seamless tunnel closed for VM \(vmName)")
	}

	/// Listens on the seamless socket until the listener closes. One guest connection at a time: a new one replaces the previous.
	private func listen(vmName: String, path: String, relay: Relay, responseStream: GRPCAsyncResponseStreamWriter<Caked_SeamlessStream>, bound: (Channel) -> Void) async throws {
		let server = try await ServerBootstrap(group: self.group)
			.bind(unixDomainSocketPath: path, cleanupExistingSocketFile: true) { channel in
				channel.eventLoop.makeCompletedFuture {
					try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
				}
			}

		// The guest controls what is shown on the desktop, so only this user may connect.
		chmod(path, 0o600)
		bound(server.channel)

		try await server.executeThenClose { inbound in
			await withTaskGroup(of: Void.self) { group in
				do {
					for try await connection in inbound {
						let outgoing = relay.newConnection()

						self.logger.debug("Guest compositor connected for VM \(vmName)")

						group.addTask {
							await self.pump(connection, outgoing: outgoing, responseStream: responseStream, vmName: vmName)
						}
					}
				} catch {
					self.logger.debug("Seamless accept loop of VM \(vmName) ended: \(error)")
				}

				group.cancelAll()
			}
		}
	}

	private func pump(_ connection: NIOAsyncChannel<ByteBuffer, ByteBuffer>, outgoing: AsyncStream<ByteBuffer>, responseStream: GRPCAsyncResponseStreamWriter<Caked_SeamlessStream>, vmName: String) async {
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
