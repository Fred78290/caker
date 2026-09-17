//
//  TasksHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/09/2026.
//

import Foundation
import GRPCLib

/// Thin gRPC client wrapper around the `ListTasks`/`CancelTask` RPCs (see `CakedProvider.listTasks()`/
/// `cancelTask(id:)` in `caked`, and `CLAUDE.md`'s "`ListTasks`/`CancelTask` RPCs" section) — mirrors
/// `RemoteHandler.swift`'s calling convention. Unlike `RemoteHandler`, there is no local/`.app`-mode
/// fallback here: tasks only exist inside a running `caked` process's memory, the same reasoning
/// `cakectl tasks` itself has no local invocation path for. Callers are expected to only reach this
/// handler when `ConnectionManager.connectionMode != .app` (see `NavigationModel.categories`, which
/// hides the `.tasks` sidebar category in `.app` mode in the first place).
public struct TasksHandler {
	public enum TasksHandlerError: Error {
		case noClient
	}

	public static func listTasks(client: CakedServiceClient?) throws -> [Caked_Reply.TaskReply.TaskEntry] {
		guard let client else {
			throw TasksHandlerError.noClient
		}

		return try client.listTasks(Caked_Empty()).response.wait().tasks.list.tasks
	}

	public static func cancelTask(client: CakedServiceClient?, id: String) throws -> Caked_Reply.TaskReply.CancelTaskReply {
		guard let client else {
			throw TasksHandlerError.noClient
		}

		return try client.cancelTask(.with { $0.id = id }).response.wait().tasks.cancelled
	}
}
