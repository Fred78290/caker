//
//  LXDAuthGroupStore.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/05/2026.
//

import Foundation
import GRPCLib

// MARK: - LXD Auth Group Store

/// Thread-safe in-memory store for LXD authorization groups.
actor LXDAuthGroupStore {
	static let shared = LXDAuthGroupStore()

	private var groups: [String: LXDAuthGroup] = [:]
	private var storeURL: URL?

	// MARK: - Persistence

	/// Loads existing state from disk and stores the persistence URL for future saves.
	func configure(runMode: Utils.RunMode) throws {
		let url = try LXDStorePersistence.storeURL(name: "lxd-auth-groups", runMode: runMode)
		if let data = try? Data(contentsOf: url),
		   let loaded = try? JSONDecoder().decode([String: LXDAuthGroup].self, from: data) {
			self.groups = loaded
		}
		self.storeURL = url
	}

	private func save() {
		guard let url = storeURL,
			  let data = try? JSONEncoder().encode(groups) else { return }
		try? data.write(to: url, options: .atomic)
	}

	func create(name: String, description: String = "", permissions: [LXDAuthGroupPermission] = [], identities: LXDAuthGroupIdentities = LXDAuthGroupIdentities(oidc: [], tls: []), identityProviderGroups: [String] = []) -> LXDAuthGroup? {
		guard groups[name] == nil else { return nil }

		let group = LXDAuthGroup(
			name: name,
			description: description,
			permissions: permissions,
			identities: identities,
			identityProviderGroups: identityProviderGroups
		)

		groups[name] = group
		save()
		return group
	}

	func get(name: String) -> LXDAuthGroup? {
		groups[name]
	}

	func list() -> [LXDAuthGroup] {
		Array(groups.values).sorted { $0.name < $1.name }
	}

	func listURLs() -> [String] {
		groups.keys.sorted().map { "/1.0/auth/groups/\($0)" }
	}

	/// Full replace (PUT).
	func put(name: String, description: String, permissions: [LXDAuthGroupPermission], identities: LXDAuthGroupIdentities, identityProviderGroups: [String]) -> LXDAuthGroup? {
		guard groups[name] != nil else { return nil }

		let updated = LXDAuthGroup(
			name: name,
			description: description,
			permissions: permissions,
			identities: identities,
			identityProviderGroups: identityProviderGroups
		)

		groups[name] = updated
		save()
		return updated
	}

	/// Partial update (PATCH): only non-nil fields are overwritten.
	func patch(name: String, description: String?, permissions: [LXDAuthGroupPermission]?, identities: LXDAuthGroupIdentities?, identityProviderGroups: [String]?) -> LXDAuthGroup? {
		guard var group = groups[name] else { return nil }

		if let description { group.description = description }
		if let permissions { group.permissions = permissions }
		if let identities { group.identities = identities }
		if let identityProviderGroups { group.identityProviderGroups = identityProviderGroups }

		groups[name] = group
		save()
		return group
	}

	/// Rename a group (POST on /{groupName}).
	func rename(from oldName: String, to newName: String) -> Bool {
		guard var group = groups[oldName], groups[newName] == nil else { return false }

		groups.removeValue(forKey: oldName)
		group.name = newName
		groups[newName] = group
		save()
		return true
	}

	/// Delete a group.
	func delete(name: String) -> Bool {
		let removed = groups.removeValue(forKey: name) != nil
		if removed { save() }
		return removed
	}
}
