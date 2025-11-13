import Foundation
import GRPCLib
import NIOCore
import TextTable

extension ImageInfo {
	public init(product: SimpleStreamProduct) throws {
		guard let imageVersion = product.latest() else {
			throw ServiceError("image doesn't offer qcow2 image")
		}

		self.init(product: product, imageVersion: imageVersion.1)
	}

	public init(product: SimpleStreamProduct, imageVersion: ImageVersion) {
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

public struct ImageHandler {
	public static func getSimpleStreamProtocol(remote: String, runMode: Utils.RunMode) async throws -> SimpleStreamProtocol {
		let remoteDb = try Home(runMode: runMode).remoteDatabase()

		guard let remoteContainerServer = remoteDb.get(remote) else {
			throw ServiceError("remote \(remote) not found")
		}

		guard let remoteContainerServerURL: URL = URL(string: remoteContainerServer) else {
			throw ServiceError("malformed url: \(remoteContainerServer)")
		}

		return try await SimpleStreamProtocol(baseURL: remoteContainerServerURL, runMode: runMode)
	}

	public static func listImage(remote: String, runMode: Utils.RunMode) async -> ListImagesInfoReply {
		do {
			let simpleStream: SimpleStreamProtocol = try await getSimpleStreamProtocol(remote: remote, runMode: runMode)
			let images = try await simpleStream.GetImages(runMode: runMode)
			var result: [ImageInfo] = []
			
			images.forEach { product in
				if let image = product.latest() {
					result.append(ImageInfo(product: product, imageVersion: image.1))
				}
			}
			
			return ListImagesInfoReply(infos: result, success: true, reason: "Success")
		} catch {
			return ListImagesInfoReply(infos: [], success: false, reason: "\(error)")
		}
	}

	public static func info(name: String, runMode: Utils.RunMode) async -> ImageInfoReply {
		do {
			let split = name.components(separatedBy: ":")
			let remote = split.count > 1 ? split[0] : ""
			let imageAlias = split.count > 1 ? split[1] : split[0]
			let simpleStream: SimpleStreamProtocol = try await getSimpleStreamProtocol(remote: remote, runMode: runMode)
			let product = try await simpleStream.GetImage(alias: imageAlias, runMode: runMode)
			
			return ImageInfoReply(info: try ImageInfo(product: product), success: true, reason: "Success")
		} catch {
			return ImageInfoReply(info: .init(), success: false, reason: "\(error)")
		}
	}

	public static func pull(name: String, runMode: Utils.RunMode) async -> PulledImageInfoReply {
		do {
			let split = name.components(separatedBy: ":")
			let remote = split.count > 1 ? split[0] : ""
			let imageAlias = split.count > 1 ? split[1] : split[0]
			let simpleStream: SimpleStreamProtocol = try await getSimpleStreamProtocol(remote: remote, runMode: runMode)
			let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: imageAlias, runMode: runMode)
			
			try await image.pullSimpleStreamImageAndConvert(runMode: runMode, progressHandler: ProgressObserver.progressHandler)
			
			return PulledImageInfoReply(info: image, success: true, reason: "Success")
		} catch {
			return PulledImageInfoReply(info: LinuxContainerImage(), success: false, reason: "\(error)")
		}
	}

	static func execute(command: Caked_ImageCommand, name: String, runMode: Utils.RunMode) async throws -> Caked_Reply {
		let reply: Caked_ImageReply

		switch command {
		case .info:
			let result = await ImageHandler.info(name: name, runMode: runMode)

			reply = Caked_ImageReply.with {
				$0.infos = result.caked
			}

		case .pull:
			let result = await ImageHandler.pull(name: name, runMode: runMode)

			reply = Caked_ImageReply.with {
				$0.pull = result.caked
			}
		case .list:
			let result = await ImageHandler.listImage(remote: name, runMode: runMode)

			reply = Caked_ImageReply.with {
				$0.list = result.caked
			}
		default:
			throw ServiceError("Unknown command \(command)")
		}

		return Caked_Reply.with {
			$0.images = reply
		}
	}
}
