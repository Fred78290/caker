//
//  LXDConsoleVGARunner.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/05/2026.
//
import CakeAgentLib
import CakedLib
import Combine
import Foundation
import NIO
import NIOCore
import Vapor

/// Bridges a LXD VGA console WebSocket (fd "0") to the VM's raw VNC TCP socket.
///
/// Flow:
///  1. Wait for WebSocket connections on fd "0" (VNC data) .
///  2. Resolve the VNC TCP endpoint via `VNCInfosHandler.vncInfos(name:runMode:)`.
///  3. Open a TCP connection to the VNC server using NIO `ClientBootstrap`.
///  4. Relay bytes bidirectionally: WS binary frames → VNC TCP, VNC TCP reads → WS binary frames.
final class LXDConsoleVGARunner: @unchecked Sendable, LXDRunnable {
	typealias AsyncStreamDatas = (stream: AsyncStream<Data>, continuation: AsyncStream<Data>.Continuation)

	let operationId: String
	let context: LXDExecContext
	let location: VMLocation
	let logger = Logger("LXDConsoleVGARunner")
	var phase: CancellablePhase = .none

	enum CancellablePhase {
		case none
		case waitConnection(Task<[String: WebSocket]?, Never>, Task<Void, Never>)
		case vncBridged(AsyncStreamDatas, Channel)
	}

	func cancel() async {
		switch self.phase {
			case .waitConnection(let waitTask, let timeoutTask):
			waitTask.cancel()
			timeoutTask.cancel()
		case .vncBridged(let stream, _):
			stream.continuation.finish()
		default:
			break
		}

		await LXDOperationStore.shared.complete(id: operationId, success: false, error: "Cancelled")
		await LXDExecSessionStore.shared.remove(operationId: operationId)
	}

	init(_ location: VMLocation, operationId: String, context: LXDExecContext) {
		self.operationId = operationId
		self.context = context
		self.location = location
	}

	func run() async {
		await withTaskCancellationHandler(
			operation: {
				defer {
					self.phase = .none
				}

				// ── 1. Wait for WebSocket connections (max 30 s) ──────────────────────────
				let waitTask = Task<[String: WebSocket]?, Never> {
					await LXDExecSessionStore.shared.waitForConnections(operationId: operationId)
				}

				let timeoutTask = Task {
					try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30 s
					waitTask.cancel()
					await LXDExecSessionStore.shared.remove(operationId: operationId)
				}

				self.phase = .waitConnection(waitTask, timeoutTask)

				guard let websockets = await waitTask.value else {
					timeoutTask.cancel()
					await LXDOperationStore.shared.complete(id: operationId, success: false, error: "Timed out waiting for WebSocket connections")
					return
				}

				timeoutTask.cancel()

				guard let vncWS = websockets["0"] else {
					await LXDOperationStore.shared.complete(id: operationId, success: false, error: "Missing VNC data WebSocket (fd 0)")
					await LXDExecSessionStore.shared.remove(operationId: operationId)
					return
				}

				// ── 2. Resolve VNC endpoint ────────────────────────────────────────────────
				do {
					let vncHost = "127.0.0.1"
					let vncInfos = try CakedLib.VNCInfosHandler.vncInfos(location: self.location, runMode: context.runMode)

					guard let vncURLStr = vncInfos.urls.first, let vncURL = URL(string: vncURLStr), let vncPort = vncURL.port else {
						throw ServiceError("No VNC URL available for instance '\(context.instanceName)'")
					}

					self.logger.debug("VGA console for '\(context.instanceName)': bridging to \(vncHost):\(vncPort)")

					// ── 3 & 4. Bridge WebSocket ↔ VNC TCP ─────────────────────────────────
					try await bridge(ws: vncWS, vncHost: vncHost, vncPort: vncPort)

					await LXDOperationStore.shared.complete(id: operationId, success: true)
				} catch {
					self.logger.error("VGA console failed for '\(context.instanceName)': \(error)")

					await LXDOperationStore.shared.complete(id: operationId, success: false, error: error.localizedDescription)
				}

				// Close both WebSockets gracefully.
				try? await vncWS.close(code: .normalClosure)

				await LXDExecSessionStore.shared.remove(operationId: operationId)
			},
			onCancel: {
				try? Utilities.group.next().makeFutureWithTask {
					await self.cancel()
				}.wait()
			})
	}

	// MARK: - TCP ↔ WebSocket bridge

	/// Relays bytes between the WebSocket and the VNC TCP socket until either side closes.
	private func bridge(ws: WebSocket, vncHost: String, vncPort: Int) async throws {
		// Buffer incoming WebSocket binary frames via AsyncStream so they can be fed to the
		// NIO async write path without mixing callback and async/await concurrency models.
		let stream = AsyncStream.makeStream(of: Data.self)

		ws.onBinary { (_, buf) async -> Void in
			var buf = buf

			if let bytes = buf.readBytes(length: buf.readableBytes), !bytes.isEmpty {
				stream.continuation.yield(Data(bytes))
			}
		}

		ws.onClose.whenComplete { _ in
			self.logger.debug("WebSocket closed")
			stream.continuation.finish()
		}

		// Connect to the VNC TCP socket.
		let bootstrap = ClientBootstrap(group: Utilities.group)
			.channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.channelInitializer {
				channel in channel.eventLoop.makeSucceededVoidFuture()
			}

		let asyncChannel = try await bootstrap.connect(host: vncHost, port: vncPort) { channel in
			self.phase = .vncBridged(stream, channel)

			return channel.eventLoop.makeCompletedFuture {
				try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
			}
		}

		try await asyncChannel.executeThenClose { input, output in
			self.logger.debug("Start VNC TCP relay")

			await withTaskGroup(of: Void.self) { group in
				// WebSocket → VNC TCP
				group.addTask {
					for await data in stream.stream {
						do {
							try await output.write(ByteBuffer(data: data))
						} catch {
							self.logger.error("Error closing WebSocket → VNC TCP relay for '\(self.context.instanceName)', \(error)")
							break
						}
					}

					self.logger.debug("Leave WebSocket → VNC TCP relay")
					// WebSocket side closed; signal the other direction.
					asyncChannel.channel.close(promise: nil)
				}

				// VNC TCP → WebSocket
				group.addTask {
					do {
						for try await buffer in input {
							try? await ws.send([UInt8](buffer.readableBytesView))
						}
					} catch {
						self.logger.error("Error closing VNC TCP relay -> WebSocket for '\(self.context.instanceName)', \(error)")
					}

					self.logger.debug("Leave VNC TCP relay -> WebSocket")
					// VNC server closed; signal the WebSocket→VNC direction to stop.
					stream.continuation.finish()
				}

				self.logger.debug("Enter VNC TCP relay")

				await group.waitForAll()
			}
		}
		
		self.logger.debug("Relay closed")
	}
}
