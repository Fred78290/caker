//
//  LXDRemotesController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 16/05/2026.
//

import CakedLib
import Foundation
import GRPCLib
import Vapor

private struct LXDRemote: Content {
	let name: String
	let url: String
}

private struct LXDRemoteCreateRequest: Content {
	let name: String
	let url: String
}

private struct LXDRemoteUpdateRequest: Content {
	let name: String?
	let url: String?
}

/// Handles /1.0/remotes routes.
struct LXDRemotesController: RouteCollection {
	let group: EventLoopGroup
	let runMode: Utils.RunMode

	func boot(routes: any RoutesBuilder) throws {
		let remotes = routes.grouped("1.0", "remotes")

		remotes.get(use: listRemotes)
		remotes.post(use: createRemote)

		let named = remotes.grouped(":name")
		named.get(use: getRemote)
		named.put(use: putRemote)
		named.patch(use: patchRemote)
		named.delete(use: deleteRemote)
	}

	private func updateRemote(oldName: String, payload: LXDRemoteUpdateRequest, partial: Bool, req: Request) async throws -> Response {
		let reply = CakedLib.RemoteHandler.listRemote(runMode: runMode)

		guard reply.success else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: reply.reason, code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let existing = reply.remotes.first(where: { $0.name == oldName }) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Remote '\(oldName)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		let trimmedName = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines)
		let trimmedURL = payload.url?.trimmingCharacters(in: .whitespacesAndNewlines)

		if partial == false {
			guard let trimmedName, trimmedName.isEmpty == false, let trimmedURL, trimmedURL.isEmpty == false else {
				return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing remote name or URL", code: 400)
					.encodeResponse(status: .badRequest, for: req)
			}
		}

		guard partial == false || trimmedName != nil || trimmedURL != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Nothing to update", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let targetName = trimmedName.flatMap { $0.isEmpty ? nil : $0 } ?? existing.name
		let targetURLString = trimmedURL.flatMap { $0.isEmpty ? nil : $0 } ?? existing.url

		guard let targetURL = URL(string: targetURLString) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Invalid remote URL", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		if targetName != oldName, reply.remotes.contains(where: { $0.name == targetName }) {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Remote '\(targetName)' already exists", code: 409)
				.encodeResponse(status: .conflict, for: req)
		}

		if targetName == oldName, targetURLString == existing.url {
			return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
		}

		let deleted = CakedLib.RemoteHandler.deleteRemote(name: oldName, runMode: runMode)
		guard deleted.deleted else {
			let notFound = deleted.reason.localizedCaseInsensitiveContains("doesn't exists")
			let status: HTTPResponseStatus = notFound ? .notFound : .badRequest
			let code = notFound ? 404 : 400

			return try await LXDResponse<LXDEmptyMetadata>.error(message: deleted.reason, code: code)
				.encodeResponse(status: status, for: req)
		}

		let created = CakedLib.RemoteHandler.addRemote(name: targetName, url: targetURL, runMode: runMode)

		guard created.created else {
			_ = CakedLib.RemoteHandler.addRemote(name: existing.name, url: URL(string: existing.url) ?? targetURL, runMode: runMode)

			let isConflict = created.reason.localizedCaseInsensitiveContains("already exists")
			let status: HTTPResponseStatus = isConflict ? .conflict : .badRequest
			let code = isConflict ? 409 : 400

			return try await LXDResponse<LXDEmptyMetadata>.error(message: created.reason, code: code)
				.encodeResponse(status: status, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// GET /1.0/remotes[?recursion=1]
	@Sendable
	func listRemotes(req: Request) async throws -> Response {
		let recursion = (req.query[Int.self, at: "recursion"] ?? 0) != 0
		let reply = CakedLib.RemoteHandler.listRemote(runMode: runMode)

		guard reply.success else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: reply.reason)
				.encodeResponse(status: .badRequest, for: req)
		}

		if recursion {
			let remotes = reply.remotes.map { LXDRemote(name: $0.name, url: $0.url) }
			return try await LXDResponse<[LXDRemote]>.sync(remotes).encodeResponse(for: req)
		}

		let urls = reply.remotes.map { "/1.0/remotes/\($0.name)" }
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// POST /1.0/remotes
	@Sendable
	func createRemote(req: Request) async throws -> Response {
		let body = try req.content.decode(LXDRemoteCreateRequest.self)

		guard body.name.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing remote name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard body.url.isEmpty == false, let url = URL(string: body.url) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing or invalid remote URL", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let created = CakedLib.RemoteHandler.addRemote(name: body.name, url: url, runMode: runMode)

		guard created.created else {
			let isConflict = created.reason.localizedCaseInsensitiveContains("already exists")
			let status: HTTPResponseStatus = isConflict ? .conflict : .badRequest
			let code = isConflict ? 409 : 400

			return try await LXDResponse<LXDEmptyMetadata>.error(message: created.reason, code: code)
				.encodeResponse(status: status, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata(), status: "Created", statusCode: 201)
			.encodeResponse(status: .created, for: req)
	}

	// GET /1.0/remotes/:name
	@Sendable
	func getRemote(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing remote name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let reply = CakedLib.RemoteHandler.listRemote(runMode: runMode)

		guard reply.success else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: reply.reason)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let remote = reply.remotes.first(where: { $0.name == name }) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Remote '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDRemote>.sync(LXDRemote(name: remote.name, url: remote.url)).encodeResponse(for: req)
	}

	// PUT /1.0/remotes/:name
	@Sendable
	func putRemote(req: Request) async throws -> Response {
		guard let oldName = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing remote name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let payload = try req.content.decode(LXDRemoteUpdateRequest.self)
		return try await updateRemote(oldName: oldName, payload: payload, partial: false, req: req)
	}

	// PATCH /1.0/remotes/:name
	@Sendable
	func patchRemote(req: Request) async throws -> Response {
		guard let oldName = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing remote name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let payload = try req.content.decode(LXDRemoteUpdateRequest.self)
		return try await updateRemote(oldName: oldName, payload: payload, partial: true, req: req)
	}

	// DELETE /1.0/remotes/:name
	@Sendable
	func deleteRemote(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing remote name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let deleted = CakedLib.RemoteHandler.deleteRemote(name: name, runMode: runMode)

		guard deleted.deleted else {
			let notFound = deleted.reason.localizedCaseInsensitiveContains("doesn't exists")
			let status: HTTPResponseStatus = notFound ? .notFound : .badRequest
			let code = notFound ? 404 : 400

			return try await LXDResponse<LXDEmptyMetadata>.error(message: deleted.reason, code: code)
				.encodeResponse(status: status, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}
}
