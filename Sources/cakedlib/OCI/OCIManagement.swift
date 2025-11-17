//
//  manager.swift
//  Caker
//
//  Created by Frederic BOLTZ on 15/11/2025.
//
import Foundation
import Containerization
import ContainerizationOCI
import ContainerizationEXT4
import ContainerizationExtras
import ContainerizationArchive
import SystemPackage
import Compression

extension Home {
	var contentStore: LocalContentStore {
		try! LocalContentStore(path: cacheDirectory.appendingPathComponent("OCIs"))
	}

	var imageStore: ImageStore {
		try! ImageStore(path: cacheDirectory, contentStore: self.contentStore)
	}
}

extension MediaTypes {
	/// The Tart media type used by tart layers referenced by an image manifest.
	public static let tartConfigLayer = "application/vnd.cirruslabs.tart.config.v1"
	
	/// The Tart media type used by tart layers referenced by an image manifest.
	public static let tartDiskV2Layer = "application/vnd.cirruslabs.tart.disk.v2"
	
	/// The Tart media type used by tart layers referenced by an image manifest.
	public static let tartDiskV1Layer = "application/vnd.cirruslabs.tart.disk.v1"
	
	/// The Tart media type used by tart layers referenced by an image manifest.
   public static let tartNVRamLayer = "application/vnd.cirruslabs.tart.nvram.v1"
}

extension Manifest {
	static let dockerLayers = [
		MediaTypes.imageLayer,
		MediaTypes.dockerImageLayer,
		MediaTypes.imageLayerGzip,
		MediaTypes.dockerImageLayerGzip
	]

	public enum ImageType: String, CaseIterable, Codable {
		case docker
		case tart
		case unknown
	}
	
	public  func imageType() async throws -> ImageType {
		if self.layers.first(where: { $0.mediaType == MediaTypes.tartDiskV1Layer || $0.mediaType == MediaTypes.tartDiskV2Layer }) != nil {
			return .tart
		}

		if self.layers.first(where: { Self.dockerLayers.contains($0.mediaType) }) != nil {
			return .docker
		}

		return .unknown
	}
}

protocol FileSystemProtocol {
	func close() throws
	func unpack(source: URL, compression: ContainerizationArchive.Filter) throws
}

extension EXT4.Formatter: FileSystemProtocol {
	func unpack(source: URL, compression: ContainerizationArchive.Filter) throws {
		try self.unpack(source: source, format: .paxRestricted, compression: compression, progress: nil)
	}
}

extension Containerization.Image {
	public func totalSize(for platform: Platform = .current) async throws -> Int64 {
		let manifest = try await self.manifest(for: platform)

		return manifest.layers.reduce(0) { $0 + $1.size }
	}

	public func unpack(_ location: VMLocation, for platform: Platform = .current, progress: ProgressHandler? = nil) async throws -> Manifest.ImageType {
		let manifest = try await self.manifest(for: platform)
		let cleanedPath = location.diskURL.absolutePath()
		let filesystem: FileSystemProtocol
		let imageType = try await manifest.imageType()

		switch imageType {
		case .docker:
			filesystem = try EXT4.Formatter(FilePath(cleanedPath))
		case .tart:
			filesystem = try RawDisk(FilePath(cleanedPath))
		case .unknown:
			throw ServiceError("Unsupported image type")
		}

		defer { try? filesystem.close() }

		var totalSize: Int64 = 0
		
		manifest.layers.forEach { layer in
			switch layer.mediaType {
			case MediaTypes.imageLayer, MediaTypes.dockerImageLayer, MediaTypes.imageLayerGzip, MediaTypes.dockerImageLayerGzip, MediaTypes.tartConfigLayer, MediaTypes.tartNVRamLayer, MediaTypes.tartDiskV1Layer, MediaTypes.tartDiskV2Layer:
				totalSize += layer.size
			default:
				break
			}
		}

		for layer in manifest.layers {
			try Task.checkCancellation()

			let content = try await self.getContent(digest: layer.digest)

			switch layer.mediaType {
			case MediaTypes.imageLayer, MediaTypes.dockerImageLayer:
				try filesystem.unpack(source: content.path, compression: .none)
			case MediaTypes.imageLayerGzip, MediaTypes.dockerImageLayerGzip:
				try filesystem.unpack(source: content.path, compression: .gzip)
			case MediaTypes.tartDiskV1Layer, MediaTypes.tartDiskV2Layer:
				try filesystem.unpack(source: content.path, compression: .lz4)
			case MediaTypes.tartConfigLayer:
				try FileManager.default.copyItem(at: content.path, to: location.configURL)
			case MediaTypes.tartNVRamLayer:
				try FileManager.default.copyItem(at: content.path, to: location.nvramURL)
			default:
				continue
			}

			if let progress = progress {
				await progress([
					ProgressEvent(event: "add-size", value: layer.size),
					ProgressEvent(event: "total-size", value: totalSize)
				])
			}
		}

		return imageType
	}
}
