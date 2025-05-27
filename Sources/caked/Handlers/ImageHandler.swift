import Foundation
import GRPCLib
import NIOCore
import TextTable

extension ImageInfo {
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
		} else if serial.contains(".") {
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

		self.init(
			aliases: aliases, architecture: product.arch.rawValue, pub: true, fileName: imageDisk.path.components(separatedBy: "/").last!, fingerprint: imageDisk.sha256, size: imageDisk.size, type: "virtual-machine", created: created,
			expires: expires, uploaded: created, properties: properties)
	}
}

struct ImageHandler: CakedCommandAsync {
	var request: Caked_ImageRequest

	static func getSimpleStreamProtocol(remote: String, asSystem: Bool) async throws -> SimpleStreamProtocol {
		let remoteDb = try Home(asSystem: asSystem).remoteDatabase()

		guard let remoteContainerServer = remoteDb.get(remote) else {
			throw ServiceError("remote \(remote) not found")
		}

		guard let remoteContainerServerURL: URL = URL(string: remoteContainerServer) else {
			throw ServiceError("malformed url: \(remoteContainerServer)")
		}

		return try await SimpleStreamProtocol(baseURL: remoteContainerServerURL, asSystem: asSystem)
	}

	static func listImage(remote: String, asSystem: Bool) async throws -> [ImageInfo] {
		let simpleStream: SimpleStreamProtocol = try await getSimpleStreamProtocol(remote: remote, asSystem: asSystem)
		let images = try await simpleStream.GetImages(asSystem: asSystem)
		var result: [ImageInfo] = []

		images.forEach { product in
			if let image = product.latest() {
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
		let product = try await simpleStream.GetImage(alias: imageAlias, asSystem: asSystem)

		return try ImageInfo(product: product)
	}

	static func pull(name: String, asSystem: Bool) async throws -> LinuxContainerImage {
		let split = name.components(separatedBy: ":")
		let remote = split.count > 1 ? split[0] : ""
		let imageAlias = split.count > 1 ? split[1] : split[0]
		let simpleStream: SimpleStreamProtocol = try await getSimpleStreamProtocol(remote: remote, asSystem: asSystem)
		let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: imageAlias, asSystem: asSystem)

		try await image.pullSimpleStreamImageAndConvert(asSystem: asSystem)

		return image
	}

	static func execute(command: Caked_ImageCommand, name: String, asSystem: Bool) async throws -> Caked_Reply {
		switch command {
		case .info:
			let result = try await ImageHandler.info(name: name, asSystem: asSystem)

			return Caked_Reply.with {
				$0.images = Caked_ImageReply.with {
					$0.infos = result.toCaked_ImageInfo()
				}
			}

		case .pull:
			let result = try await ImageHandler.pull(name: name, asSystem: asSystem)

			return Caked_Reply.with {
				$0.images = Caked_ImageReply.with {
					$0.pull = result.toCaked_PulledImageInfo()
				}
			}
		case .list:
			let result = try await ImageHandler.listImage(remote: name, asSystem: asSystem)

			return Caked_Reply.with {
				$0.images = Caked_ImageReply.with {
					$0.list = Caked_ListImagesInfoReply.with {
						$0.infos = result.map {
							$0.toCaked_ImageInfo()
						}
					}
				}
			}
		default:
			throw ServiceError("Unknown command \(command)")
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			try await Self.execute(command: request.command, name: request.name, asSystem: asSystem)
		}
	}
}
