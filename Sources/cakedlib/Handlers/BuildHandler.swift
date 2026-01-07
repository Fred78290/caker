import Dispatch
import Foundation
import GRPCLib
import CakeAgentLib
import NIOCore
import SwiftUI
import Virtualization

public struct BuildHandler {
	public static func build(name: String, options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> BuildedReply {
		do {
			let storageLocation = StorageLocation(runMode: runMode)

			if storageLocation.exists(name) {
				return BuildedReply(name: options.name, builded: false, reason: "VM already exists")
			}

			let tempVMLocation: VMLocation = try VMLocation.tempDirectory(runMode: runMode)

			// Lock the temporary VM directory to prevent it's garbage collection
			let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
			try tmpVMDirLock.lock()

			try await withTaskCancellationHandler(
				operation: {
					do {
						let location = storageLocation.location(name)
						_ = try await VMBuilder.buildVM(vmName: name, location: tempVMLocation, options: options, runMode: runMode, queue: queue, progressHandler: progressHandler)

						try storageLocation.relocate(name, from: tempVMLocation)

						progressHandler(.terminated(.success(location), "Build VM finished successfully"))
					} catch {
						try? FileManager.default.removeItem(at: tempVMLocation.rootURL)

						progressHandler(.terminated(.failure(error), "Build VM failed"))

						throw error
					}
				},
				onCancel: {
					try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
				})
			return BuildedReply(name: options.name, builded: true, reason: "VM created")
		} catch {
			return BuildedReply(name: options.name, builded: false, reason: "\(error)")
		}
	}
}
