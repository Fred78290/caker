//
//  LXDExecRunner.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/05/2026.
//

import CakedLib
import Foundation
import GRPCLib
import NIOCore
import Vapor

// MARK: - Control channel message

/// Minimal decodable for LXD WebSocket control-channel messages.
private struct LXDControlMessage: Decodable {
	var command: String
	var args: [String: String]?
}

// MARK: - Runner

/// Namespace for running an LXD exec operation once all WebSocket fds are connected.
enum LXDExecRunner {

	/// Entry point called from a detached `Task` after the operation has been registered.
	///
	/// Waits for all required WebSocket fds to connect (timeout: 30 s), then runs the
	/// command either interactively (PTY via `ShellHandler`) or non-interactively
	/// (buffered stdin/stdout/stderr via `CakeAgentConnection.run()`).
	static func run(operationId: String, context: LXDExecContext) async {
		// Wait for all WebSocket connections (max 30 s).
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
				id: operationId, success: false,
				error: "Timed out waiting for WebSocket connections"
			)
			return
		}
		timeoutTask.cancel()

		let controlWS = websockets["control"]

		do {
			let location = try StorageLocation(runMode: context.runMode).find(context.instanceName)
			let exitCode: Int32

			if context.interactive {
				exitCode = try await runInteractiveExec(
					location: location,
					context: context,
					ptyWS: websockets["0"]!,
					controlWS: controlWS!
				)
			} else {
				exitCode = try await runNonInteractiveExec(
					location: location,
					context: context,
					stdinWS: websockets["0"]!,
					stdoutWS: websockets["1"]!,
					stderrWS: websockets["2"]!
				)
			}

			sendExitCode(exitCode, to: controlWS)
			await LXDOperationStore.shared.complete(id: operationId, success: exitCode == 0)

		} catch {
			 Logger(label: "LXDExecRunner").error("Exec failed: \(error)")
			sendExitCode(1, to: controlWS)
			await LXDOperationStore.shared.complete(
				id: operationId, success: false, error: error.localizedDescription
			)
		}

		await LXDExecSessionStore.shared.remove(operationId: operationId)
	}

	// MARK: - Non-interactive exec

	/// Buffers stdin from `stdinWS` until it closes, then runs the command via
	/// `CakeAgentConnection.run()` and forwards stdout/stderr to their WebSockets.
	private static func runNonInteractiveExec(
		location: VMLocation,
		context: LXDExecContext,
		stdinWS: WebSocket,
		stdoutWS: WebSocket,
		stderrWS: WebSocket
	) async throws -> Int32 {
		// Buffer stdin data from WebSocket until it closes.
		let (stdinStream, stdinCont) = AsyncStream.makeStream(of: [UInt8].self)
		stdinWS.onBinary { _, buf in
			var buf = buf
			stdinCont.yield(buf.readBytes(length: buf.readableBytes) ?? [])
		}
		stdinWS.onClose.whenComplete { _ in
			stdinCont.finish()
		}

		var stdinData = Data()
		for await chunk in stdinStream {
			stdinData.append(contentsOf: chunk)
		}

		// Run the command via CakeAgent.
		let conn = try CakeAgentConnection.createCakeAgentConnection(
			on: Utilities.group.next(),
			listeningAddress: location.agentURL,
			timeout: 300,
			runMode: context.runMode
		)

		let command = context.command[0]
		let args = Array(context.command.dropFirst())
		let reply = try conn.run(
			command: command,
			arguments: args,
			input: stdinData.isEmpty ? nil : stdinData
		)

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

	// MARK: - Interactive exec

	/// Starts an interactive PTY shell via `ShellHandler`, then bridges:
	/// - WebSocket 0 (pty) ↔ shell stdin/stdout
	/// - WebSocket control → shell terminal resize
	private static func runInteractiveExec(
		location: VMLocation,
		context: LXDExecContext,
		ptyWS: WebSocket,
		controlWS: WebSocket
	) async throws -> Int32 {
		let shell = try ShellHandler.shell(
			vmURL: location.url,
			terminalSize: ShellHandler.TerminalSize(rows: Int32(context.height), cols: Int32(context.width)),
			connectionTimeout: 30,
			runMode: context.runMode
		)

		// PTY WebSocket → shell stdin
		ptyWS.onBinary { _, buf in
			var buf = buf
			if let bytes = buf.readBytes(length: buf.readableBytes), bytes.isEmpty == false {
				shell.sendDatas(data: bytes[...])
			}
		}

		// Control WebSocket → terminal resize
		controlWS.onText { _, text in
			guard
				let data = text.data(using: .utf8),
				let msg = try? JSONDecoder().decode(LXDControlMessage.self, from: data),
				msg.command == "window-resize",
				let heightStr = msg.args?["height"],
				let widthStr = msg.args?["width"],
				let h = Int(heightStr),
				let w = Int(widthStr)
			else { return }
			shell.sendTerminalSize(rows: h, cols: w)
		}

		// Shell output → PTY WebSocket
		var exitCode: Int32 = 0
		do {
			for try await response in shell {
				switch response {
				case .stdout(let data):
					try? await ptyWS.send([UInt8](data))
				case .stderr(let data):
					// On a PTY stderr is merged into the same fd.
					try? await ptyWS.send([UInt8](data))
				case .exitCode(let code):
					exitCode = code
					shell.finish()
					shell.closeShell(promise: nil)
					try? await ptyWS.close(code: .normalClosure)
					return exitCode
				case .failure(let reason):
					Logger(label: "LXDExecRunner").error("Shell failure: \(reason)")
					shell.finish()
					shell.closeShell(promise: nil)
					try? await ptyWS.close(code: .normalClosure)
					return 1
				case .established:
					break
				}
			}
		} catch {
			shell.finish()
			shell.closeShell(promise: nil)
			try? await ptyWS.close(code: .normalClosure)
			throw error
		}

		try? await ptyWS.close(code: .normalClosure)
		return exitCode
	}

	// MARK: - Helpers

	private static func sendExitCode(_ code: Int32, to ws: WebSocket?) {
		let msg = #"{"command":"metadata","metadata":{"return":\#(code)}}"#
		ws?.send(msg)
		_ = ws?.close(code: .normalClosure)
	}
}
