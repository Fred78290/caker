//
//  RemoteEntry.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//

public struct RemoteEntry: Identifiable, Equatable, Hashable, Codable {
	public let name: String
	public let url: String

	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.url == rhs.url && lhs.name == rhs.name
	}

	public var id: String {
		self.url
	}

	public init(name: String, url: String) {
		self.name = name
		self.url = url
	}

	public init(from: Caked_RemoteEntry) {
		self.name = from.name
		self.url = from.url
	}

	public var caked: Caked_RemoteEntry {
		Caked_RemoteEntry.with {
			$0.name = name
			$0.url = url
		}
	}
}

public struct CreateRemoteReply: Codable {
	public let name: String
	public let created: Bool
	public let reason: String

	public var caked: Caked_CreateRemoteReply {
		Caked_CreateRemoteReply.with {
			$0.name = self.name
			$0.created = self.created
			$0.reason = self.reason
		}
	}

	public init(name: String, created: Bool, reason: String) {
		self.name = name
		self.created = created
		self.reason = reason
	}

	public init(from: Caked_CreateRemoteReply) {
		self.name = from.name
		self.created = from.created
		self.reason = from.reason
	}
}

public struct DeleteRemoteReply: Codable {
	public let name: String
	public let deleted: Bool
	public let reason: String

	public var caked: Caked_DeleteRemoteReply {
		Caked_DeleteRemoteReply.with {
			$0.name = self.name
			$0.deleted = self.deleted
			$0.reason = self.reason
		}
	}

	public init(name: String, deleted: Bool, reason: String) {
		self.name = name
		self.deleted = deleted
		self.reason = reason
	}

	public init(from: Caked_DeleteRemoteReply) {
		self.name = from.name
		self.deleted = from.deleted
		self.reason = from.reason
	}
}

public struct ListRemoteReply: Codable {
	public let remotes: [RemoteEntry]
	public let success: Bool
	public let reason: String

	public var caked: Caked_ListRemoteReply {
		Caked_ListRemoteReply.with {
			$0.success = self.success
			$0.reason = self.reason
			$0.remotes = self.remotes.map(\.caked)
		}
	}

	public init(remotes: [RemoteEntry], success: Bool, reason: String) {
		self.remotes = remotes
		self.success = success
		self.reason = reason
	}

	public init(from: Caked_ListRemoteReply) {
		self.remotes = from.remotes.map { .init(from: $0) }
		self.success = from.success
		self.reason = from.reason
	}
}
