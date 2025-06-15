//
//  Images.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/04/2025.
//

import Foundation
import TextTable

public typealias Aliases = [String]
public typealias ImageInfos = [ImageInfo]

extension Aliases {
	var description: String {
		if self.isEmpty {
			return ""
		} else if self.count == 1 {
			return self[0]
		} else {
			return self[0] + " (" + String(self.count - 1) + " more)"
		}
	}
}

public struct ImageEntry: Codable {
	public let name: String
}

public class LinuxContainerImage: Codable {
	public let alias: [String]?
	public let path: URL
	public let size: Int
	public let fingerprint: String
	public let remoteName: String
	public let description: String

	public init(from: Caked_PulledImageInfo) {
		self.alias = from.hasAlias ? from.alias.split(separator: ",").map { String($0) } : nil
		self.path = URL(fileURLWithPath: from.path)
		self.size = Int(from.size)
		self.fingerprint = from.fingerprint
		self.remoteName = from.remoteName
		self.description = from.description_p
	}

	public init(remoteName: String, fingerprint: String, alias: [String]?, description: String, path: URL, size: Int) {
		self.alias = alias
		self.path = path
		self.size = size
		self.fingerprint = fingerprint
		self.remoteName = remoteName
		self.description = description
	}

	public func toCaked_PulledImageInfo() -> Caked_PulledImageInfo {
		Caked_PulledImageInfo.with { image in
			image.alias = self.alias?.joined(separator: ",") ?? ""
			image.path = self.path.absoluteURL.path
			image.size = UInt64(self.size)
			image.fingerprint = self.fingerprint
			image.remoteName = self.remoteName
			image.description_p = self.description
		}
	}
}

public struct ImageInfo: Codable, Identifiable, Hashable {
	public typealias ID = String

	public let aliases: Aliases
	public let architecture: String
	public let pub: Bool
	public let fileName: String
	public let fingerprint: String
	public let size: Int
	public let type: String
	public let created: String?
	public let expires: String?
	public let uploaded: String?
	public let properties: [String: String]

	public var id: String {
		self.fingerprint
	}

	public init(from: Caked_ImageInfo) {
		self.aliases = from.aliases
		self.architecture = from.architecture
		self.pub = from.pub
		self.fileName = from.fileName
		self.fingerprint = from.fingerprint
		self.size = Int(from.size)
		self.type = from.type
		self.created = from.created
		self.expires = from.expires
		self.uploaded = from.uploaded
		self.properties = from.properties
	}

	public init(
		aliases: Aliases,
		architecture: String,
		pub: Bool,
		fileName: String,
		fingerprint: String,
		size: Int,
		type: String,
		created: String?,
		expires: String?,
		uploaded: String?,
		properties: [String: String]
	) {
		self.aliases = aliases
		self.architecture = architecture
		self.pub = pub
		self.fileName = fileName
		self.fingerprint = fingerprint
		self.size = size
		self.type = type
		self.created = created
		self.expires = expires
		self.uploaded = uploaded
		self.properties = properties
	}

	public func toCaked_ImageInfo() -> Caked_ImageInfo {
		Caked_ImageInfo.with { image in
			image.aliases = self.aliases
			image.architecture = self.architecture
			image.pub = self.pub
			image.fileName = self.fileName
			image.fingerprint = self.fingerprint
			image.size = UInt64(self.size)
			image.type = self.type
			image.properties = self.properties

			if let created = self.created {
				image.created = created
			}

			if let uploaded = self.uploaded {
				image.uploaded = uploaded
			}

			if let expires = self.expires {
				image.expires = expires
			}
		}
	}

	public func toText() -> String {
		var text = "Fingerprint: \(fingerprint)\n"

		text += "Size: \(Double(size) / 1024 / 1024)MiB\n"
		text += "Architecture: \(architecture)\n"
		text += "Type: \(type)\n"
		text += "Public: \(pub ? "yes" : "no")\n"
		text += "Timestamps:\n"
		text += "    Created: \(created ?? "")\n"
		text += "    Uploaded: \(uploaded ?? "")\n"
		text += "    Expires: \(expires ?? "")\n"
		text += "    Last used: never\n"
		text += "Properties:\n"
		for (key, value) in properties {
			text += "    \(key): \(value)\n"
		}
		text += "Aliases:\n"
		for alias in aliases {
			text += "    - \(alias)\n"
		}
		text += "Cached: no\n"
		text += "Auto update: disabled\n"
		text += "Profiles: []\n"

		return text
	}

	public enum CodingKeys: String, CodingKey {
		case aliases = "aliases"
		case architecture = "architecture"
		case pub = "public"
		case fileName = "filename"
		case fingerprint = "fingerprint"
		case size = "size"
		case type = "type"
		case created = "created_at"
		case expires = "expires_at"
		case uploaded = "uploaded_at"
		case properties = "properties"
	}
}

public struct ShortImageInfo: Codable {
	public let alias: String
	public let fingerprint: String
	public let pub: String
	public let description: String
	public let architecture: String
	public let type: String
	public let size: String
	public let uploaded: String

	public enum CodingKeys: String, CodingKey {
		case alias = "ALIAS"
		case fingerprint = "FINGERPRINT"
		case pub = "PUBLIC"
		case description = "DESCRIPTION"
		case architecture = "ARCHITECTURE"
		case type = "TYPE"
		case size = "SIZE"
		case uploaded = "UPLOADED"
	}

	public init(from: Caked_ImageInfo) {
		self.alias = from.aliases.description
		self.fingerprint = from.fingerprint.substring(..<12)
		self.pub = from.pub ? "yes" : "no"
		self.description = from.properties["description"] ?? ""
		self.architecture = from.architecture
		self.type = from.type
		self.size = ByteCountFormatter.string(fromByteCount: Int64(from.size), countStyle: .file)
		self.uploaded = from.uploaded
	}

	public init(imageInfo: ImageInfo) {
		self.alias = imageInfo.aliases.description
		self.fingerprint = imageInfo.fingerprint.substring(..<12)
		self.pub = imageInfo.pub ? "yes" : "no"
		self.description = imageInfo.properties["description"] ?? ""
		self.architecture = imageInfo.architecture
		self.type = imageInfo.type
		self.size = ByteCountFormatter.string(fromByteCount: Int64(imageInfo.size), countStyle: .file)
		self.uploaded = imageInfo.uploaded ?? ""
	}
}

public struct ShortLinuxContainerImage: Codable {
	public let alias: String
	public let fingerprint: String
	public let description: String
	public let size: String

	public enum CodingKeys: String, CodingKey {
		case alias = "ALIAS"
		case fingerprint = "FINGERPRINT"
		case description = "DESCRIPTION"
		case size = "SIZE"
	}

	public init(image: LinuxContainerImage) {
		self.alias = image.alias?.description ?? ""
		self.fingerprint = image.fingerprint.substring(..<12)
		self.description = image.description
		self.size = ByteCountFormatter.string(fromByteCount: Int64(image.size), countStyle: .file)
	}
}
