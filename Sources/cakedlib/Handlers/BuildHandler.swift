import Dispatch
import Foundation
import GRPCLib
import Logging
import NIOCore
import SwiftUI
import Virtualization

public struct BuildHandler {
	public static func build(name: String, options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> BuildedReply {
		do {
			if StorageLocation(runMode: runMode).exists(name) {
				return BuildedReply(name: options.name, builded: false, reason: "VM already exists")
			}
			
			let tempVMLocation: VMLocation = try VMLocation.tempDirectory(runMode: runMode)
			
			// Lock the temporary VM directory to prevent it's garbage collection
			let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
			try tmpVMDirLock.lock()
			
			try await withTaskCancellationHandler(
				operation: {
					do {
						_ = try await VMBuilder.buildVM(vmName: name, location: tempVMLocation, options: options, runMode: runMode, queue: queue, progressHandler: progressHandler)

						try StorageLocation(runMode: runMode).relocate(name, from: tempVMLocation)
						
						progressHandler(.terminated(.success(try StorageLocation(runMode: runMode).find(name))))
					} catch {
						try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
						
						progressHandler(.terminated(.failure(error)))
						
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
