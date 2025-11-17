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
	private static func withAuthentication<T>(ref: String, _ body: @Sendable @escaping (_ auth: Authentication?) async throws -> T) async throws -> T {
		let ref = try Reference.parse(ref)

		guard let host = ref.resolvedDomain else {
			throw ContainerizationError(.invalidArgument, message: "No host specified in image reference")
		}

		let keychain = KeychainHelper(id: Utilities.keychainID)
		let authentication = try? keychain.lookup(domain: host)

		return try await body(authentication)
	}

	public static func pull(location: VMLocation?, image: String, insecure: Bool, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> PullReply {
		let imageStore = try Home(runMode: runMode).imageStore
		let reference = try Reference.parse(image)

		reference.normalize()

		let normalizedReference = reference.description
		let image = try await Self.withAuthentication(ref: normalizedReference) { auth in
			try await imageStore.pull(reference: normalizedReference, platform: nil, insecure: insecure, auth: auth)
		}

		let context = ProgressObserver.ProgressHandlerContext()

		if let location {
			try await image.unpack(location) { event in
				var totalSize: Int64? = nil
				var addSize: Int64? = nil

				event.forEach {
					if $0.event == "add-size" {
						addSize = $0.value as? Int64
					} else if $0.event == "total-size" {
						totalSize = $0.value as? Int64
					}
				}
				
				if let totalSize, let addSize {
					let fractionCompleted = (Double(addSize) / Double(totalSize)) * 100.0
					
					if context.oldFractionCompleted != fractionCompleted {
						progressHandler(.progress(context, fractionCompleted))
						context.oldFractionCompleted = fractionCompleted
					}
				}
			}
		}
		return PullReply(success: true, message: "Success")
	}

	public static func pull(name: String, image: String, insecure: Bool, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> PullReply {
		do {
			if StorageLocation(runMode: runMode).exists(name) {
				return PullReply(success: false, message: "VM already exists")
			}
			
			let tempVMLocation: VMLocation = try VMLocation.tempDirectory(runMode: runMode)
			let storageLocation = StorageLocation(runMode: runMode)

			// Lock the temporary VM directory to prevent it's garbage collection
			let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
			try tmpVMDirLock.lock()

			try await withTaskCancellationHandler(
				operation: {
					do {
						_ = try await Self.pull(location: tempVMLocation, image: image, insecure: insecure, runMode: runMode, progressHandler: progressHandler)
						try storageLocation.relocate(name, from: tempVMLocation)
						
						let location = try StorageLocation(runMode: runMode).find(name)
						let config = try CakeConfig(location: location.rootURL, options: .init(name: name, password: "admin"))

						try config.save()

						progressHandler(.terminated(.success(location)))
					} catch {
						try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
						
						progressHandler(.terminated(.failure(error)))
						
						throw error
					}
				},
				onCancel: {
					try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
				})

			return PullReply(success: true, message: "Success")
		} catch {
			return PullReply(success: false, message: "\(error)")
		}
	}
}
