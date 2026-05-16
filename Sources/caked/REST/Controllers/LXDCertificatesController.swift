//
//  LXDCertificatesController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/05/2026.
//

import Foundation
import Vapor
import GRPCLib

/// Handles /1.0/certificates routes
struct LXDCertificatesController: RouteCollection {
	let group: EventLoopGroup
	let runMode: Utils.RunMode

	func boot(routes: any RoutesBuilder) throws {
		let certs = routes.grouped("1.0", "certificates")

		certs.get(use: listCertificates)
		certs.post(use: createCertificate)

		let fingerprinted = certs.grouped(":fingerprint")
		fingerprinted.get(use: getCertificate)
		fingerprinted.put(use: putCertificate)
		fingerprinted.patch(use: patchCertificate)
		fingerprinted.delete(use: deleteCertificate)
	}

	// GET /1.0/certificates[?recursion=1]
	@Sendable
	func listCertificates(req: Request) async throws -> Response {
		let recursion = (req.query[Int.self, at: "recursion"] ?? 0) != 0

		if recursion {
			let all = await LXDCertificateStore.shared.list()
			return try await LXDResponse<LXDCertificateListMetadata>.syncCertificates(all).encodeResponse(for: req)
		}

		let urls = await LXDCertificateStore.shared.listURLs()
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// POST /1.0/certificates — add certificate
	@Sendable
	func createCertificate(req: Request) async throws -> Response {
		let body = try req.content.decode(LXDCertificatesPost.self)

		guard body.name.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing certificate name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		// If token=true, return a synthetic 201 (token issuance not fully implemented)
		if body.token == true {
			return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata(), status: "Created", statusCode: 201)
				.encodeResponse(status: .created, for: req)
		}

		if let pem = body.certificate, pem.isEmpty == false {
			// Use the store's SHA-256 based helper so fingerprints are consistent with mTLS trust checks.
			let created = await LXDCertificateStore.shared.createFromPem(
				name: body.name,
				type: body.type,
				restricted: body.restricted,
				projects: body.projects ?? [],
				pem: pem
			)

			guard created != nil else {
				return try await LXDResponse<LXDEmptyMetadata>.error(message: "Certificate already exists", code: 409)
					.encodeResponse(status: .conflict, for: req)
			}
		} else {
			// No certificate provided (e.g. trust-token workflow stub).
			let fingerprint = UUID().uuidString.replacingOccurrences(of: "-", with: "")
			let created = await LXDCertificateStore.shared.create(
				name: body.name,
				type: body.type,
				restricted: body.restricted,
				projects: body.projects ?? [],
				certificate: "",
				fingerprint: fingerprint
			)

			guard created != nil else {
				return try await LXDResponse<LXDEmptyMetadata>.error(message: "Certificate already exists", code: 409)
					.encodeResponse(status: .conflict, for: req)
			}
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata(), status: "Created", statusCode: 201)
			.encodeResponse(status: .created, for: req)
	}

	// GET /1.0/certificates/:fingerprint
	@Sendable
	func getCertificate(req: Request) async throws -> Response {
		guard let fp = req.parameters.get("fingerprint") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing fingerprint", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let cert = await LXDCertificateStore.shared.get(fingerprint: fp) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Certificate '\(fp)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDCertificate>.sync(cert).encodeResponse(for: req)
	}

	// PUT /1.0/certificates/:fingerprint — full replace
	@Sendable
	func putCertificate(req: Request) async throws -> Response {
		guard let fp = req.parameters.get("fingerprint") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing fingerprint", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let body = try req.content.decode(LXDCertificatePut.self)

		let updated = await LXDCertificateStore.shared.put(
			fingerprint: fp,
			name: body.name ?? "",
			type: body.type ?? "client",
			restricted: body.restricted ?? false,
			projects: body.projects ?? [],
			certificate: body.certificate ?? ""
		)

		guard updated != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Certificate '\(fp)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// PATCH /1.0/certificates/:fingerprint — partial update
	@Sendable
	func patchCertificate(req: Request) async throws -> Response {
		guard let fp = req.parameters.get("fingerprint") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing fingerprint", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let body = try req.content.decode(LXDCertificatePut.self)

		let updated = await LXDCertificateStore.shared.patch(
			fingerprint: fp,
			name: body.name,
			type: body.type,
			restricted: body.restricted,
			projects: body.projects,
			certificate: body.certificate
		)

		guard updated != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Certificate '\(fp)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

	// DELETE /1.0/certificates/:fingerprint
	@Sendable
	func deleteCertificate(req: Request) async throws -> Response {
		guard let fp = req.parameters.get("fingerprint") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing fingerprint", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard await LXDCertificateStore.shared.delete(fingerprint: fp) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Certificate '\(fp)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}

}
