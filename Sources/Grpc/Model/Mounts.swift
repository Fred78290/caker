//
//  Mounts.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//

import Foundation
import TextTable

public struct MountVirtioFS: Codable {
	public var name: String = String.empty
	public var path: String = String.empty
	public var mounted: Bool = false
	public var reason: String = String.empty

	public init() {

	}

	public init(name: String, error: Error) {
		self.name = name
		self.mounted = false
		self.reason = error.reason
	}

	public init(mounted: Bool, name: String, reason: String) {
		self.name = name
		self.mounted = mounted
		self.reason = reason
	}

	public static func with(
		_ populator: (inout Self) throws -> Void
	) rethrows -> Self {
		var message = Self()
		try populator(&message)
		return message
	}

	public init(_ from: Caked_MountVirtioFSReply) {
		self.name = from.name
		self.path = from.path
		self.mounted = from.mounted
		self.reason = from.reason
	}

	public var caked: Caked_MountVirtioFSReply {
		Caked_MountVirtioFSReply.with {
			$0.name = self.name
			$0.path = self.path
			$0.reason = self.reason
			$0.mounted = self.mounted
		}
	}
}

public struct MountInfos: Codable {
	public var mounts: [MountVirtioFS]
	public var success: Bool
	public var reason: String

	internal init() {
		self.mounts = []
		self.success = false
		self.reason = String.empty
	}

	public init(success: Bool, reason: String, mounts: [MountVirtioFS]) {
		self.mounts = mounts
		self.success = success
		self.reason = reason
	}

	private static let decoder = JSONDecoder()

	public init(fromJSON: String) {
		guard let data = fromJSON.data(using: .utf8),
			  let decoded = try? MountInfos.decoder.decode(Self.self, from: data) else {
			self.init()
			return
		}
		self = decoded
	}

	public func withDirectorySharingAttachment(directorySharingAttachment: DirectorySharingAttachments) -> MountInfos {
		MountInfos.with {
			$0.mounts = self.mounts.map { mount in
				if let attachement = directorySharingAttachment.first(where: { attachement in attachement.name == mount.name }) {
					return MountVirtioFS.with {
						$0.name = mount.name
						$0.path = attachement.path.path
						$0.mounted = mount.mounted
						$0.reason = mount.reason
					}
				}

				return mount
			}
			$0.success = self.success
			$0.reason = self.reason
		}
	}

	public static func with(
		_ populator: (inout Self) throws -> Void
	) rethrows -> Self {
		var message = Self()
		try populator(&message)
		return message
	}

	private static let encoder: JSONEncoder = {
		let e = JSONEncoder()
		e.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
		return e
	}()

	public func toJSON() -> String {
		(try? MountInfos.encoder.encode(self).toString()) ?? "{}"
	}
}
