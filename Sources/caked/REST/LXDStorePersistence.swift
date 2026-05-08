//
//  LXDStorePersistence.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/05/2026.
//

import Foundation
import GRPCLib

/// Helpers shared by all LXD*Store actors for JSON persistence.
enum LXDStorePersistence {
	/// Returns the URL for a given store's JSON file, creating the directory if needed.
	/// Files are stored under `<cakeHome>/rest-state/<name>.json`.
	static func storeURL(name: String, runMode: Utils.RunMode) throws -> URL {
		let home = try Utils.getHome(runMode: runMode)
		let dir = home.appendingPathComponent("rest-state", isDirectory: true)

		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

		return dir.appendingPathComponent("\(name).json", isDirectory: false).absoluteURL
	}
}
