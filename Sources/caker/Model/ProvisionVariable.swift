//
//  ProvisionVariable.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/09/2026.
//
import Foundation
import GRPCLib

typealias ProvisionVariables = [ProvisionVariable]

/// A single `${var.<key>}` substitution the wizard offers to inject into the provisioning
/// template alongside the built-in `${var.username}`/`${var.password}` — see `BuildOptions.provisionVars`
/// (`--var key=value` on the CLI) and `PackerLiteTemplate`'s `${var.*}` resolution.
struct ProvisionVariable: Identifiable, Hashable, Codable, Validatable {
	let id: UUID
	var key: String
	var value: String

	init(key: String = String.empty, value: String = String.empty) {
		self.id = UUID()
		self.key = key
		self.value = value
	}

	func validate() -> Bool {
		self.key.trimmingCharacters(in: .whitespaces).isEmpty == false
	}
}

extension ProvisionVariables {
	func editItem(_ editItem: ProvisionVariable.ID?) -> ProvisionVariable {
		if let editItem {
			return self.first(where: { $0.id == editItem }) ?? .init()
		} else {
			return .init()
		}
	}

	/// `key=value` strings in the shape `BuildOptions.provisionVars` expects, dropping any entry
	/// with a blank (whitespace-only) key rather than sending a malformed `--var` entry.
	var asProvisionVarStrings: [String] {
		self.compactMap { entry in
			let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)

			guard key.isEmpty == false,
				key.contains("=") == false,
				key.contains(String.grpcSeparator) == false,
				entry.value.contains(String.grpcSeparator) == false
			else {
				return nil
			}

			return "\(key)=\(entry.value)"
		}
	}
}

/// Persists the wizard's provisioning variables to `<CAKE_HOME>/ProvisionVariables.json`, so the
/// last-used set is restored automatically the next time the wizard is opened, instead of always
/// starting empty — mirrors `VMImageCatalog`'s own `<CAKE_HOME>/VMImages.json` load/save pattern
/// (`Sources/cakedlib/VMImageCatalog.swift`), including its "best-effort, never crash the app over
/// user-supplied/cached state" posture: a missing or malformed file just falls back to `[]`, and a
/// failed save is silently dropped rather than surfaced to the user.
enum ProvisionVariablesStore {
	private static let filename = "ProvisionVariables.json"

	private static func cakeHomeURL(createHomeIfNeeded: Bool) -> URL? {
		guard let home = try? Utils.getHome(runMode: .app, createItIfNotExists: createHomeIfNeeded) else {
			return nil
		}

		return home.appendingPathComponent(filename, isDirectory: false)
	}

	static func load() -> ProvisionVariables {
		guard let url = cakeHomeURL(createHomeIfNeeded: false), FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
			return []
		}

		return (try? JSONDecoder().decode(ProvisionVariables.self, from: Data(contentsOf: url))) ?? []
	}

	static func save(_ variables: ProvisionVariables) {
		guard let url = cakeHomeURL(createHomeIfNeeded: true) else {
			return
		}

		try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try? JSONEncoder().encode(variables).write(to: url, options: .atomic)
	}
}
