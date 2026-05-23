//
//  LXDExecRunner.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/05/2026.
//
import CakeAgentLib
import CakedLib
import Combine
import Foundation
import GRPCLib
import NIOCore
import Vapor

// MARK: - Runner

/// Namespace for running an LXD exec operation once all WebSocket fds are connected.
final class LXDExecRunner: @unchecked Sendable, LXDRunnable {
	typealias AsyncThrowingStreamDatas = (stream: AsyncThrowingStream<Data, Error>, continuation: AsyncThrowingStream<Data, Error>.Continuation)

	let operationId: String
	let context: LXDExecContext
	let location: VMLocation
	let logger = Logger("LXDExecRunner")
	var phase: CancellablePhase = .none

	enum CancellablePhase {
		case none
		case waitConnection(Task<[String: WebSocket]?, Never>, Task<Void, Never>)
		case waitInput([String: WebSocket], AsyncThrowingStreamDatas)
		case webSocket([String: WebSocket])
	}

	init(_ location: VMLocation, operationId: String, context: LXDExecContext) {
		self.operationId = operationId
		self.context = context
		self.location = location
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
					let exitCode = try await runNonInteractive(websockets: websockets)

					sendExitCode(exitCode, to: controlWS)
					await LXDOperationStore.shared.complete(id: operationId, success: exitCode == 0)

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

	// MARK: - Non-interactive exec

	/// Buffers stdin from `stdinWS` until it closes, then runs the command via
	/// `CakeAgentConnection.run()` and forwards stdout/stderr to their WebSockets.
	private func runNonInteractive(websockets: [String: WebSocket]) async throws -> Int32 {
		guard let stdinWS = websockets["0"], let stdoutWS = websockets["1"], let stderrWS = websockets["2"] else {
			throw ServiceError("Missing stdin/stdout/stderr WebSocket")
		}
		#if DEBUG
			stdinWS.onClose.whenComplete { _ in
				self.logger.debug("Stdin WebSocket closed")
			}

			stdoutWS.onClose.whenComplete { _ in
				self.logger.debug("Stdout WebSocket closed")
			}

			stderrWS.onClose.whenComplete { _ in
				self.logger.debug("Stderr WebSocket closed")
			}
		#endif

		// Buffer stdin data from WebSocket until it closes.
		let stream = AsyncThrowingStream.makeStream(of: Data.self)

		self.phase = .waitInput(websockets, stream)

		stdinWS.onBinary { (_, buf) async -> Void in
			var buf = buf

			if let bytes = buf.readBytes(length: buf.readableBytes), !bytes.isEmpty {
				stream.continuation.yield(Data(bytes))
			}
		}

		stdinWS.onText { (_, text) async -> Void in
			if let data = text.data(using: .utf8), !data.isEmpty {
				stream.continuation.yield(data)
			}
		}

		stdinWS.onClose.whenComplete { _ in
			stream.continuation.finish()
		}

		var stdinData = Data()

		for try await chunk in stream.stream {
			stdinData.append(contentsOf: chunk)
		}

		// Run the command via CakeAgent.
		let conn = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: location.agentURL, timeout: 300, runMode: context.runMode)

		let command = context.command[0]
		let args = Array(context.command.dropFirst())
		let reply = try conn.run(command: command, arguments: args, input: stdinData.isEmpty ? nil : stdinData)

		// Forward stdout to WebSocket 1.
		if reply.stdout.isEmpty == false {
			try? await stdoutWS.send([UInt8](reply.stdout))
		}

		try? await stdoutWS.close(code: .normalClosure)

		// Forward stderr to WebSocket 2.
		if reply.stderr.isEmpty == false {
			try? await stderrWS.send([UInt8](reply.stderr))
		}

		try? await stderrWS.close(code: .normalClosure)

		return reply.exitCode
	}

	// MARK: - Helpers

	private func sendExitCode(_ code: Int32, to ws: WebSocket?) {
		let msg = #"{"command":"metadata","metadata":{"return":\#(code)}}"#
		ws?.send(msg)
		_ = ws?.close(code: .normalClosure)
	}
}
