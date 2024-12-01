import Dispatch
import Foundation
import SwiftUI
import Virtualization
import GRPCLib
protocol BuildArguments {
	var name: String { get }
	var cpu: UInt16 { get }
	var memory: UInt64 { get }
	var user: String { get }
	var mainGroup: String { get }
	var clearPassword: Bool { get }
	var cloudImage: String? { get }
	var remoteContainerServer: String { get }
	var aliasImage: String? { get }
	var fromImage: String? { get }
	var ociImage: String? { get }
	var sshAuthorizedKey: String? { get }
	var vendorData: String? { get }
	var userData: String? { get }
	var networkConfig: String? { get }
	var diskSize: UInt16 { get }
	var displayRefit: Bool { get }
	var autostart: Bool { get }
	var nested: Bool { get }
	var forwardedPort: [ForwardedPort] { get }
}

struct BuildHandler: CakedCommand, BuildArguments {
	var name: String = ""
	var cpu: UInt16 = 1
	var memory: UInt64 = 512
	var diskSize: UInt16 = 20
	var user: String = "admin"
	var mainGroup: String = "adm"
	var clearPassword: Bool = false
	var cloudImage: String?
	var aliasImage: String?
	var fromImage: String?
	var ociImage: String?
	var remoteContainerServer: String = defaultSimpleStreamsServer
	var sshAuthorizedKey: String?
	var vendorData: String?
	var userData: String?
	var networkConfig: String?
	var displayRefit: Bool = true
	var autostart: Bool = false
	var nested: Bool = false
	var forwardedPort: [ForwardedPort] = []

	static func build(name: String, arguments: BuildArguments, asSystem: Bool) async throws {
		let tempVMLocation: VMLocation = try VMLocation.tempDirectory()

		// Lock the temporary VM directory to prevent it's garbage collection
		let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
		try tmpVMDirLock.lock()

		try await withTaskCancellationHandler(
			operation: {
				try await VMBuilder.buildVM(vmName: name, vmLocation: tempVMLocation, arguments: arguments)
				try StorageLocation(asSystem: asSystem).relocate(name, from: tempVMLocation)
			},
			onCancel: {
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			})
	}

	func run(asSystem: Bool) async throws -> String {
		try await Self.build(name: self.name, arguments: self, asSystem: asSystem)

		return ""
	}
}
