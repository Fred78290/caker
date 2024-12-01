import Foundation
import GRPCLib

protocol LaunchArguments : BuildArguments {
	var dir: [String] { get }
	var netBridged: [String] { get }
	var netSoftnet: Bool { get }
	var netSoftnetAllow: String? { get }
	var netHost: Bool { get }
	var nested: Bool { get }
	var foreground: Bool { get }
}

struct LaunchHandler: CakedCommand, LaunchArguments {
	var name: String
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
	var sshAuthorizedKey: String?
	var remoteContainerServer: String = defaultSimpleStreamsServer
	var vendorData: String?
	var userData: String?
	var networkConfig: String?
	var dir: [String] = []
	var netBridged: [String] = []
	var netSoftnet: Bool = false
	var netSoftnetAllow: String?
	var netHost: Bool = false
	var nested: Bool = true
	var foreground: Bool = false
	var displayRefit: Bool = true
	var autostart: Bool = false
	var forwardedPort: [ForwardedPort] = []

	static func launch(asSystem: Bool, _ self: LaunchArguments) throws {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(self.name)
		var config = try CakeConfig(baseURL: vmLocation.rootURL)

		config.nested = self.nested
		config.displayRefit = self.displayRefit
		config.autostart = self.autostart
		config.netBridged = self.netBridged
		config.netSoftnet = self.netSoftnet
		config.netSoftnetAllow = self.netSoftnetAllow
		config.netHost = self.netHost
		config.dir = self.dir

		try config.save(to: vmLocation.rootURL)

		try StartHandler.startVM(vmLocation: vmLocation, foreground: self.foreground)
	}

	static func launchVM(asSystem: Bool, _ self: LaunchArguments) async throws {
		let tempVMLocation: VMLocation = try VMLocation.tempDirectory()

		// Lock the temporary VM directory to prevent it's garbage collection
		let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
		try tmpVMDirLock.lock()

		try await withTaskCancellationHandler(
			operation: {
				try await VMBuilder.buildVM(vmName: self.name, vmLocation: tempVMLocation, arguments: self)
				try tmpVMDirLock.unlock()
				try StorageLocation(asSystem: asSystem).relocate(self.name, from: tempVMLocation)
				try Self.launch(asSystem: asSystem, self)
			},
			onCancel: {
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			})
	}

	func run(asSystem: Bool) async throws  -> String {
		try await Self.launchVM(asSystem: asSystem, self)
		return "launched \(name)"
	}

}
