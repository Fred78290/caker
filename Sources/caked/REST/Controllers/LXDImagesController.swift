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

/// Handles /1.0/images routes.
/// Image data is pulled from all caches (TemplateImageCache, CloudImageCache,
/// IPSWCache, IsoCache, SimpleStreamsImageCache, OCIImageCache, …) via ListHandler.
struct LXDImagesController: RouteCollection {
	let runMode: Utils.RunMode

	func boot(routes: any RoutesBuilder) throws {
		let images = routes.grouped("1.0", "images")
		images.get(use: listImages)

		let named = images.grouped(":fingerprint")
		named.get(use: getImage)
	}

	// MARK: - Helpers

	/// Returns all cached images (excludes live VMs).
	private func allCachedImages() -> [VirtualMachineInfo] {
		CakedLib.ListHandler
			.list(vmonly: false, includeConfig: false, runMode: runMode)
			.infos
			.filter { $0.type != "vm" }
	}

	/// Map a cache `type()` string to the LXD image type field.
	private func lxdImageType(for cacheType: String) -> String {
		switch cacheType {
		case "OCIs", "simplestream": return "container"
		case "iso": return "iso"
		default: return "virtual-machine"
		}
	}

	/// Convert a `VirtualMachineInfo` (coming from an image cache) to `LXDImage`.
	private func toLXDImage(_ info: VirtualMachineInfo) -> LXDImage {
		let fp = info.fingerprint ?? info.instanceID ?? info.name
		let now = ISO8601DateFormatter().string(from: Date())
		let aliases = info.fqn.map { LXDImageAlias(description: info.name, name: $0) }

		return LXDImage(
			aliases: aliases,
			architecture: Architecture.current().description,
			autoUpdate: false,
			cached: true,
			createdAt: now,
			expiresAt: "1970-01-01T00:00:00Z",
			filename: info.name,
			fingerprint: fp,
			lastUsedAt: now,
			public: false,
			size: Int(info.diskSize),
			type: lxdImageType(for: info.type),
			uploadedAt: now
		)
	}

	// MARK: - Route handlers

	// GET /1.0/images[?recursion=1]
	@Sendable
	func listImages(req: Request) async throws -> Response {
		let recursion = req.query[Int.self, at: "recursion"] ?? 0
		let infos = allCachedImages()

		if recursion >= 1 {
			let images = infos.map { toLXDImage($0) }
			return try await LXDResponse<LXDImageListMetadata>.syncImages(images).encodeResponse(for: req)
		}

		let urls = infos.map { "/1.0/images/\($0.fingerprint ?? $0.instanceID ?? $0.name)" }
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// GET /1.0/images/:fingerprint
	@Sendable
	func getImage(req: Request) async throws -> Response {
		guard let fingerprint = req.parameters.get("fingerprint") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing image fingerprint", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let infos = allCachedImages()

		guard let info = infos.first(where: {
			let fp = $0.fingerprint ?? $0.instanceID ?? $0.name
			return fp == fingerprint || $0.name == fingerprint || $0.fqn.contains(fingerprint)
		}) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Image '\(fingerprint)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await LXDResponse<LXDImage>.sync(toLXDImage(info)).encodeResponse(for: req)
	}
}
