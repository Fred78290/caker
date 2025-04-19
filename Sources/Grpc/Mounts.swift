//
//  Mounts.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//

import Foundation
import TextTable

public struct MountVirtioFS: Codable {
	public var name: String = ""
	public var path: String = ""
	public var response: OneOf_Response? = nil

	enum CodingKeys: String, CodingKey {
		case name = "name"
		case path = "path"
		case response = "response"
	}

	public enum OneOf_Response: Equatable, Codable {
		case error(String)
		case success(Bool)
	}

	public init() {

	}

	public init(name: String, error: Error) {
		self.name = name
		self.response = .error(String(describing: error))
	}

	public static func with(
		_ populator: (inout Self) throws -> Void
	) rethrows -> Self {
		var message = Self()
		try populator(&message)
		return message
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(self.name, forKey: .name)
		try container.encode(self.path, forKey: .path)
		try container.encode(self.response, forKey: .response)
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.name = try container.decode(String.self, forKey: .name)
		self.path = try container.decode(String.self, forKey: .path)
		self.response = try container.decode(OneOf_Response.self, forKey: .response)
	}

	public init(from: Caked_MountVirtioFSReply) {
		self.name = from.name
		self.path = from.path

		if case .success(true) = from.response {
			self.response = .success(true)
		} else {
			self.response = .error(from.error)
		}
	}

	public func toCaked_MountVirtioFSReply() -> Caked_MountVirtioFSReply {
		Caked_MountVirtioFSReply.with {
			$0.name = self.name
			$0.path = self.path

			if case .success(true) = self.response {
				$0.success = true
			} else if case .error(let error) = self.response {
				$0.error = error
			}
		}
	}
}

public struct MountInfos: Codable {
	public var mounts: [MountVirtioFS] = []
	public var response: OneOf_Response? = .success(true)

	public init() {
	}

	public enum CodingKeys: String, CodingKey {
		case mounts = "mounts"
		case response = "response"
	}

	public enum OneOf_Response: Codable, Equatable, Sendable {
		case error(String)
		case success(Bool)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(self.mounts, forKey: .mounts)
		try container.encode(self.response, forKey: .response)
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.mounts = try container.decode([MountVirtioFS].self, forKey: .mounts)
		self.response = try container.decode(OneOf_Response.self, forKey: .response)
	}

	public init(fromJSON: String) {
		let decoder = JSONDecoder()

		self = try! decoder.decode(Self.self, from: fromJSON.data(using: .utf8)!)
	}

	public func withDirectorySharingAttachment(directorySharingAttachment: [DirectorySharingAttachment]) -> MountInfos {
		MountInfos.with {
			$0.mounts = self.mounts.map { mount in
				if let attachement = directorySharingAttachment.first(where: { attachement in attachement.name == mount.name}) {
					return MountVirtioFS.with {
						$0.name = mount.name
						$0.path = attachement.path.path

						if case .error(let reason) = mount.response! {
							$0.response = .error(reason)
						} else {
							$0.response = .success(true)
						}
					}
				}

				return mount
			}

			if case .error(let reason) = self.response! {
				$0.response = .error(reason)
			} else {
				$0.response = .success(true)
			}
		}
	}

	public static func with(
		_ populator: (inout Self) throws -> Void
	) rethrows -> Self {
		var message = Self()
		try populator(&message)
		return message
	}

	public func toJSON() -> String {
		let encoder = JSONEncoder()

		encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]

		return try! encoder.encode(self).toString()
	}
}
