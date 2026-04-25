import Dispatch
import Foundation
import GRPCLib
import CakeAgentLib
import NIOCore
import SwiftUI
import Virtualization

public struct BuildHandler {
	public static func build(options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> BuildedReply {
		do {
			let storageLocation = StorageLocation(runMode: runMode)

			if storageLocation.exists(options.name) {
				return BuildedReply(name: options.name, builded: false, reason: String(localized: "VM already exists"))
			}

			if options.bridgedNetwork {
				guard try CakedKeyConfig.bridgedNetwork.get() != nil else {
					return BuildedReply(name: options.name, builded: false, reason: String(localized: "Any bridged network is not configured"))
				}
			}

			let tempVMLocation: VMLocation = try VMLocation.tempDirectory(runMode: runMode)

			// Lock the temporary VM directory to prevent it's garbage collection
			let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
			try tmpVMDirLock.lock()

			try await withTaskCancellationHandler(
				operation: {
					do {
						let location = storageLocation.location(options.name)
						_ = try await VMBuilder.buildVM(vmName: options.name, location: tempVMLocation, options: options, runMode: runMode, queue: queue, progressHandler: progressHandler)

						try storageLocation.relocate(options.name, from: tempVMLocation)

						progressHandler(.terminated(.success(location.rootURL), "Build VM finished successfully"))
					} catch {
						try? FileManager.default.removeItem(at: tempVMLocation.rootURL)

						progressHandler(.terminated(.failure(error), "Build VM failed"))

						throw error
					}
				},
				onCancel: {
					try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
				})
			return BuildedReply(name: options.name, builded: true, reason: String(localized: "VM created"))
		} catch {
			return BuildedReply(name: options.name, builded: false, reason: error.reason)
		}
	}
}
