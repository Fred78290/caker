//
//  LXDConsoleTextRunner.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/05/2026.
//
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib
import NIOCore
import Synchronization
import Vapor

// MARK: - Control channel message

/// Minimal decodable for LXD WebSocket control-channel messages.
private struct LXDControlMessage: Decodable {
	var command: String
	var args: [String: String]?
}

// MARK: - Runner

/// Namespace for running an LXD exec operation once all WebSocket fds are connected.
final class LXDConsoleTextRunner: @unchecked Sendable, LXDRunnable {
	typealias AsyncThrowingStreamDatas = (stream: AsyncThrowingStream<Data, Error>, continuation: AsyncThrowingStream<Data, Error>.Continuation)

	let operationId: String
	let context: LXDExecContext
	let location: VMLocation
	let logger = Logger("LXDConsoleTextRunner")
	private let _phase: Mutex<CancellablePhase> = .init(.none)
	var phase: CancellablePhase {
		get { _phase.withLock { $0 } }
		set { _phase.withLock { $0 = newValue } }
	}
	let shellStream: (any ShellHandler.ShellHandlerProtocol)

	enum CancellablePhase {
		case none
		case waitConnection(Task<[String: WebSocket]?, Never>, Task<Void, Never>)
		case waitInput([String: WebSocket], AsyncThrowingStreamDatas)
		case webSocket([String: WebSocket])
	}

	deinit {
		self.shellStream.closeShell()
	}

	init(_ location: VMLocation, operationId: String, context: LXDExecContext) throws {
		self.operationId = operationId
		self.context = context
		self.location = location
		self.shellStream = try ShellHandler.shell(
			vmURL: location.url,
			terminalSize: ShellHandler.TerminalSize(rows: Int32(context.height), cols: Int32(context.width)),
			connectionTimeout: 30,
			runMode: context.runMode
		)
	}

	func cancel() async {
		switch self.phase {
		case .waitConnection(let waitTask, let timeoutTask):
			waitTask.cancel()
			timeoutTask.cancel()
		case .waitInput(let websockets, let stream):
			stream.continuation.finish()
			for ws in websockets.values {
				try? await ws.close(code: .goingAway)
			}
		case .webSocket(let websockets):
			for ws in websockets.values {
				try? await ws.close(code: .goingAway)
			}
		default:
			break
		}

		self.shellStream.closeShell()

		await LXDOperationStore.shared.complete(id: operationId, success: false, error: "Cancelled")
		await LXDExecSessionStore.shared.remove(operationId: operationId)
	}

	/// Entry point called from a detached `Task` after the operation has been registered.
	///
	/// Waits for all required WebSocket fds to connect (timeout: 30 s), then runs the
	/// command either interactively (PTY via `ShellHandler`) or non-interactively
	/// (buffered stdin/stdout/stderr via `CakeAgentConnection.run()`).
	func run() async {
		await withTaskCancellationHandler(
			operation: {
				defer {
					self.phase = .none
				}

				// Wait for all WebSocket connections (max 30 s).
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

				let controlWS = websockets["control"]

				do {
					let exitCode = try await runInteractiveExec(websockets: websockets)

					sendExitCode(exitCode, to: controlWS)
					await LXDOperationStore.shared.complete(id: operationId, success: exitCode == 0, error: exitCode == 0 ? "Success" : "Exit code \(exitCode)")
				} catch {
					self.logger.error("Exec failed: \(error)")
					sendExitCode(1, to: controlWS)
					await LXDOperationStore.shared.complete(id: operationId, success: false, error: error.localizedDescription)
				}

				await LXDExecSessionStore.shared.remove(operationId: operationId)
			},
			onCancel: {
				try? Utilities.group.next().makeFutureWithTask {
					await self.cancel()
				}.wait()
			})
	}

	// MARK: - Interactive exec

	/// Starts an interactive PTY shell via `ShellHandler`, then bridges:
	/// - WebSocket 0 (pty) ↔ shell stdin/stdout
	/// - WebSocket control → shell terminal resize
	private func runInteractiveExec(websockets: [String: WebSocket]) async throws -> Int32 {
		guard let ptyWS = websockets["0"], let controlWS = websockets["control"] else {
			throw ServiceError("Missing pty/control WebSocket")
		}

		func convertStream(_ datas: Data) -> [UInt8] {
			var out: [UInt8] = []
			var previous: UInt8 = 0

			out.reserveCapacity(datas.count * 2)

			datas.forEach { b in
				if b == 0x0A && previous != 0x0D {
					out.append(0x0D)  // insert CR after LF when not already preceded by CR
				}

				out.append(b)

				previous = b
			}

			return out
		}

		ptyWS.onClose.whenComplete { _ in
			self.logger.debug("ptyWS WebSocket closed")
			// Closing controlWS triggers its onClose handler which calls closeShell().
			// This covers the case where the PTY side drops (network error, browser tab
			// closed) while the control channel is still alive.
			_ = controlWS.close(code: .goingAway)
		}

		controlWS.onClose.whenComplete { _ in
			self.logger.debug("controlWS WebSocket closed")

			self.shellStream.closeShell()
		}

		self.phase = .webSocket(websockets)

		@discardableResult
		func closeWebSockets(_ exitCode: Int32 = 0) async -> Int32 {
			try? await ptyWS.close(code: .normalClosure)
			try? await controlWS.close(code: .normalClosure)

			return exitCode
		}

		// PTY WebSocket → shell stdin
		ptyWS.onBinary { (_, buf) async -> Void in
			var buf = buf
			if let bytes = buf.readBytes(length: buf.readableBytes), bytes.isEmpty == false {
				self.shellStream.sendDatas(data: bytes[...])
			}
		}

		ptyWS.onText { (_, text) async -> Void in
			if let data = text.data(using: .utf8), !data.isEmpty {
				let bytes = [UInt8](data)
				self.shellStream.sendDatas(data: bytes[...])
			}
		}

		// Control WebSocket → terminal resize
		controlWS.onText { (_, text) async -> Void in
			guard let data = text.data(using: .utf8), let msg = try? JSONDecoder().decode(LXDControlMessage.self, from: data) else {
				return
			}

			guard msg.command == "window-resize", let heightStr = msg.args?["height"], let widthStr = msg.args?["width"], let h = Int(heightStr), let w = Int(widthStr) else {
				return
			}

			self.shellStream.sendTerminalSize(rows: h, cols: w)
		}

		do {
			for try await response in self.shellStream {
				switch response {
				case .stdout(let data):
					try? await ptyWS.send(convertStream(data))
				case .stderr(let data):
					// On a PTY stderr is merged into the same fd.
					try? await ptyWS.send(convertStream(data))
				case .exitCode(let code):
					return await closeWebSockets(code)
				case .failure(let reason):
					self.logger.error("Shell failure: \(reason)")
					return await closeWebSockets(1)
				case .established:
					break
				}
			}
		} catch {
			await closeWebSockets()
			throw error
		}

		return await closeWebSockets()
	}

	// MARK: - Helpers

	private func sendExitCode(_ code: Int32, to ws: WebSocket?) {
		let msg = #"{"command":"metadata","metadata":{"return":\#(code)}}"#
		ws?.send(msg)
		_ = ws?.close(code: .normalClosure)
	}
}
