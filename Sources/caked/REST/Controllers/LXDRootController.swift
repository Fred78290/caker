//
//  LXDOperationsController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import CakedLib
import Foundation
import GRPCLib
import Vapor

/// Handles GET /1.0
struct LXDRootController: RouteCollection {
	let group: EventLoopGroup
	let runMode: Utils.RunMode

	func boot(routes: any RoutesBuilder) throws {
		routes.get("1.0", use: serverInfo)
	}

	@Sendable
	func serverInfo(req: Request) async throws -> Response {
		let version = CI.version

		let info = LXDServerInfo(
			apiExtensions: [
				"instances",
				"instance_state_action",
				"networks",
				"images",
				"operations",
				"auth_groups",
				"auth_identities",
				"certificate",
			],
			apiStatus: "stable",
			apiVersion: "1.0",
			auth: "trusted",
			config: [:],
			environment: LXDEnvironment(
				architectures: ["aarch64", "x86_64"],
				certificate: "",
				certificateFingerprint: "",
				driver: "apple-virtualization",
				driverVersion: version,
				firewall: "none",
				kernel: "Darwin",
				kernelArchitecture: Architecture.current().description,
				kernelVersion: ProcessInfo.processInfo.operatingSystemVersionString,
				ovmfPath: "",
				server: "caked",
				serverName: Host.current().localizedName ?? "caked",
				serverVersion: version,
				storage: "local",
				storageVersion: "1.0"
			),
			public: false
		)

		let response = LXDResponse<LXDServerInfo>.sync(info)
		return try await response.encodeResponse(for: req)
	}
}
