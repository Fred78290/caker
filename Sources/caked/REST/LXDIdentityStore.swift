//
//  LXDIdentityStore.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/05/2026.
//

import Foundation
import GRPCLib

// MARK: - LXD Identity Store

/// Thread-safe in-memory store for LXD identities, keyed by "authMethod:identifier".
actor LXDIdentityStore {
	static let shared = LXDIdentityStore()

	/// Composite key: "\(authenticationMethod):\(id)"
	private var identities: [String: LXDIdentity] = [:]
	private var storeURL: URL?

	// MARK: - Persistence

	/// Loads existing state from disk and stores the persistence URL for future saves.
	func configure(runMode: Utils.RunMode) throws {
		let url = try LXDStorePersistence.storeURL(name: "lxd-identities", runMode: runMode)
		if let data = try? Data(contentsOf: url),
		   let loaded = try? JSONDecoder().decode([String: LXDIdentity].self, from: data) {
			self.identities = loaded
		}
		self.storeURL = url
	}

	private func save() {
		guard let url = storeURL,
			  let data = try? JSONEncoder().encode(identities) else { return }
		try? data.write(to: url, options: .atomic)
	}

	private func key(authMethod: String, identifier: String) -> String {
		"\(authMethod):\(identifier)"
	}

	func create(authenticationMethod: String, type: String, id: String, name: String, groups: [String] = [], tlsCertificate: String = "") -> LXDIdentity? {
		let k = key(authMethod: authenticationMethod, identifier: id)
		guard identities[k] == nil else { return nil }

		let identity = LXDIdentity(
			authenticationMethod: authenticationMethod,
			type: type,
			id: id,
			name: name,
			groups: groups,
			tlsCertificate: tlsCertificate
		)

		identities[k] = identity
		save()
		return identity
	}

	func get(authMethod: String, nameOrID: String) -> LXDIdentity? {
		let k = key(authMethod: authMethod, identifier: nameOrID)
		if let found = identities[k] { return found }
		// fall back to name search
		return identities.values.first { $0.authenticationMethod == authMethod && $0.name == nameOrID }
	}

	func list() -> [LXDIdentity] {
		Array(identities.values).sorted { $0.id < $1.id }
	}

	func listURLs() -> [String] {
		identities.values
			.sorted { $0.id < $1.id }
			.map { "/1.0/auth/identities/\($0.authenticationMethod)/\($0.id)" }
	}

	func listByAuthMethod(_ authMethod: String) -> [LXDIdentity] {
		identities.values
			.filter { $0.authenticationMethod == authMethod }
			.sorted { $0.id < $1.id }
	}

	func listURLsByAuthMethod(_ authMethod: String) -> [String] {
		identities.values
			.filter { $0.authenticationMethod == authMethod }
			.sorted { $0.id < $1.id }
			.map { "/1.0/auth/identities/\(authMethod)/\($0.id)" }
	}

	/// Full replace (PUT).
	func put(authMethod: String, nameOrID: String, groups: [String], tlsCertificate: String) -> LXDIdentity? {
		guard var identity = get(authMethod: authMethod, nameOrID: nameOrID) else { return nil }

		identity.groups = groups
		identity.tlsCertificate = tlsCertificate
		identities[key(authMethod: authMethod, identifier: identity.id)] = identity
		save()
		return identity
	}

	/// Partial update (PATCH).
	func patch(authMethod: String, nameOrID: String, groups: [String]?, tlsCertificate: String?) -> LXDIdentity? {
		guard var identity = get(authMethod: authMethod, nameOrID: nameOrID) else { return nil }

		if let groups { identity.groups = groups }
		if let tlsCertificate { identity.tlsCertificate = tlsCertificate }
		identities[key(authMethod: authMethod, identifier: identity.id)] = identity
		save()
		return identity
	}

	func delete(authMethod: String, nameOrID: String) -> Bool {
		guard let identity = get(authMethod: authMethod, nameOrID: nameOrID) else { return false }
		identities.removeValue(forKey: key(authMethod: authMethod, identifier: identity.id))
		save()
		return true
	}
}
