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

private struct LXDImagePullRequest: Content {
	let remote: String
	let alias: String
}

/// Handles /1.0/images routes.
/// Image data is pulled from all caches (TemplateImageCache, CloudImageCache,
/// IPSWCache, IsoCache, SimpleStreamsImageCache, OCIImageCache, …) via ListHandler.
struct LXDImagesController: RouteCollection {
	let group: EventLoopGroup
	let runMode: Utils.RunMode

	func boot(routes: any RoutesBuilder) throws {
		let images = routes.grouped("1.0", "images")
		images.get(use: listImages)
		images.get("remote", ":name", use: listRemoteImages)
		images.post("pull", use: pullImage)

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
		let created = ISO8601DateFormatter().string(from: info.created ?? Date())
		let lastUsedAt = ISO8601DateFormatter().string(from: info.lastUsed ?? Date())
		let aliases = info.fqn.map { LXDImageAlias(description: info.name, name: $0) }

		return LXDImage(
			aliases: aliases,
			architecture: Architecture.current().description,
			autoUpdate: false,
			cached: true,
			createdAt: created,
			expiresAt: "1970-01-01T00:00:00Z",
			filename: info.name,
			fingerprint: fp,
			lastUsedAt: lastUsedAt,
			public: false,
			size: Int(info.diskSize),
			type: lxdImageType(for: info.type),
			uploadedAt:  created
		)
	}

	/// Convert a `ImageInfo` (coming from a remote simplestream) to `LXDImage`.
	private func toLXDImage(_ info: ImageInfo, cached: Bool) -> LXDImage {
		let aliases = info.aliases.map { LXDImageAlias(description: info.fileName, name: $0) }
		let created = info.created ?? "1970-01-01T00:00:00Z"
		let uploaded = info.uploaded ?? created
		let expires = info.expires ?? "1970-01-01T00:00:00Z"

		return LXDImage(
			aliases: aliases,
			architecture: info.architecture,
			autoUpdate: false,
			cached: cached,
			createdAt: created,
			expiresAt: expires,
			filename: info.fileName,
			fingerprint: info.fingerprint,
			lastUsedAt: "1970-01-01T00:00:00Z",
			public: info.pub,
			size: Int(info.size),
			type: info.type,
			uploadedAt: uploaded
		)
	}

	// MARK: - Route handlers

	// GET /1.0/images[?recursion=1]
	@Sendable
	func listImages(req: Request) async throws -> Response {
		let recursion = (req.query[Int.self, at: "recursion"] ?? 0) != 0
		let infos = allCachedImages()

		if recursion {
			let images = infos.map { toLXDImage($0) }
			return try await LXDResponse<LXDImageListMetadata>.syncImages(images).encodeResponse(for: req)
		}

		let urls = infos.map { "/1.0/images/\($0.fingerprint ?? $0.instanceID ?? $0.name)" }
		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// GET /1.0/images/remote/:name
	@Sendable
	func listRemoteImages(req: Request) async throws -> Response {
		guard let remoteName = req.parameters.get("name"), remoteName.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing remote name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let result = await CakedLib.ImageHandler.listImage(remote: remoteName, runMode: runMode)

		guard result.success else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: result.reason, code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let images: [LXDImage]
		let remoteDb = try Home(runMode: runMode).remoteDatabase()

		if let remoteContainerServer = remoteDb.get(remoteName),
		   let remoteURL = URL(string: remoteContainerServer),
		   let hostname = remoteURL.host(percentEncoded: false),
		   let remoteCache = try? SimpleStreamsImageCache(name: hostname, runMode: runMode) {

			images = result.infos.map { info in
				let isCachedByFingerprint = remoteCache.getCache(fingerprint: info.fingerprint)?.kind == .image
				let isCachedByAlias = info.aliases.contains { alias in
					remoteCache.findCache(fingerprintOrAlias: alias)?.kind == .image
				}

				return toLXDImage(info, cached: isCachedByFingerprint || isCachedByAlias)
			}
		} else {
			images = result.infos.map { info in
				toLXDImage(info, cached: false)
			}
		}

		return try await LXDResponse<LXDImageListMetadata>.syncImages(images).encodeResponse(for: req)
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

	// POST /1.0/images/pull
	@Sendable
	func pullImage(req: Request) async throws -> Response {
		let body = try req.content.decode(LXDImagePullRequest.self)
		let remote = body.remote.trimmingCharacters(in: .whitespacesAndNewlines)
		let alias = body.alias.trimmingCharacters(in: .whitespacesAndNewlines)

		guard remote.isEmpty == false, alias.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing remote or alias", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let result = await CakedLib.ImageHandler.pull(name: "\(remote):\(alias)", runMode: runMode)

		guard result.success else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: result.reason, code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		return try await LXDResponse<LXDEmptyMetadata>.sync(LXDEmptyMetadata()).encodeResponse(for: req)
	}
}
