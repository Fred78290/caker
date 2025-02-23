import Foundation
import GRPCLib
import NIOCore

struct LaunchHandler: CakedCommandAsync {
	var options: BuildOptions
	var waitIPTimeout = 180

	private static func launch(asSystem: Bool, options: BuildOptions, waitIPTimeout: Int, foreground: Bool) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(options.name)
		let config = try vmLocation.config()

		return try StartHandler(location: vmLocation, config: config, waitIPTimeout: 180, foreground: false).run(on: Root.group.next(), asSystem: runAsSystem)
	}

	static func buildAndLaunchVM(asSystem: Bool, options: BuildOptions, waitIPTimeout: Int, foreground: Bool) async throws -> String {
		try await BuildHandler.build(name: options.name, options: options, asSystem: asSystem)
		return try Self.launch(asSystem: asSystem, options: options, waitIPTimeout: waitIPTimeout, foreground: foreground)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		return on.makeFutureWithTask {
			let runningIP: String = try await Self.buildAndLaunchVM(asSystem: asSystem, options: options, waitIPTimeout: waitIPTimeout, foreground: false)
			return "launched \(options.name) with IP: \(runningIP)"
		}
	}

}
