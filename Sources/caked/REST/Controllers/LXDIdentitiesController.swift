//
//  LXDIdentitiesController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/05/2026.
//

import Foundation
import Vapor
import GRPCLib

/// Handles /1.0/auth/identities routes
struct LXDIdentitiesController: RouteCollection {
	let group: EventLoopGroup
	let runMode: Utils.RunMode

	func boot(routes: any RoutesBuilder) throws {
		let identities = routes.grouped("1.0", "auth", "identities")

		// GET /1.0/auth/identities[?recursion=1]
		identities.get(use: listAllIdentities)
		// GET /1.0/auth/identities/current
		identities.get("current", use: getCurrentIdentity)

		// --- TLS ---
		let tls = identities.grouped("tls")
		tls.get(use: listTLSIdentities)
		tls.post(use: createTLSIdentity)
		let tlsNamed = tls.grouped(":nameOrID")
		tlsNamed.get(use: getTLSIdentity)
		tlsNamed.put(use: putTLSIdentity)
		tlsNamed.patch(use: patchTLSIdentity)
		tlsNamed.delete(use: deleteTLSIdentity)

		// --- Bearer ---
		let bearer = identities.grouped("bearer")
		bearer.get(use: listBearerIdentities)
		bearer.post(use: createBearerIdentity)
		let bearerNamed = bearer.grouped(":nameOrID")
		bearerNamed.get(use: getBearerIdentity)
		bearerNamed.put(use: putBearerIdentity)
		bearerNamed.patch(use: patchBearerIdentity)
		bearerNamed.delete(use: deleteBearerIdentity)
		bearerNamed.post("token", use: issueBearerToken)
	}

	// MARK: - All Identities

	// GET /1.0/auth/identities[?recursion=1]
	@Sendable
	func listAllIdentities(req: Request) async throws -> Response {
		let recursion = (req.query[Int.self, at: "recursion"] ?? 0) != 0

		if recursion {
			let all = await LXDIdentityStore.shared.list()
			return try await LXDResponse<LXDIdentityListMetadata>.syncIdentities(all).encodeResponse(for: req)
		}

		let urls = await LXDIdentityStore.shared.listURLs()
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// GET /1.0/auth/identities/current
	@Sendable
	func getCurrentIdentity(req: Request) async throws -> Response {
		// Return a minimal IdentityInfo for the current TLS caller.
		let info = LXDIdentityInfo(
			authenticationMethod: "tls",
			type: "Client certificate",
			id: "",
			name: "current",
			groups: [],
			tlsCertificate: "",
			effectiveGroups: [],
			effectivePermissions: [],
			fineGrained: false,
			expiresAt: nil
		)

		return try await LXDResponse<LXDIdentityInfo>.sync(info).encodeResponse(for: req)
	}

	// MARK: - TLS Identities

	// GET /1.0/auth/identities/tls[?recursion=1]
	@Sendable
	func listTLSIdentities(req: Request) async throws -> Response {
		let recursion = req.query[Int.self, at: "recursion"] ?? 0

		if recursion >= 1 {
			let all = await LXDIdentityStore.shared.listByAuthMethod("tls")
			return try await LXDResponse<LXDIdentityListMetadata>.syncIdentities(all).encodeResponse(for: req)
		}

		let urls = await LXDIdentityStore.shared.listURLsByAuthMethod("tls")
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// POST /1.0/auth/identities/tls — add TLS identity
	@Sendable
	func createTLSIdentity(req: Request) async throws -> Response {
		let body = try req.content.decode(LXDIdentitiesTLSPost.self)

		guard body.name.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let certificate = body.certificate ?? ""
		// Use a UUID as stable identifier for this in-memory store.
		let identifier = UUID().uuidString

		let created = await LXDIdentityStore.shared.create(
			authenticationMethod: "tls",
			type: "Client certificate",
			id: identifier,
			name: body.name,
			groups: body.groups ?? [],
			tlsCertificate: certificate
		)

		guard created != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(body.name)' already exists", code: 409)
				.encodeResponse(status: .conflict, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata(), status: "Created", statusCode: 201)
			.encodeResponse(status: .created, for: req)
	}

	// GET /1.0/auth/identities/tls/:nameOrID
	@Sendable
	func getTLSIdentity(req: Request) async throws -> Response {
		guard let nameOrID = req.parameters.get("nameOrID") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity identifier", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let identity = await LXDIdentityStore.shared.get(authMethod: "tls", nameOrID: nameOrID) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(nameOrID)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDIdentity>.sync(identity).encodeResponse(for: req)
	}

	// PUT /1.0/auth/identities/tls/:nameOrID — full replace
	@Sendable
	func putTLSIdentity(req: Request) async throws -> Response {
		guard let nameOrID = req.parameters.get("nameOrID") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity identifier", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let body = try req.content.decode(LXDIdentityPut.self)

		let updated = await LXDIdentityStore.shared.put(
			authMethod: "tls",
			nameOrID: nameOrID,
			groups: body.groups ?? [],
			tlsCertificate: body.tlsCertificate ?? ""
		)

		guard updated != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(nameOrID)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// PATCH /1.0/auth/identities/tls/:nameOrID — partial update
	@Sendable
	func patchTLSIdentity(req: Request) async throws -> Response {
		guard let nameOrID = req.parameters.get("nameOrID") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity identifier", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let body = try req.content.decode(LXDIdentityPut.self)

		let updated = await LXDIdentityStore.shared.patch(
			authMethod: "tls",
			nameOrID: nameOrID,
			groups: body.groups,
			tlsCertificate: body.tlsCertificate
		)

		guard updated != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(nameOrID)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// DELETE /1.0/auth/identities/tls/:nameOrID
	@Sendable
	func deleteTLSIdentity(req: Request) async throws -> Response {
		guard let nameOrID = req.parameters.get("nameOrID") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity identifier", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard await LXDIdentityStore.shared.delete(authMethod: "tls", nameOrID: nameOrID) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(nameOrID)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// MARK: - Bearer Identities

	// GET /1.0/auth/identities/bearer[?recursion=1]
	@Sendable
	func listBearerIdentities(req: Request) async throws -> Response {
		let recursion = (req.query[Int.self, at: "recursion"] ?? 0) != 0

		if recursion {
			let all = await LXDIdentityStore.shared.listByAuthMethod("bearer")
			return try await LXDResponse<LXDIdentityListMetadata>.syncIdentities(all).encodeResponse(for: req)
		}

		let urls = await LXDIdentityStore.shared.listURLsByAuthMethod("bearer")
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// POST /1.0/auth/identities/bearer — create bearer identity
	@Sendable
	func createBearerIdentity(req: Request) async throws -> Response {
		let body = try req.content.decode(LXDIdentitiesBearerPost.self)

		guard body.name.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let identifier = UUID().uuidString

		let created = await LXDIdentityStore.shared.create(
			authenticationMethod: "bearer",
			type: body.type,
			id: identifier,
			name: body.name,
			groups: body.groups ?? [],
			tlsCertificate: ""
		)

		guard created != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(body.name)' already exists", code: 409)
				.encodeResponse(status: .conflict, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata(), status: "Created", statusCode: 201)
			.encodeResponse(status: .created, for: req)
	}

	// GET /1.0/auth/identities/bearer/:nameOrID
	@Sendable
	func getBearerIdentity(req: Request) async throws -> Response {
		guard let nameOrID = req.parameters.get("nameOrID") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity identifier", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let identity = await LXDIdentityStore.shared.get(authMethod: "bearer", nameOrID: nameOrID) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(nameOrID)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDIdentity>.sync(identity).encodeResponse(for: req)
	}

	// PUT /1.0/auth/identities/bearer/:nameOrID — full replace
	@Sendable
	func putBearerIdentity(req: Request) async throws -> Response {
		guard let nameOrID = req.parameters.get("nameOrID") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity identifier", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let body = try req.content.decode(LXDIdentityPut.self)

		let updated = await LXDIdentityStore.shared.put(
			authMethod: "bearer",
			nameOrID: nameOrID,
			groups: body.groups ?? [],
			tlsCertificate: ""
		)

		guard updated != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(nameOrID)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// PATCH /1.0/auth/identities/bearer/:nameOrID — partial update
	@Sendable
	func patchBearerIdentity(req: Request) async throws -> Response {
		guard let nameOrID = req.parameters.get("nameOrID") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity identifier", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let body = try req.content.decode(LXDIdentityPut.self)

		let updated = await LXDIdentityStore.shared.patch(
			authMethod: "bearer",
			nameOrID: nameOrID,
			groups: body.groups,
			tlsCertificate: nil
		)

		guard updated != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(nameOrID)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// DELETE /1.0/auth/identities/bearer/:nameOrID
	@Sendable
	func deleteBearerIdentity(req: Request) async throws -> Response {
		guard let nameOrID = req.parameters.get("nameOrID") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity identifier", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard await LXDIdentityStore.shared.delete(authMethod: "bearer", nameOrID: nameOrID) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(nameOrID)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// POST /1.0/auth/identities/bearer/:nameOrID/token — issue a token
	@Sendable
	func issueBearerToken(req: Request) async throws -> Response {
		guard let nameOrID = req.parameters.get("nameOrID") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing identity identifier", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let identity = await LXDIdentityStore.shared.get(authMethod: "bearer", nameOrID: nameOrID) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Identity '\(nameOrID)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		// Use the persisted bearer identity id as token so PasswordAuthMiddleware can validate it from LXDIdentityStore.
		let tokenValue = identity.id
		let bearerToken = LXDIdentityBearerToken(token: tokenValue)

		return try await LXDResponse<LXDIdentityBearerToken>.sync(bearerToken).encodeResponse(for: req)
	}
}



