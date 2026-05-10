//
//  LXDOperationStore.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import Foundation
import GRPCLib

// MARK: - LXD Operation Store

/// Thread-safe in-memory store for LXD async operations.
actor LXDOperationStore {
	static let shared = LXDOperationStore()

	private var operations: [String: LXDOperationMetadata] = [:]
	private var storeURL: URL?

	// MARK: - Persistence

	/// Loads existing state from disk and stores the persistence URL for future saves.
	/// Operations that were "Running" when the server stopped are marked as "Failure".
	func configure(runMode: Utils.RunMode) throws {
		let url = try LXDStorePersistence.storeURL(name: "lxd-operations", runMode: runMode)
		if let data = try? Data(contentsOf: url),
		   var loaded = try? JSONDecoder().decode([String: LXDOperationMetadata].self, from: data) {
			let now = ISO8601DateFormatter().string(from: Date())
			for (id, var op) in loaded where op.status == "Running" {
				op.status = "Failure"
				op.statusCode = 400
				op.error = "Server restarted"
				op.updatedAt = now
				loaded[id] = op
			}
			self.operations = loaded
		}
		self.storeURL = url
	}

	func create(description: String, resources: [String: [String]] = [:]) -> LXDOperationMetadata {
		let id = UUID().uuidString.lowercased()
		let now = ISO8601DateFormatter().string(from: Date())

		let operation = LXDOperationMetadata(
			id: id,
			type: "task",
			description: description,
			createdAt: now,
			updatedAt: now,
			status: "Running",
			statusCode: 103,
			resources: resources,
			metadata: nil,
			mayCancel: false,
			error: ""
		)

		operations[id] = operation

		return operation
	}

	func complete(id: String, success: Bool, error: String = "") {
		guard var op = operations[id] else { return }

		let now = ISO8601DateFormatter().string(from: Date())
		op.updatedAt = now

		if success {
			op.status = "Success"
			op.statusCode = 200
		} else {
			op.status = "Failure"
			op.statusCode = 400
			op.error = error
		}

		operations[id] = op
	}

	func get(id: String) -> LXDOperationMetadata? {
		operations[id]
	}

	func list() -> [LXDOperationMetadata] {
		Array(operations.values)
	}

	func listURLs() -> [String] {
		operations.keys.map { "/1.0/operations/\($0)" }
	}

	func delete(id: String) -> Bool {
		return operations.removeValue(forKey: id) != nil
	}

	/// Registers a "websocket" exec operation in the store so that it is visible via
	/// `GET /1.0/operations/:id`.  The fds secrets are NOT persisted here (they live in
	/// `LXDExecSessionStore`) because they are ephemeral and only relevant while the
	/// WebSocket connections are alive.
	func registerExec(id: String, instanceName: String) {
		let now = ISO8601DateFormatter().string(from: Date())
		let operation = LXDOperationMetadata(
			id: id,
			type: "websocket",
			description: "Executing in instance \(instanceName)",
			createdAt: now,
			updatedAt: now,
			status: "Running",
			statusCode: 103,
			resources: ["instances": ["/1.0/instances/\(instanceName)"]],
			metadata: nil,
			mayCancel: false,
			error: ""
		)
		operations[id] = operation
	}

	/// Registers a "websocket" console operation (POST /1.0/instances/{name}/console).
	func registerConsole(id: String, instanceName: String) {
		let now = ISO8601DateFormatter().string(from: Date())
		let operation = LXDOperationMetadata(
			id: id,
			type: "websocket",
			description: "Connecting to console of instance \(instanceName)",
			createdAt: now,
			updatedAt: now,
			status: "Running",
			statusCode: 103,
			resources: ["instances": ["/1.0/instances/\(instanceName)"]],
			metadata: nil,
			mayCancel: false,
			error: ""
		)
		operations[id] = operation
	}
}
