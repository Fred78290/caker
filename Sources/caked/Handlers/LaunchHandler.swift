import Foundation
import GRPCLib
import NIOCore

struct LaunchHandler: CakedCommand {
	var options: BuildOptions
	var waitIPTimeout = 180

	private static func launch(asSystem: Bool, options: BuildOptions, waitIPTimeout: Int, foreground: Bool) throws -> String {
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
		config.forwardedPorts = options.forwardedPort

		try config.save(to: vmLocation.rootURL)

		return try StartHandler.startVM(vmLocation: vmLocation, waitIPTimeout: waitIPTimeout, foreground: foreground)
	}

	static func buildAndLaunchVM(asSystem: Bool, options: BuildOptions, waitIPTimeout: Int, foreground: Bool) async throws -> String {
		let tempVMLocation: VMLocation = try VMLocation.tempDirectory()

		// Lock the temporary VM directory to prevent it's garbage collection
		let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
		try tmpVMDirLock.lock()

		return try await withTaskCancellationHandler(
			operation: {
				try await VMBuilder.buildVM(vmName: options.name, vmLocation: tempVMLocation, options: options)
				try tmpVMDirLock.unlock()
				try StorageLocation(asSystem: asSystem).relocate(options.name, from: tempVMLocation)
				
				return try Self.launch(asSystem: asSystem, options: options, waitIPTimeout: waitIPTimeout, foreground: foreground)
			},
			onCancel: {
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			})
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		return on.makeFutureWithTask {
			let runningIP: String = try await Self.buildAndLaunchVM(asSystem: asSystem, options: options, waitIPTimeout: waitIPTimeout, foreground: false)
			return "launched \(options.name) with IP: \(runningIP)"
		}
	}

}
