import Foundation
import GRPCLib
import NIOCore

struct ImageEntry: Codable {
	let name: String
}

struct ImageAlias: Codable {
	let name: String
	let description: String
}

struct ImageInfo: Codable {
	let aliases: [ImageAlias]
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

	init(product: SimpleStreamProduct) throws {
		guard let imageVersion = product.latest() else {
			throw ServiceError("image not found")
		}

		let imageDisk: ImageVersionItem = imageVersion.items.imageDisk!
		let serial: Dictionary<String, ImageVersion>.Keys.Element = product.versions.keys.first { key in
			if let version = product.versions[key] {
				if let disk = version.items.imageDisk {
					return disk.sha256 == imageDisk.sha256
				}
			}

			return false
		}!

		let aliases: [ImageAlias] = product.aliases.components(separatedBy: ",").map { alias in
			return ImageAlias(name: alias, description: "")
		}

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
			dateFormatter.dateFormat = "yyyyMMdd"
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

struct ImageHandler : CakedCommand {
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

		return try images.map { product in
			return try ImageInfo(product: product)
		}
	}

	static func info(name: String, asSystem: Bool) async throws -> ImageInfo {
		let split = name.components(separatedBy: ":")
		let remote = split.count > 1 ? split[0] : ""
		let imageAlias = split.count > 1 ? split[1] : split[0]
		let simpleStream: SimpleStreamProtocol = try await getSimpleStreamProtocol(remote: remote, asSystem: asSystem)
		let product = try await simpleStream.GetImage(alias: imageAlias)

		return try ImageInfo(product: product)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		return on.makeFutureWithTask {
			let format: Format = request.format == .text ? Format.text : Format.json

			switch request.command {
			case .info:
				return format.renderSingle(try await Self.info(name: request.name, asSystem: asSystem))
			case .list:
				return format.renderList(try await Self.listImage(remote: request.name, asSystem: runAsSystem))
			default:
				throw ServiceError("Unknown command \(request.command)")
			}
		}
	}
}