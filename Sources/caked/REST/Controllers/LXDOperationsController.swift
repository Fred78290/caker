//
//  LXDOperationsController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import CakedLib
import Foundation
import Vapor

/// Handles /1.0/operations routes
struct LXDOperationsController: RouteCollection {
	func boot(routes: any RoutesBuilder) throws {
		let operations = routes.grouped("1.0", "operations")
		operations.get(use: listOperations)

		let named = operations.grouped(":id")
		named.get(use: getOperation)
		named.delete(use: deleteOperation)

		named.grouped("wait").get(use: waitOperation)
		named.webSocket("websocket", onUpgrade: websocketForOperation)
	}

	// GET /1.0/operations
	@Sendable
	func listOperations(req: Request) async throws -> Response {
		let urls = await LXDOperationStore.shared.listURLs()
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// GET /1.0/operations/:id
	@Sendable
	func getOperation(req: Request) async throws -> Response {
		guard let id = req.parameters.get("id") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing operation id", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let operation = await LXDOperationStore.shared.get(id: id) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Operation '\(id)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDOperationMetadata>.sync(operation).encodeResponse(for: req)
	}

	// DELETE /1.0/operations/:id (cancel)
	@Sendable
	func deleteOperation(req: Request) async throws -> Response {
		guard let id = req.parameters.get("id") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing operation id", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let deleted = await LXDOperationStore.shared.delete(id: id) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Operation '\(id)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		await deleted.cancel()

		return try await LXDResponse<LXDEmptyMetadata>(
			type: "sync", status: "Success", statusCode: 200,
			operation: "", errorCode: 0, error: "", metadata: nil
		).encodeResponse(for: req)
	}

	// GET /1.0/operations/:id/wait
	@Sendable
	func waitOperation(req: Request) async throws -> Response {
		guard let id = req.parameters.get("id") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing operation id", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let timeout = req.query[Int.self, at: "timeout"] ?? 30
		let deadline = Date().addingTimeInterval(TimeInterval(timeout))

		while Date() < deadline {
			if let operation = await LXDOperationStore.shared.get(id: id) {
				if operation.status == "Success" || operation.status == "Failure" {
					return try await LXDResponse<LXDOperationMetadata>.sync(operation).encodeResponse(for: req)
				}
			} else {
				return try await LXDResponse<LXDEmptyMetadata>.error(message: "Operation '\(id)' not found", code: 404)
					.encodeResponse(status: .notFound, for: req)
			}

			try await Task.sleep(nanoseconds: 500_000_000) // 0.5s poll
		}

		// Return current state on timeout
		if let operation = await LXDOperationStore.shared.get(id: id) {
			return try await LXDResponse<LXDOperationMetadata>.sync(operation).encodeResponse(for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.error(message: "Operation '\(id)' not found", code: 404)
			.encodeResponse(status: .notFound, for: req)
	}

	// GET /1.0/operations/:id/websocket?secret=<uuid>
	// Upgrades the HTTP connection to a WebSocket for an LXD exec fd.
	@Sendable
	func websocketForOperation(req: Request, ws: WebSocket) async {
		guard let id = req.parameters.get("id"),
			  let secret = req.query[String.self, at: "secret"] else {
			try? await ws.close(code: .unacceptableData)
			return
		}

		guard let fd = await LXDExecSessionStore.shared.findFD(operationId: id, secret: secret) else {
			try? await ws.close(code: .unacceptableData)
			return
		}

		await LXDExecSessionStore.shared.connect(operationId: id, fd: fd, ws: ws)

		// Hold the WebSocket open until the server-side runner closes it.
		try? await ws.onClose.get()
	}
}
