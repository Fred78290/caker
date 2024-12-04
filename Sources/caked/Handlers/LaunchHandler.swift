import Foundation
import GRPCLib

struct LaunchHandler: CakedCommand {
	var options: BuildOptions

	private static func launch(asSystem: Bool, options: BuildOptions, foreground: Bool) throws {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(options.name)
		var config = try CakeConfig(baseURL: vmLocation.rootURL)

		config.nested = options.nested
		config.displayRefit = options.displayRefit
		config.autostart = options.autostart
		config.netBridged = options.netBridged
//		config.netSoftnet = options.netSoftnet
//		config.netSoftnetAllow = options.netSoftnetAllow
//		config.netHost = options.netHost
		config.mounts = options.mounts
		config.forwardedPort = options.forwardedPort

		try config.save(to: vmLocation.rootURL)

		try StartHandler.startVM(vmLocation: vmLocation, foreground: foreground)
	}

	static func buildAndLaunchVM(asSystem: Bool, options: BuildOptions, foreground: Bool) async throws {
		let tempVMLocation: VMLocation = try VMLocation.tempDirectory()

		// Lock the temporary VM directory to prevent it's garbage collection
		let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
		try tmpVMDirLock.lock()

		try await withTaskCancellationHandler(
			operation: {
				try await VMBuilder.buildVM(vmName: options.name, vmLocation: tempVMLocation, options: options)
				try tmpVMDirLock.unlock()
				try StorageLocation(asSystem: asSystem).relocate(options.name, from: tempVMLocation)
				try Self.launch(asSystem: asSystem, options: options, foreground: foreground)
			},
			onCancel: {
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			})
	}

	func run(asSystem: Bool) async throws  -> String {
		try await Self.buildAndLaunchVM(asSystem: asSystem, options: options, foreground: false)
		return "launched \(options.name)"
	}

}
