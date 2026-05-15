//
//  LXDExecSessionStore.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/05/2026.
//

import CakedLib
import Foundation
import GRPCLib
import Vapor

/// Immutable description of a pending exec session (what to run and how).
struct LXDExecContext: Sendable {
	enum ExecMode {
		case interactive
		case nonInteractive
		case vga
	}

	let instanceName: String
	let command: [String]
	let environment: [String: String]
	let mode: ExecMode
	let height: Int
	let width: Int
	let runMode: Utils.RunMode
	/// fd name ("0", "1", "2", "control") → WebSocket secret.
	let fds: [String: String]

	/// The fd names that must all connect before the exec can start.
	var requiredFDs: Set<String> {
		// Interactive: single pty fd (0) + control channel.
		// Non-interactive: separate stdin (0), stdout (1), stderr (2) + control.
		switch self.mode {
			case .interactive:
				return ["0", "control"]
			case .nonInteractive:
				return ["0", "1", "2", "control"]
			case .vga:
				return ["0"]
		}
	}
}

/// Thread-safe store that coordinates WebSocket connections for LXD exec operations.
///
/// Flow:
///  1. `POST /1.0/instances/{name}/exec` calls `register(operationId:context:)`.
///  2. A background `Task` calls `waitForConnections(operationId:)` which suspends
///     until all required WebSocket fds have connected (or the session is removed).
///  3. Each WebSocket upgrade for `/1.0/operations/{id}/websocket?secret=X` calls
///     `connect(operationId:fd:ws:)` which resumes the waiter once all fds are present.
actor LXDExecSessionStore {
	static let shared = LXDExecSessionStore()

	private struct PendingSession {
		let context: LXDExecContext
		/// fd name → connected WebSocket.
		var connectedFDs: [String: WebSocket] = [:]
	}

	/// operationId → pending session.
	private var sessions: [String: PendingSession] = [:]
	/// operationId → continuation waiting for all fds to connect.
	private var waiters: [String: CheckedContinuation<[String: WebSocket]?, Never>] = [:]

	// MARK: - Registration

	func register(operationId: String, context: LXDExecContext) {
		sessions[operationId] = PendingSession(context: context)
	}

	/// Removes a session and cancels any pending waiter (resumes with `nil`).
	func remove(operationId: String) {
		sessions.removeValue(forKey: operationId)
		waiters.removeValue(forKey: operationId)?.resume(returning: nil)
	}

	// MARK: - WebSocket connection

	/// Returns the fd name (e.g. "0", "1", "control") whose secret matches `secret`,
	/// or `nil` if no matching session/fd is found.
	func findFD(operationId: String, fd: String) -> String? {
		sessions[operationId]?.context.fds.first(where: { $0.value == fd })?.key
	}

	/// Registers a WebSocket for `fd`.  If all required fds are now connected,
	/// resumes any waiter that was blocked in `waitForConnections`.
	func connect(operationId: String, fd: String, ws: WebSocket) {
		guard var session = sessions[operationId] else { return }
		session.connectedFDs[fd] = ws
		sessions[operationId] = session

		if session.context.requiredFDs.isSubset(of: Set(session.connectedFDs.keys)) {
			if let op = waiters.removeValue(forKey: operationId) {
				op.resume(returning: session.connectedFDs)
			}
		}
	}

	// MARK: - Exec trigger

	/// Suspends until all required WebSocket fds are connected (or the session is removed).
	/// Returns the full fd → WebSocket map on success, or `nil` on cancellation / removal.
	func waitForConnections(operationId: String) async -> [String: WebSocket]? {
		// Fast-path: already all connected.
		if let session = sessions[operationId], session.context.requiredFDs.isSubset(of: Set(session.connectedFDs.keys)) {
			return session.connectedFDs
		}

		// Slow-path: suspend until connect() resumes us.
		let result: [String: WebSocket]? = await withCheckedContinuation { continuation in
			// Re-check inside the actor's synchronous context to avoid a race.
			guard let session = sessions[operationId] else {
				continuation.resume(returning: nil)
				return
			}

			if session.context.requiredFDs.isSubset(of: Set(session.connectedFDs.keys)) {
				continuation.resume(returning: session.connectedFDs)
			} else {
				waiters[operationId] = continuation
			}
		}

		return result
	}
}
