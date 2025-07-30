import Dispatch
import Foundation
import GRPCLib
import NIOCore
import SwiftUI
import Virtualization
import Logging

public struct BuildHandler {
	public static func progressHandler(_ result: VirtualMachine.IPSWProgressValue) {
		if case let .progress(fractionCompleted) = result {
			let completed = Int(fractionCompleted * 100)
			
			if completed % 10 == 0 {
				if completed == 0 {
					print(String(format: "%0.2d", completed), terminator: "")
				} else if completed < 100 {
					print(String(format: "...%0.2d", completed), terminator: "")
				} else {
					print(String(format: "...%0.3d", completed), terminator: " complete\n")
				}
			}
		} else if case let .terminated(result) = result {
			let logger = Logger("BuildHandler")

			if case let .failure(error) = result {
				logger.error("IPSW installation failed: \(error)")
			} else {
				logger.error("IPSW installation succeeded")
			}
		}
	}

	public static func build(name: String, options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: VirtualMachine.IPSWProgressHandler? = nil) async throws {
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
					if try await VMBuilder.buildVM(vmName: name, location: tempVMLocation, options: options, runMode: runMode, queue: queue, progressHandler: progressHandler) == .oci {
						try tempVMLocation.delete()
					} else {
						try StorageLocation(runMode: runMode).relocate(name, from: tempVMLocation)
					}
				} catch {
					try? FileManager.default.removeItem(at: tempVMLocation.rootURL)

					if let progressHandler = progressHandler {
						progressHandler(.terminated(.failure(error)))
					}

					throw error
				}
			},
			onCancel: {
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			})
	}
}
