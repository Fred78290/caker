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
import Crypto
import SwiftDate

extension MediaTypes {
	/// The Tart media type used by tart layers referenced by an image manifest.
	public static let cakedConfigLayer = "application/vnd.aldunelabs.caked.config.v1"
	public static let cakedCdRomLayer = "application/vnd.aldunelabs.cdrom.v1"

	public static let tartConfigLayer = "application/vnd.cirruslabs.tart.config.v1"
	
	/// The Tart media type used by tart layers referenced by an image manifest.
	public static let tartDiskV2Layer = "application/vnd.cirruslabs.tart.disk.v2"
	
	/// The Tart media type used by tart layers referenced by an image manifest.
	public static let tartDiskV1Layer = "application/vnd.cirruslabs.tart.disk.v1"
	
	/// The Tart media type used by tart layers referenced by an image manifest.
	public static let tartNVRamLayer = "application/vnd.cirruslabs.tart.nvram.v1"
	
	public static let diskFormatLabel = "org.cirruslabs.tart.disk.format"
	public static let uncompressedDiskSizeAnnotation = "org.cirruslabs.tart.uncompressed-disk-size"
	public static let uploadTimeAnnotation = "org.cirruslabs.tart.upload-time"
	public static let uncompressedSizeAnnotation = "org.cirruslabs.tart.uncompressed-size"
	public static let uncompressedContentDigestAnnotation = "org.cirruslabs.tart.uncompressed-content-digest"
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

extension ContentWriter {
	public struct ChunkedLayer {
		let size: Int64
		let uncompressedSize: Int64
		let digest: SHA256.Digest
		let uncompressedDigest: SHA256.Digest
	}

	/// Reads the data present in the passed in URL and writes it to the base path.
	/// - Parameters:
	///   - url: The URL to read the data from.
	@discardableResult
	public func create(from url: URL) throws -> ChunkedLayer {
		let data = try Data(contentsOf: url)
		let result = try self.write(data)
		
		return ChunkedLayer(size: result.size, uncompressedSize: Int64(data.count), digest: result.digest, uncompressedDigest: SHA256.hash(data: data))
	}

	@discardableResult
	public func createChunked(from url: URL, chunkSize: Int64, concurrency: UInt) async throws -> [ChunkedLayer] {
		let mappedDisk = try Data(contentsOf: url, options: [.alwaysMapped])
		var pushedLayers: [(index: Int, layer: ChunkedLayer)] = []

		// Compress the disk file as multiple individually decompressible streams,
		// each equal ``Self.layerLimitBytes`` bytes or less due to LZ4 compression
		try await withThrowingTaskGroup(of: (index: Int, layer: ChunkedLayer).self) { group in
			for (index, data) in mappedDisk.chunks(ofCount: RawDisk.layerLimitBytes).enumerated() {
				// Respect the concurrency limit
				if index >= concurrency {
					if let layer = try await group.next() {
						pushedLayers.append(layer)
					}
				}

				// Launch a disk layer pushing task
				group.addTask {
					let compressedData = try (data as NSData).compressed(using: .lz4) as Data
					let result = try self.write(compressedData)

					return (index, ChunkedLayer(size: result.size, uncompressedSize: Int64(data.count), digest: result.digest, uncompressedDigest: SHA256.hash(data: data)))
				}
			}

			for try await pushedLayer in group {
				pushedLayers.append(pushedLayer)
			}
		}

		return pushedLayers.sorted {
			$0.index < $1.index
		}.map {
			$0.layer
		}
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
		var cdrom: FileSystemProtocol! = nil
		let imageType = try await manifest.imageType()

		switch imageType {
		case .docker:
			filesystem = try EXT4.Formatter(FilePath(cleanedPath))
		case .tart:
			filesystem = try RawDisk(FilePath(cleanedPath))
		case .unknown:
			throw ServiceError("Unsupported image type")
		}

		defer {
			try? filesystem.close()
			try? cdrom?.close()
		}

		var totalSize: Int64 = 0
		var currentSize: Int64 = 0

		manifest.layers.forEach { layer in
			switch layer.mediaType {
			case MediaTypes.imageLayer, MediaTypes.dockerImageLayer, MediaTypes.imageLayerGzip, MediaTypes.dockerImageLayerGzip, MediaTypes.tartConfigLayer, MediaTypes.tartNVRamLayer, MediaTypes.tartDiskV1Layer, MediaTypes.tartDiskV2Layer:
				totalSize += 1
			default:
				break
			}
		}

		if let progress = progress {
			await progress([
				ProgressEvent(event: "current-size", value: currentSize),
				ProgressEvent(event: "total-size", value: totalSize)
			])
		}

		for layer in manifest.layers {
			try Task.checkCancellation()

			currentSize += 1

			let content = try await self.getContent(digest: layer.digest)

			switch layer.mediaType {
			case MediaTypes.imageLayer, MediaTypes.dockerImageLayer:
				try filesystem.unpack(source: content.path, compression: .none)
			case MediaTypes.imageLayerGzip, MediaTypes.dockerImageLayerGzip:
				try filesystem.unpack(source: content.path, compression: .gzip)
			case MediaTypes.tartDiskV1Layer, MediaTypes.tartDiskV2Layer:
				try filesystem.unpack(source: content.path, compression: .lz4)
			case MediaTypes.cakedCdRomLayer:
				if cdrom == nil {
					cdrom = try RawDisk(FilePath(location.cdromISO.absolutePath()))
				}
				try cdrom!.unpack(source: content.path, compression: .lz4)
			case MediaTypes.tartConfigLayer:
				try FileManager.default.copyItem(at: content.path, to: location.configURL)
			case MediaTypes.tartNVRamLayer:
				try FileManager.default.copyItem(at: content.path, to: location.nvramURL)
			case MediaTypes.cakedConfigLayer:
				try FileManager.default.copyItem(at: content.path, to: location.cakeURL)
			default:
				continue
			}

			if let progress = progress {
				await progress([
					ProgressEvent(event: "current-size", value: currentSize),
					ProgressEvent(event: "total-size", value: totalSize)
				])
			}
		}

		return imageType
	}
}

extension InitImage {
	actor AsyncStore<T> {
		private var _value: T?

		init(_ value: T? = nil) {
			self._value = value
		}

		func get() -> T? {
			self._value
		}

		func set(_ value: T) {
			self._value = value
		}
	}

	@discardableResult
	public static func create(references: [String], location: VMLocation, platform: Platform = .current, labels: [String: String] = [:], imageStore: ImageStore, contentStore: ContentStore, chunkSize: Int64, concurrency: UInt = 4) async throws -> [InitImage] {
		let indexDescriptorStore = AsyncStore<Descriptor>()
		let diskSize = try location.sizeBytes()

		try await contentStore.ingest { dir in
			let writer = try ContentWriter(for: dir)

			let diskLayers = try await writer.createChunked(from: location.diskURL, chunkSize: chunkSize, concurrency: concurrency)
			var layersDescriptors = diskLayers.map {
				Descriptor(mediaType: MediaTypes.tartDiskV2Layer, digest: $0.digest.digestString, size: $0.size, annotations: [
					MediaTypes.uncompressedContentDigestAnnotation : $0.uncompressedDigest.digestString,
					MediaTypes.uncompressedSizeAnnotation : "\($0.uncompressedSize)"
				])
			}

			var result: ContentWriter.ChunkedLayer = try writer.create(from: location.configURL)
			layersDescriptors.append(
				Descriptor(mediaType: MediaTypes.tartConfigLayer, digest: result.digest.digestString, size: result.size, annotations: [
					MediaTypes.uncompressedContentDigestAnnotation : result.uncompressedDigest.digestString,
					MediaTypes.uncompressedSizeAnnotation : "\(result.uncompressedSize)"
				])
			)

			result = try writer.create(from: location.cakeURL)
			layersDescriptors.append(
				Descriptor(mediaType: MediaTypes.cakedConfigLayer, digest: result.digest.digestString, size: result.size, annotations: [
					MediaTypes.uncompressedContentDigestAnnotation : result.uncompressedDigest.digestString,
					MediaTypes.uncompressedSizeAnnotation : "\(result.uncompressedSize)"
				])
			)

			result = try writer.create(from: location.nvramURL)
			layersDescriptors.append(
				Descriptor(mediaType: MediaTypes.tartNVRamLayer, digest: result.digest.digestString, size: result.size, annotations: [
					MediaTypes.uncompressedContentDigestAnnotation : result.uncompressedDigest.digestString,
					MediaTypes.uncompressedSizeAnnotation : "\(result.uncompressedSize)"
				])
			)

			if try location.cdromISO.exists() {
				let diskLayers = try await writer.createChunked(from: location.cdromISO, chunkSize: chunkSize, concurrency: concurrency)

				layersDescriptors.append(contentsOf: diskLayers.map {
					Descriptor(mediaType: MediaTypes.cakedCdRomLayer, digest: $0.digest.digestString, size: $0.size, annotations: [
						MediaTypes.uncompressedContentDigestAnnotation : $0.uncompressedDigest.digestString,
						MediaTypes.uncompressedSizeAnnotation : "\($0.uncompressedSize)"
					])
				})
			}

			let rootfsConfig = ContainerizationOCI.Rootfs(type: "layers", diffIDs: diskLayers.map { $0.digest.digestString })
			let runtimeConfig = ContainerizationOCI.ImageConfig(labels: labels)
			let imageConfig = ContainerizationOCI.Image(architecture: platform.architecture, os: platform.os, config: runtimeConfig, rootfs: rootfsConfig)

			var layer = try writer.create(from: imageConfig)

			let configDescriptor = Descriptor(mediaType: ContainerizationOCI.MediaTypes.imageConfig, digest: layer.digest.digestString, size: layer.size)

			let manifest = Manifest(config: configDescriptor, layers: layersDescriptors)

			layer = try writer.create(from: manifest)

			let manifestDescriptor = Descriptor(mediaType: ContainerizationOCI.MediaTypes.imageManifest, digest: layer.digest.digestString, size: layer.size, platform: platform)

			let index = ContainerizationOCI.Index(manifests: [manifestDescriptor], annotations: [
				MediaTypes.uncompressedDiskSizeAnnotation: "\(diskSize)",
				MediaTypes.uploadTimeAnnotation: Date.now.toISO()
			])

			layer = try writer.create(from: index)

			let indexDescriptor = Descriptor(mediaType: ContainerizationOCI.MediaTypes.index, digest: layer.digest.digestString, size: layer.size)

			await indexDescriptorStore.set(indexDescriptor)
		}

		var result: [InitImage] = []

		for reference in references {
			guard let indexDescriptor = await indexDescriptorStore.get() else {
				throw ServiceError("image for \(reference) not found")
			}

			let description = Image.Description(reference: reference, descriptor: indexDescriptor)
			let image = try await imageStore.create(description: description)

			result.append(InitImage(image: image))
		}

		return result
	}
}
