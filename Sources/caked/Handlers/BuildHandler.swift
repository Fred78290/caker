import Dispatch
import Foundation
import SwiftUI
import Virtualization
import GRPCLib
import NIOCore

struct BuildHandler: CakedCommand {
	var options: BuildOptions

	static func build(name: String, options: BuildOptions, asSystem: Bool) async throws {
		let tempVMLocation: VMLocation = try VMLocation.tempDirectory()

		// Lock the temporary VM directory to prevent it's garbage collection
		let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
		try tmpVMDirLock.lock()

		try await withTaskCancellationHandler(
			operation: {
				try await VMBuilder.buildVM(vmName: name, vmLocation: tempVMLocation, options: options)
				try StorageLocation(asSystem: asSystem).relocate(name, from: tempVMLocation)
			},
			onCancel: {
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			})
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		return on.makeFutureWithTask {
			try await Self.build(name: self.options.name, options: self.options, asSystem: asSystem)

			return ""
		}
	}
}
