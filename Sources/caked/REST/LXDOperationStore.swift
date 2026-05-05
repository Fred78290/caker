//
//  LXDOperationStore.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import Foundation

// MARK: - LXD Operation Store

/// Thread-safe in-memory store for LXD async operations.
actor LXDOperationStore {
	static let shared = LXDOperationStore()

	private var operations: [String: LXDOperationMetadata] = [:]

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
		operations.removeValue(forKey: id) != nil
	}
}
