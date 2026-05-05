//
//  LXDImagesController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import CakedLib
import Foundation
import GRPCLib
import Vapor

/// Handles /1.0/images routes (read-only: local templates and cached images)
struct LXDImagesController: RouteCollection {
	let runMode: Utils.RunMode

	func boot(routes: any RoutesBuilder) throws {
		let images = routes.grouped("1.0", "images")
		images.get(use: listImages)

		let named = images.grouped(":fingerprint")
		named.get(use: getImage)
	}

	// GET /1.0/images
	@Sendable
	func listImages(req: Request) async throws -> Response {
		let reply = CakedLib.ListHandler.list(vmonly: false, includeConfig: false, runMode: runMode)
		let urls = reply.infos
			.filter { $0.type != "vm" }
			.map { "/1.0/images/\($0.fingerprint ?? $0.instanceID ?? $0.name)" }
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// GET /1.0/images/:fingerprint
	@Sendable
	func getImage(req: Request) async throws -> Response {
		guard let fingerprint = req.parameters.get("fingerprint") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing image fingerprint", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let reply = CakedLib.ListHandler.list(vmonly: false, includeConfig: false, runMode: runMode)
		let candidates = reply.infos.filter { $0.type != "vm" }

		guard let info = candidates.first(where: {
			($0.fingerprint ?? $0.instanceID ?? $0.name) == fingerprint || $0.name == fingerprint
		}) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Image '\(fingerprint)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		let fp = info.fingerprint ?? info.instanceID ?? info.name
		let image = LXDImage(
			aliases: [LXDImageAlias(description: info.name, name: info.name)],
			architecture: info.config?.arch.description ?? Architecture.current().description,
			autoUpdate: false,
			cached: true,
			createdAt: ISO8601DateFormatter().string(from: Date()),
			expiresAt: "1970-01-01T00:00:00Z",
			filename: info.name,
			fingerprint: fp,
			lastUsedAt: ISO8601DateFormatter().string(from: Date()),
			public: false,
			size: Int(info.diskSize),
			type: "virtual-machine",
			uploadedAt: ISO8601DateFormatter().string(from: Date())
		)

		return try await LXDResponse<LXDImage>.sync(image).encodeResponse(for: req)
	}
}
