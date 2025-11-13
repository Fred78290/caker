//
//  Templates.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//

import Foundation

public struct TemplateEntry: Codable, Identifiable, Hashable {
	public let name: String
	public let fqn: String
	public let diskSize: Int
	public let totalSize: Int

	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.fqn == rhs.fqn && lhs.diskSize == rhs.diskSize && lhs.totalSize == rhs.totalSize
	}

	public var id: String {
		return self.fqn
	}

	public init(name: String, fqn: String, diskSize: Int, totalSize: Int) {
		self.name = name
		self.fqn = fqn
		self.diskSize = diskSize
		self.totalSize = totalSize
	}

	public init(from: Caked_TemplateEntry) {
		self.name = from.name
		self.fqn = from.fqn
		self.diskSize = Int(from.diskSize)
		self.totalSize = Int(from.totalSize)
	}

	public var caked: Caked_TemplateEntry {
		Caked_TemplateEntry.with {
			$0.name = self.name
			$0.fqn = self.fqn
			$0.diskSize = UInt64(self.diskSize)
			$0.totalSize = UInt64(self.totalSize)
		}
	}
}

public struct ShortTemplateEntry: Codable {
	public let name: String
	public let fqn: String
	public let diskSize: String
	public let totalSize: String

	public init(from: Caked_TemplateEntry) {
		self.name = from.name
		self.fqn = from.fqn
		self.diskSize = ByteCountFormatter.string(fromByteCount: Int64(from.diskSize), countStyle: .file)
		self.totalSize = ByteCountFormatter.string(fromByteCount: Int64(from.totalSize), countStyle: .file)
	}

	public init(from: TemplateEntry) {
		self.name = from.name
		self.fqn = from.fqn
		self.diskSize = ByteCountFormatter.string(fromByteCount: Int64(from.diskSize), countStyle: .file)
		self.totalSize = ByteCountFormatter.string(fromByteCount: Int64(from.totalSize), countStyle: .file)
	}
}

public struct CreateTemplateReply: Codable, Hashable {
	public let name: String
	public let created: Bool
	public var reason: String? = nil

	public init(name: String, created: Bool, reason: String? = nil) {
		self.name = name
		self.created = created
		self.reason = reason
	}

	public init(from: Caked_CreateTemplateReply) {
		self.name = from.name
		self.created = from.created
		self.reason = from.reason
	}

	public var caked: Caked_CreateTemplateReply {
		Caked_CreateTemplateReply.with {
			$0.name = self.name
			$0.created = self.created

			if let reason = self.reason {
				$0.reason = reason
			}
		}
	}
}

public struct ListTemplateReply: Codable {
	public let templates: [TemplateEntry]
	public let success: Bool
	public let reason: String

	public var caked: Caked_ListTemplatesReply {
		Caked_ListTemplatesReply.with {
			$0.templates = self.templates.map(\.caked)
			$0.success = self.success
			$0.reason = self.reason
		}
	}

	public init(templates: [TemplateEntry], success: Bool, reason: String) {
		self.templates = templates
		self.success = success
		self.reason = reason
	}

	public init(from: Caked_ListTemplatesReply) {
		self.templates = from.templates.map(TemplateEntry.init(from:))
		self.success = from.success
		self.reason = from.reason
	}
}

public struct DeleteTemplateReply: Codable {
	public let name: String
	public let deleted: Bool
	public let reason: String

	public var caked: Caked_DeleteTemplateReply {
		Caked_DeleteTemplateReply.with {
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

	public init(from: Caked_DeleteTemplateReply) {
		self.name = from.name
		self.deleted = from.deleted
		self.reason = from.reason
	}
}
