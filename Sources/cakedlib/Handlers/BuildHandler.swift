import Dispatch
import Foundation
import GRPCLib
import NIOCore
import SwiftUI
import Virtualization

public struct BuildHandler {
	public static func build(name: String, options: BuildOptions, runMode: Utils.RunMode) async throws {
		if StorageLocation(runMode: runMode).exists(name) {
			throw ServiceError("VM already exists")
		}

		let tempVMLocation: VMLocation = try VMLocation.tempDirectory(runMode: runMode)

		// Lock the temporary VM directory to prevent it's garbage collection
		let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
		try tmpVMDirLock.lock()

		try await withTaskCancellationHandler(
			operation: {
				do {
					if try await VMBuilder.buildVM(vmName: name, vmLocation: tempVMLocation, options: options, runMode: runMode) == .oci {
						try tempVMLocation.delete()
					} else {
						try StorageLocation(runMode: runMode).relocate(name, from: tempVMLocation)
					}
				} catch {
					try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
					throw error
				}
			},
			onCancel: {
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			})
	}
}
