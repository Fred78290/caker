//
//  ComposeHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 27/09/2026.
//

import Foundation
import GRPCLib
import CakedLib
import Yams

/// Thin client-side wrapper around the `compose` RPC, mirroring `RemoteHandler.swift`'s dual
/// local/remote calling convention (`guard let client else { ... local CakedLib call ... }`) —
/// **not** `TasksHandler.swift`'s gRPC-only, no-local-fallback one.
///
/// This distinction matters: `CakedProvider.runningTasks` only exists inside a running `caked`
/// process's memory, so `TasksHandler` has no `.app`-mode story at all. Compose is architecturally
/// different — `ComposeFileDatabase`/`CakedLib.ComposeHandler`'s functions are plain functions that
/// take a `runMode:` directly and read/write `Home(runMode:).composeFileDatabase()` on disk, exactly
/// like `CakedLib.RemoteHandler.listRemote(runMode:)`/`Home(runMode:).remoteDatabase()` already do.
/// So Compose must keep working when `ConnectionManager.connectionMode == .app` (VMs embedded
/// in-process, no separate `caked`), unlike the Tasks sidebar category.
///
/// Named `ComposeHandler` to match this codebase's `<Foo>Handler.swift` convention — this collides
/// with the server-side `Sources/caked/Handlers/ComposeHandler.swift` and the plain-logic
/// `Sources/cakedlib/Handlers/ComposeHandler.swift`, but harmlessly: those live in the `caked`
/// module (never imported here) and the `CakedLib` module respectively, and this file only ever
/// extends the latter — exactly the same shape as `RemoteHandler.swift`'s `extension RemoteHandler`.
extension ComposeHandler {
	/// Lists every compose project currently registered with `caked` (or, in `.app` mode, this
	/// process's own `ComposeFileDatabase`).
	public static func list(client: CakedServiceClient?, runMode: Utils.RunMode) throws -> ComposeReplyList {
		guard let client else {
			let database = try Home(runMode: runMode).composeFileDatabase()

			return self.list(database: database, runMode: runMode)
		}

		return try ComposeReplyList(client.compose(.with { $0.ls = .init() }).response.wait().compose.ls)
	}

	/// Registers (if new) and starts/updates a compose project from an in-memory `ComposeFile` —
	/// the Compose Editor's "Save & Start" action, and the moral equivalent of `cakectl compose up`
	/// without requiring a file on disk.
	///
	/// `replaceDefinition` (local `.app` mode only) says whether `compose` also replaces an
	/// already-registered project's stored definition: `true` for a user-authored definition (the
	/// editor), `false` for the sidebar/menu-bar "Start" action, whose `compose` is only the lossy
	/// name-and-image reconstruction — see `statusForUp(database:compose:replaceDefinition:)`. Over gRPC
	/// the server decides on its own (`caked`'s `Up.run` currently keeps the stored definition).
	public static func up(client: CakedServiceClient?, compose: ComposeFile, services: [String] = [], waitIPTimeout: Int = 180, replaceDefinition: Bool = true, runMode: Utils.RunMode) async throws -> ComposeReplyUp {
		guard let client else {
			let database = try Home(runMode: runMode).composeFileDatabase()
			var status = self.statusForUp(database: database, compose: compose, replaceDefinition: replaceDefinition)

			let reply = await self.up(compose: &status, services: services, waitIPTimeout: waitIPTimeout, runMode: runMode)

			// Persist whatever was successfully launched, even on partial failure — same rule
			// `caked`'s own `ComposeHandler.Up.run` uses.
			if reply.success || status.installed.isEmpty == false {
				try database.upsert(compose.name, status)
			}

			return reply
		}

		let composeDatas = try Data(YAMLEncoder().encode(compose).utf8)

		return try await ComposeReplyUp(
			client.compose(.with {
				$0.up = .with {
					$0.composeDatas = composeDatas
					$0.waitIptimeout = Int32(waitIPTimeout)
					$0.services = services
				}
			}).response.get().compose.up)
	}

	/// Stops a registered project's services (all, or just `services`) in reverse `depends_on` order.
	public static func down(client: CakedServiceClient?, name: String, services: [String] = [], force: Bool = false, runMode: Utils.RunMode) throws -> ComposeReplyDown {
		guard let client else {
			let database = try Home(runMode: runMode).composeFileDatabase()

			guard let status = database.get(name) else {
				return ComposeReplyDown(name: name, success: false, reason: String(format: String(localized: "compose %@ not found"), name))
			}

			return self.down(compose: status, services: services, force: force, runMode: runMode)
		}

		return try ComposeReplyDown(
			client.compose(.with {
				$0.down = .with {
					$0.name = name
					$0.services = services
					$0.force = force
				}
			}).response.wait().compose.down)
	}

	/// Per-service status for one registered project — used to populate a detail pane.
	public static func ps(client: CakedServiceClient?, name: String, services: [String] = [], runMode: Utils.RunMode) throws -> ComposeReplyPs {
		guard let client else {
			let database = try Home(runMode: runMode).composeFileDatabase()

			guard let status = database.get(name) else {
				return ComposeReplyPs(name: name, services: [], success: false, reason: String(format: String(localized: "compose %@ not found"), name))
			}

			return self.ps(compose: status.composeFile, services: services, runMode: runMode)
		}

		return try ComposeReplyPs(
			client.compose(.with {
				$0.ps = .with {
					$0.name = name
					$0.services = services
				}
			}).response.wait().compose.ps)
	}

	/// Stops (if `stop`) and deletes a registered project's services, then unregisters it once
	/// nothing tracked remains installed.
	public static func rm(client: CakedServiceClient?, name: String, services: [String] = [], stop: Bool = false, force: Bool = false, runMode: Utils.RunMode) throws -> ComposeReplyDelete {
		guard let client else {
			let database = try Home(runMode: runMode).composeFileDatabase()

			guard var status = database.get(name) else {
				return ComposeReplyDelete(name: name, success: false, reason: String(format: String(localized: "compose %@ not found"), name))
			}

			let reply = self.rm(compose: &status, services: services, stop: stop, force: force, runMode: runMode)

			if status.installed.isEmpty {
				_ = try? database.remove(name)
			} else {
				try? database.upsert(name, status)
			}

			return reply
		}

		return try ComposeReplyDelete(
			client.compose(.with {
				$0.delete = .with {
					$0.name = name
					$0.services = services
					$0.force = force
					$0.stop = stop
				}
			}).response.wait().compose.delete)
	}
}
