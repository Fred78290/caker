//
//  LXDVMImagesController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/10/2026.
//

import CakedLib
import Foundation
import GRPCLib
import Vapor

private struct LXDVMImageEntry: Content {
	let id: String
	let label: String
	let url: String
	let minCPU: UInt16
	let minMemoryMiB: UInt64

	init(_ entry: VMImageEntry) {
		self.id = entry.id
		self.label = entry.label
		self.url = entry.url
		self.minCPU = entry.minCPU
		self.minMemoryMiB = entry.minMemoryMiB
	}
}

/// Same shape as one architecture node of `VMImages.json` (and the web UI's `VMImageCatalog` type).
/// `ipsw` is always present, empty on an x86_64 caked, which can't build macOS guests.
private struct LXDVMImageCatalog: Content {
	let iso: [LXDVMImageEntry]
	let ipsw: [LXDVMImageEntry]
	let cloud: [LXDVMImageEntry]
}

/// Handles GET /1.0/vm-images, a Caker extension (like /1.0/remotes), not part of the LXD API: the VM
/// image catalog of this caked's host, so the web UI's create dialog offers what this caked builds
/// rather than the copy bundled into the web UI when it was built. Same data as the gRPC `Aliases`
/// RPC, including a `<CAKE_HOME>/VMImages.json` override re-read when it changes.
struct LXDVMImagesController: RouteCollection {
	func boot(routes: any RoutesBuilder) throws {
		routes.get("1.0", "vm-images", use: getCatalog)
	}

	@Sendable
	func getCatalog(req: Request) async throws -> Response {
		let catalog = VMImageCatalog.reloadIfChanged().current

		#if arch(arm64)
			let ipsw = catalog.ipsw
		#else
			let ipsw: [VMImageEntry] = []
		#endif

		let metadata = LXDVMImageCatalog(
			iso: catalog.iso.map(LXDVMImageEntry.init),
			ipsw: ipsw.map(LXDVMImageEntry.init),
			cloud: catalog.cloud.map(LXDVMImageEntry.init))

		return try await LXDResponse<LXDVMImageCatalog>.sync(metadata).encodeResponse(for: req)
	}
}
