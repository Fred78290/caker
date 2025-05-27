import Dispatch
import Foundation
import GRPCLib
import NIOCore
import SwiftUI
import Virtualization

struct BuildHandler: CakedCommandAsync {
	var options: BuildOptions

	static func build(name: String, options: BuildOptions, asSystem: Bool) async throws {

		if StorageLocation(asSystem: asSystem).exists(name) {
			throw ServiceError("VM already exists")
		}

		let tempVMLocation: VMLocation = try VMLocation.tempDirectory(asSystem: asSystem)

		// Lock the temporary VM directory to prevent it's garbage collection
		let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
		try tmpVMDirLock.lock()

		try await withTaskCancellationHandler(
			operation: {
				do {
					if try await VMBuilder.buildVM(vmName: name, vmLocation: tempVMLocation, options: options, asSystem: asSystem) == .oci {
						try tempVMLocation.delete()
					} else {
						try StorageLocation(asSystem: asSystem).relocate(name, from: tempVMLocation)
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

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			try await Self.build(name: self.options.name, options: self.options, asSystem: asSystem)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.message = "VM \(self.options.name) created"
				}
			}
		}
	}
}
