import Foundation
import GRPCLib
import NIOCore

public struct LaunchHandler {
	private static func launch(runMode: Utils.RunMode, options: BuildOptions, waitIPTimeout: Int, startMode: StartHandler.StartMode) throws -> String {
		let location = try StorageLocation(runMode: runMode).find(options.name)
		let config = try location.config()

		return try StartHandler.startVM(on: Utilities.group.next(), location: location, config: config, waitIPTimeout: 180, startMode: startMode, runMode: runMode)
	}

	public static func buildAndLaunchVM(runMode: Utils.RunMode, options: BuildOptions, waitIPTimeout: Int, startMode: StartHandler.StartMode) async throws -> String {
		try await BuildHandler.build(name: options.name, options: options, runMode: runMode, progressHandler: ProgressObserver.progressHandler)

		let runningIP = try Self.launch(runMode: runMode, options: options, waitIPTimeout: waitIPTimeout, startMode: startMode)

		return "VM launched \(options.name) with IP: \(runningIP)"
	}
}
