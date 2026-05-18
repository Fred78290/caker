//
//  LXDNetworksController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import CakedLib
import Foundation
import GRPCLib
import Vapor

/// Handles /1.0/networks routes
struct LXDNetworksController: RouteCollection {
	let group: EventLoopGroup
	let runMode: Utils.RunMode

	func boot(routes: any RoutesBuilder) throws {
		let networks = routes.grouped("1.0", "networks")
		networks.get(use: listNetworks)

		let named = networks.grouped(":name")
		named.get(use: getNetwork)
	}

	// GET /1.0/networks[?recursion=1]
	@Sendable
	func listNetworks(req: Request) async throws -> Response {
		let recursion = (req.query[Int.self, at: "recursion"] ?? 0) != 0
		let reply = CakedLib.NetworksHandler.networks(runMode: runMode)

		guard reply.success else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: reply.reason)
				.encodeResponse(status: .badRequest, for: req)
		}

		if recursion {
			return try await LXDResponse<[LXDNetwork]>.syncList(reply.networks).encodeResponse(for: req)
		}

		let urls = reply.networks.map { "/1.0/networks/\($0.name)" }

		return try await LXDResponse<LXDStringListMetadata>.syncList(urls).encodeResponse(for: req)
	}

	// GET /1.0/networks/:name
	@Sendable
	func getNetwork(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing network name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		let reply = CakedLib.NetworksHandler.networks(runMode: runMode)

		guard let network = reply.networks.first(where: { $0.name == name }) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Network '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		let lxdNetwork = LXDNetwork.from(name: name, network: network, referencedNetworks: LXDNetwork.referencedNetworks)
		return try await LXDResponse<LXDNetwork>.sync(lxdNetwork).encodeResponse(for: req)
	}
}
