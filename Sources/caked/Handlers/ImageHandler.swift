import Foundation
import GRPCLib
import NIOCore
import TextTable

typealias Aliases = [String]

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

struct ImageEntry: Codable {
	let name: String
}

struct ImageInfo: Codable {
	let aliases: Aliases
	let architecture: String
	let pub: Bool
	let fileName: String
	let fingerprint: String
	let size: UInt
	let type: String
	let created: String?
	let expires: String?
	let uploaded: String?
	let properties: [String: String]

	func toText() -> String {
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

	init(product: SimpleStreamProduct) throws {
		guard let imageVersion = product.latest() else {
			throw ServiceError("image doesn't offer qcow2 image")
		}

		self.init(product: product, imageVersion: imageVersion.1)
	}

	init(product: SimpleStreamProduct, imageVersion: ImageVersion) {
		let imageDisk: ImageVersionItem = imageVersion.items.imageDisk!
		let serial: Dictionary<String, ImageVersion>.Keys.Element = product.versions.keys.first { key in
			if let version = product.versions[key] {
				if let disk = version.items.imageDisk {
					return disk.sha256 == imageDisk.sha256
				}
			}

			return false
		}!

		let aliases = product.aliases.components(separatedBy: ",")
		let dateFormatter = DateFormatter()

		dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

		if serial.contains("_") {
			dateFormatter.dateFormat = "yyyyMMdd'_'HH:mm"
		} else if serial.contains("."){
			dateFormatter.dateFormat = "yyyyMMdd'.'"
		} else {
			dateFormatter.dateFormat = "yyyyMMdd"
		}

		var created: String? = nil
		var expires: String? = nil

		if let dd = dateFormatter.date(from: serial) {
			created = dd.toFormat(String(format: "yyyy-MM-dd'T'HH:mm:ss'Z'"))
		}

		if let supportedEOL = product.supportedEOL {
			dateFormatter.dateFormat = "yyyy-MM-dd"
			if let dd = dateFormatter.date(from: supportedEOL) {
				expires = dd.toFormat(String(format: "yyyy-MM-dd'T'HH:mm:ss'Z'"))
			}
		}

		var properties: [String: String] = [
			"architecture": product.arch.description,
			"description": "\(product.os) \(product.releaseTitle) \(product.arch) (\(product.release)) \(serial)",
			"os": product.os,
			"release": product.release,
			"serial": serial,
		]

		if let label = imageVersion.label {
			properties["label"] = label
		}

		if let version = product.version {
			properties["version"] = version
		}

		self.aliases = aliases
		self.architecture = product.arch.rawValue
		self.pub = true
		self.fileName = imageDisk.path.components(separatedBy: "/").last!
		self.fingerprint = imageDisk.sha256
		self.size = UInt(imageDisk.size)
		self.type = "virtual-machine"
		self.created = created
		self.expires = expires
		self.uploaded = created
		self.properties = properties
	}

	enum CodingKeys: String, CodingKey {
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

struct ShortImageInfo: Codable {
	let alias: String
	let fingerprint: String
	let pub: String
	let description: String
	let architecture: String
	let type: String
	let size: String
	let uploaded: String

	enum CodingKeys: String, CodingKey {
		case alias = "ALIAS"
		case fingerprint = "FINGERPRINT"
		case pub = "PUBLIC"
		case description = "DESCRIPTION"
		case architecture = "ARCHITECTURE"
		case type = "TYPE"
		case size = "SIZE"
		case uploaded = "UPLOADED"
	}

	init(imageInfo: ImageInfo) {
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

struct ShortLinuxContainerImage: Codable {
	let alias: String
	let fingerprint: String
	let description: String
	let size: String

	enum CodingKeys: String, CodingKey {
		case alias = "ALIAS"
		case fingerprint = "FINGERPRINT"
		case description = "DESCRIPTION"
		case size = "SIZE"
	}

	init(image: LinuxContainerImage) {
		self.alias = image.alias?.description ?? ""
		self.fingerprint = image.fingerprint.substring(..<12)
		self.description = image.description
		self.size = ByteCountFormatter.string(fromByteCount: Int64(image.size), countStyle: .file)
	}
}

struct ImageHandler : CakedCommandAsync {
	var request: Caked_ImageRequest

	static func getSimpleStreamProtocol(remote: String, asSystem: Bool) async throws -> SimpleStreamProtocol {
		let remoteDb = try Home(asSystem: runAsSystem).remoteDatabase()

		guard let remoteContainerServer = remoteDb.get(remote) else {
			throw ServiceError("remote \(remote) not found")
		}

		guard let remoteContainerServerURL: URL = URL(string: remoteContainerServer) else {
			throw ServiceError("malformed url: \(remoteContainerServer)")
		}

		return try await SimpleStreamProtocol(baseURL: remoteContainerServerURL)
	}

	static func listImage(remote: String, asSystem: Bool) async throws -> [ImageInfo] {
		let simpleStream: SimpleStreamProtocol = try await getSimpleStreamProtocol(remote: remote, asSystem: asSystem)
		let images = try await simpleStream.GetImages()
		var result: [ImageInfo] = []

		images.forEach { product in
			if let image = product.latest()  {
				result.append(ImageInfo(product: product, imageVersion: image.1))
			}
		}

		return result
	}

	static func info(name: String, asSystem: Bool) async throws -> ImageInfo {
		let split = name.components(separatedBy: ":")
		let remote = split.count > 1 ? split[0] : ""
		let imageAlias = split.count > 1 ? split[1] : split[0]
		let simpleStream: SimpleStreamProtocol = try await getSimpleStreamProtocol(remote: remote, asSystem: asSystem)
		let product = try await simpleStream.GetImage(alias: imageAlias)

		return try ImageInfo(product: product)
	}

	static func pull(name: String, asSystem: Bool) async throws -> LinuxContainerImage {
		let split = name.components(separatedBy: ":")
		let remote = split.count > 1 ? split[0] : ""
		let imageAlias = split.count > 1 ? split[1] : split[0]
		let simpleStream: SimpleStreamProtocol = try await getSimpleStreamProtocol(remote: remote, asSystem: asSystem)
		let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: imageAlias)

		try await image.pullSimpleStreamImageAndConvert()

		return image
	}


	static func execute(command: Caked_RemoteCommand, name: String, format: Format, asSystem: Bool) async throws -> String {
		switch command {
		case .info:
			let result = try await ImageHandler.info(name: name, asSystem: false)

			if format == .json {
				return format.renderSingle(result)
			} else {
				return result.toText()
			}
		case .pull:
			let result = try await ImageHandler.pull(name: name, asSystem: asSystem)
			if format == .json {
				return format.renderSingle(style: Style.grid, uppercased: true, result)
			} else {
				return format.renderSingle(style: Style.grid, uppercased: true, ShortLinuxContainerImage(image: result))
			}
		case .list:
			let result: [ImageInfo] = try await ImageHandler.listImage(remote: name, asSystem: asSystem)
			if format == .json {
				return format.renderList(style: Style.grid, uppercased: true, result)
			} else {
				return format.renderList(style: Style.grid, uppercased: true, result.map{ ShortImageInfo(imageInfo: $0)})
			}
		default:
			throw ServiceError("Unknown command \(command)")
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		return on.makeFutureWithTask {
			try await Self.execute(command: request.command, name: request.name, format: request.format == .text ? Format.text : Format.json, asSystem: asSystem)
		}
	}
}