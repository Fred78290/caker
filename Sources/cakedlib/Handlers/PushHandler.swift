//
//  PushHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import GRPCLib
import ContainerizationOCI
import Containerization

public struct PushHandler {
	public static func push(localName: String, remoteNames: [String], insecure: Bool, chunkSizeInMB: Int, concurrency: UInt, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> PushReply {
		do {
			let home = try Home(runMode: runMode)
			let imageStore = home.imageStore
			let storage = StorageLocation(runMode: runMode)
			let chunkSize = chunkSizeInMB == 0 ? RawDisk.bufferSizeBytes : chunkSizeInMB * 1024 * 1024

			if storage.exists(localName) == false {
				return PushReply(success: false, message: "VM not found")
			}
			
			let labels: [String: String] = [
				"com.apple.containerization.index.indirect": "true"
			]

			let references = try remoteNames.map {
				let ref = try Reference.parse($0)
				
				ref.normalize()
				
				return ref.description
			}
			
			try await InitImage.create(references: references, location: storage.find(localName), labels: labels, imageStore: home.imageStore, contentStore: home.contentStore, chunkSize: Int64(chunkSize), concurrency: concurrency)
			
			_ = references.async.map { normalizedReference in
				try await PullHandler.withAuthentication(ref: normalizedReference) { auth in
					try await imageStore.push(reference: normalizedReference, platform: .current, insecure: insecure, auth: auth)
				}
			}

			return PushReply(success: true, message: "Success")
		} catch {
			return PushReply(success: false, message: "\(error)")
		}
	}
}
