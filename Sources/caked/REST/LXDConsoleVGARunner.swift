//
//  LXDConsoleVGARunner.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/05/2026.
//

import CakedLib
import Foundation
import NIO
import NIOCore
import Vapor

/// Bridges a LXD VGA console WebSocket (fd "0") to the VM's raw VNC TCP socket.
///
/// Flow:
///  1. Wait for WebSocket connections on fd "0" (VNC data) and "control".
///  2. Resolve the VNC TCP endpoint via `VNCInfosHandler.vncInfos(name:runMode:)`.
///  3. Open a TCP connection to the VNC server using NIO `ClientBootstrap`.
///  4. Relay bytes bidirectionally: WS binary frames → VNC TCP, VNC TCP reads → WS binary frames.
enum LXDConsoleVGARunner {

	static func run(operationId: String, context: LXDExecContext) async {
		let logger = Logger(label: "LXDConsoleVGARunner")

		// ── 1. Wait for WebSocket connections (max 30 s) ──────────────────────────
		let waitTask = Task<[String: WebSocket]?, Never> {
			await LXDExecSessionStore.shared.waitForConnections(operationId: operationId)
		}
		let timeoutTask = Task {
			try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 s
			waitTask.cancel()
			await LXDExecSessionStore.shared.remove(operationId: operationId)
		}

		guard let websockets = await waitTask.value else {
			timeoutTask.cancel()
			await LXDOperationStore.shared.complete(
				id: operationId, success: false, error: "Timed out waiting for WebSocket connections"
			)
			return
		}
		timeoutTask.cancel()

		guard let vncWS = websockets["0"] else {
			await LXDOperationStore.shared.complete(
				id: operationId, success: false, error: "Missing VNC data WebSocket (fd 0)"
			)
			await LXDExecSessionStore.shared.remove(operationId: operationId)
			return
		}

		// ── 2. Resolve VNC endpoint ────────────────────────────────────────────────
		do {
			let vncInfos = try CakedLib.VNCInfosHandler.vncInfos(
				name: context.instanceName, runMode: context.runMode
			)

			guard let vncURLStr = vncInfos.urls.first,
				  let vncURL = URL(string: vncURLStr),
				  let vncPort = vncURL.port else {
				throw ServiceError("No VNC URL available for instance '\(context.instanceName)'")
			}
			let vncHost = vncURL.host(percentEncoded: false) ?? "127.0.0.1"

			logger.debug("VGA console for '\(context.instanceName)': bridging to \(vncHost):\(vncPort)")

			// ── 3 & 4. Bridge WebSocket ↔ VNC TCP ─────────────────────────────────
			try await bridge(ws: vncWS, vncHost: vncHost, vncPort: vncPort)

			await LXDOperationStore.shared.complete(id: operationId, success: true)
		} catch {
			logger.error("VGA console failed for '\(context.instanceName)': \(error)")
			await LXDOperationStore.shared.complete(
				id: operationId, success: false, error: error.localizedDescription
			)
		}

		// Close both WebSockets gracefully.
		try? await vncWS.close(code: .normalClosure)
		if let controlWS = websockets["control"] {
			try? await controlWS.close(code: .normalClosure)
		}
		await LXDExecSessionStore.shared.remove(operationId: operationId)
	}

	// MARK: - TCP ↔ WebSocket bridge

	/// Relays bytes between the WebSocket and the VNC TCP socket until either side closes.
	private static func bridge(ws: WebSocket, vncHost: String, vncPort: Int) async throws {
		// Buffer incoming WebSocket binary frames via AsyncStream so they can be fed to the
		// NIO async write path without mixing callback and async/await concurrency models.
		let (wsToVNCStream, wsToVNCCont) = AsyncStream.makeStream(of: Data.self)

		ws.onBinary { _, buf in
			var buf = buf
			if let bytes = buf.readBytes(length: buf.readableBytes), !bytes.isEmpty {
				wsToVNCCont.yield(Data(bytes))
			}
		}
		ws.onClose.whenComplete { _ in
			wsToVNCCont.finish()
		}

		// Connect to the VNC TCP socket.
		let bootstrap = ClientBootstrap(group: Utilities.group)
			.channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.channelInitializer { channel in channel.eventLoop.makeSucceededVoidFuture() }

		let asyncChannel = try await bootstrap.connect(host: vncHost, port: vncPort) { channel in
			channel.eventLoop.makeCompletedFuture {
				try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
			}
		}

		let allocator = ByteBufferAllocator()

		try await asyncChannel.executeThenClose { input, output in
			await withTaskGroup(of: Void.self) { group in

				// WebSocket → VNC TCP
				group.addTask {
					for await data in wsToVNCStream {
						do {
							var buffer = allocator.buffer(capacity: data.count)
							buffer.writeBytes(data)
							try await output.write(buffer)
						} catch {
							break
						}
					}
					// WebSocket side closed; signal the other direction.
					wsToVNCCont.finish()
				}

				// VNC TCP → WebSocket
				group.addTask {
					do {
						for try await buffer in input {
							try? await ws.send([UInt8](buffer.readableBytesView))
						}
					} catch {}
					// VNC server closed; signal the WebSocket→VNC direction to stop.
					wsToVNCCont.finish()
				}

				await group.waitForAll()
			}
		}
	}
}
