//
//  PullHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import GRPCLib
import Containerization
import ContainerizationArchive
import ContainerizationError
import ContainerizationExtras
import ContainerizationOCI
import Foundation

public struct PullHandler {
	public static func pull(location: VMLocation, image: String, insecure: Bool, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> PullReply {
		do {
			let imageStore: ImageStore = Application.imageStore
			let platform: Platform? = try {
				if let platformString {
					return try Platform(from: platformString)
				}
				return nil
			}()
			
			let reference = try Reference.parse(image)
			reference.normalize()
			let normalizedReference = reference.description
			if normalizedReference != image {
				print("Reference resolved to \(reference.description)")
			}
			
			var startTime = ContinuousClock.now
			let image = try await Images.withAuthentication(ref: normalizedReference) { auth in
				try await imageStore.pull(reference: normalizedReference, platform: platform, insecure: insecure, auth: auth)
			}
			
			guard let image else {
				return PullReply(success: true, message: "image pull failed")
			}
			
			var duration = ContinuousClock.now - startTime
			print("Image pull took: \(duration)\n")
			
			guard let unpackPath else {
				return PullReply(success: false, message: "Succes")
			}
			guard !FileManager.default.fileExists(atPath: unpackPath) else {
				throw ContainerizationError(.exists, message: "Directory already exists at \(unpackPath)")
			}
			let unpackUrl = URL(filePath: unpackPath)
			try FileManager.default.createDirectory(at: unpackUrl, withIntermediateDirectories: true)
			
			let unpacker = EXT4Unpacker.init(blockSizeInBytes: 2.gib())
			
			startTime = ContinuousClock.now
			if let platform {
				let name = platform.description.replacingOccurrences(of: "/", with: "-")
				let _ = try await unpacker.unpack(image, for: platform, at: unpackUrl.appending(component: name))
			} else {
				for descriptor in try await image.index().manifests {
					if let referenceType = descriptor.annotations?["vnd.docker.reference.type"], referenceType == "attestation-manifest" {
						continue
					}
					guard let descPlatform = descriptor.platform else {
						continue
					}
					let name = descPlatform.description.replacingOccurrences(of: "/", with: "-")
					let _ = try await unpacker.unpack(image, for: descPlatform, at: unpackUrl.appending(component: name))
					print("created snapshot for platform \(descPlatform.description)")
				}
			}
			duration = ContinuousClock.now - startTime

			return PullReply(success: true, message: "Succes")
		} catch {
			return PullReply(success: false, message: "\(error)")
		}
	}

	public static func pull(name: String, image: String, insecure: Bool, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> PullReply {
		PullReply(success: false, message: "Not implemented")
	}
}
