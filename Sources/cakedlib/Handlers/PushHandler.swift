//
//  PushHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import GRPCLib
import ContainerizationOCI
import Containerization
import Synchronization

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
	
			let context = ProgressObserver.ProgressHandlerContext()
			let currentItems = Atomic(0)
			var location = try storage.find(localName)
			var delete = false
			let config = try location.config()

			if location.isPIDRunning() {
				return PushReply(success: false, message: "VM is running")
			}

			let references = try remoteNames.map {
				let ref = try Reference.parse($0)
				
				ref.normalize()
				
				return ref.description
			}
			
			if config.os == .linux && config.useCloudInit {
				progressHandler(.step("Clean cloud-init"))

				location = try TemplateHandler.cleanCloudInit(source: location, config: config, runMode: runMode)
				delete = true
			}

			defer {
				if delete {
					try? location.delete()
				}
			}

			progressHandler(.step("Build image"))

			try await InitImage.create(references: references, location: location, labels: [:], imageStore: home.imageStore, contentStore: home.contentStore, chunkSize: Int64(chunkSize), concurrency: concurrency) { events in
				var addItems: Int? = nil
				var numberOfItems: Int? = nil

				events.forEach {
					if $0.event == "add-item" {
						addItems = $0.value as? Int
					} else if $0.event == "add-total-items" {
						numberOfItems = $0.value as? Int
					}
				}

				if let addItems, let numberOfItems {
					let count = currentItems.add(addItems, ordering: .relaxed)
					let fractionCompleted = (Double(count.newValue) / Double(numberOfItems))

					if context.oldFractionCompleted != fractionCompleted {
						progressHandler(.progress(context, fractionCompleted))
						context.oldFractionCompleted = fractionCompleted
					}
				}
			}
			
			for normalizedReference in references {
				progressHandler(.step("Push image to \(normalizedReference)"))

				let totalSize: Atomic<Int64> = Atomic(0)
				let currentSize: Atomic<Int64> = Atomic(0)

				try await PullHandler.withAuthentication(ref: normalizedReference) { auth in
					try await imageStore.push(reference: normalizedReference, platform: .current, insecure: insecure, auth: auth) { events in
						var addSize: Int64? = nil

						events.forEach {
							if $0.event == "add-total-size" {
								if let addTotalSize = $0.value as? Int64 {
									totalSize.add(addTotalSize, ordering: .relaxed)
								}
							} else if $0.event == "add-size" {
								addSize = $0.value as? Int64
							}

							if let addSize {
								let count = currentSize.add(addSize, ordering: .relaxed)
								let fractionCompleted = (Double(count.newValue) / Double(totalSize.load(ordering: .relaxed)))

								if context.oldFractionCompleted != fractionCompleted {
									progressHandler(.progress(context, fractionCompleted))
									context.oldFractionCompleted = fractionCompleted
								}
							}
						}
					}
				}
			}

			progressHandler(.terminated(.success(location), "Push complete"))

			return PushReply(success: true, message: "Success")
		} catch {
			progressHandler(.terminated(.failure(error), "Push failed"))

			return PushReply(success: false, message: "\(error)")
		}
	}
}
