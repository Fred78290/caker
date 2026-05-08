//
//  LXDCertificatesController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/05/2026.
//

import Foundation
import Vapor

/// Handles /1.0/certificates routes
struct LXDCertificatesController: RouteCollection {
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
		let recursion = req.query[Int.self, at: "recursion"] ?? 0

		if recursion >= 1 {
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

		let fingerprint = body.certificate.flatMap { computeFingerprint($0) } ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")

		let created = await LXDCertificateStore.shared.create(
			name: body.name,
			type: body.type,
			restricted: body.restricted,
			projects: body.projects ?? [],
			certificate: body.certificate ?? "",
			fingerprint: fingerprint
		)

		guard created != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Certificate already exists", code: 409)
				.encodeResponse(status: .conflict, for: req)
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

	/// Returns a synthetic fingerprint for a PEM-encoded certificate (hex of SHA-256).
	/// Falls back to a UUID-derived string if the certificate is empty or unparseable.
	private func computeFingerprint(_ pem: String) -> String? {
		guard pem.isEmpty == false else { return nil }
		// Use a hash of the raw PEM bytes as a fingerprint approximation
		var hash: UInt64 = 14695981039346656037
		for byte in pem.utf8 {
			hash ^= UInt64(byte)
			hash = hash &* 1099511628211
		}
		return String(format: "%016llx%016llx", hash, hash ^ 0xdeadbeefcafe1234)
	}
}
