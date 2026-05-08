//
//  LXDAuthGroupsController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/05/2026.
//

import Foundation
import Vapor

/// Handles /1.0/auth/groups routes
struct LXDAuthGroupsController: RouteCollection {
	func boot(routes: any RoutesBuilder) throws {
		let groups = routes.grouped("1.0", "auth", "groups")

		groups.get(use: listGroups)
		groups.post(use: createGroup)

		let named = groups.grouped(":groupName")
		named.get(use: getGroup)
		named.put(use: putGroup)
		named.patch(use: patchGroup)
		named.delete(use: deleteGroup)
		named.post(use: renameGroup)
	}

	// GET /1.0/auth/groups[?recursion=1]
	@Sendable
	func listGroups(req: Request) async throws -> Response {
		let recursion = req.query[Int.self, at: "recursion"] ?? 0

		if recursion >= 1 {
			let all = await LXDAuthGroupStore.shared.list()
			return try await LXDResponse<[LXDAuthGroup]>.sync(all).encodeResponse(for: req)
		}

		let urls = await LXDAuthGroupStore.shared.listURLs()
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// POST /1.0/auth/groups — create
	@Sendable
	func createGroup(req: Request) async throws -> Response {
		let body = try req.content.decode(LXDAuthGroupWriteRequest.self)

		guard let name = body.name, name.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing group name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let created = await LXDAuthGroupStore.shared.create(
			name: name,
			description: body.description ?? "",
			permissions: body.permissions ?? [],
			identities: body.identities ?? LXDAuthGroupIdentities(oidc: [], tls: []),
			identityProviderGroups: body.identityProviderGroups ?? []
		)

		guard created != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Group '\(name)' already exists", code: 409)
				.encodeResponse(status: .conflict, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata(), status: "Created", statusCode: 201)
			.encodeResponse(status: .created, for: req)
	}

	// GET /1.0/auth/groups/:groupName
	@Sendable
	func getGroup(req: Request) async throws -> Response {
		guard let name = req.parameters.get("groupName") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing group name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let group = await LXDAuthGroupStore.shared.get(name: name) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Group '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDAuthGroup>.sync(group).encodeResponse(for: req)
	}

	// PUT /1.0/auth/groups/:groupName — full replace
	@Sendable
	func putGroup(req: Request) async throws -> Response {
		guard let name = req.parameters.get("groupName") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing group name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let body = try req.content.decode(LXDAuthGroupWriteRequest.self)

		let updated = await LXDAuthGroupStore.shared.put(
			name: name,
			description: body.description ?? "",
			permissions: body.permissions ?? [],
			identities: body.identities ?? LXDAuthGroupIdentities(oidc: [], tls: []),
			identityProviderGroups: body.identityProviderGroups ?? []
		)

		guard updated != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Group '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// PATCH /1.0/auth/groups/:groupName — partial update
	@Sendable
	func patchGroup(req: Request) async throws -> Response {
		guard let name = req.parameters.get("groupName") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing group name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let body = try req.content.decode(LXDAuthGroupWriteRequest.self)

		let updated = await LXDAuthGroupStore.shared.patch(
			name: name,
			description: body.description,
			permissions: body.permissions,
			identities: body.identities,
			identityProviderGroups: body.identityProviderGroups
		)

		guard updated != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Group '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// DELETE /1.0/auth/groups/:groupName
	@Sendable
	func deleteGroup(req: Request) async throws -> Response {
		guard let name = req.parameters.get("groupName") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing group name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard await LXDAuthGroupStore.shared.delete(name: name) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Group '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// POST /1.0/auth/groups/:groupName — rename
	@Sendable
	func renameGroup(req: Request) async throws -> Response {
		guard let oldName = req.parameters.get("groupName") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing group name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let body = try req.content.decode(LXDAuthGroupWriteRequest.self)

		guard let newName = body.name, newName.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing new name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard await LXDAuthGroupStore.shared.rename(from: oldName, to: newName) else {
			return try await LXDResponse<LXDEmptyMetadata>
				.error(message: "Group '\(oldName)' not found or '\(newName)' already exists", code: 409)
				.encodeResponse(status: .conflict, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}
}

// MARK: - Array<LXDAuthGroup>: Content

extension Array: @retroactive Content where Element == LXDAuthGroup {}
