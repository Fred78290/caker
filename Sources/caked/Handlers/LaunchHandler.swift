import Foundation
import GRPCLib
import NIOCore

struct LaunchHandler: CakedCommandAsync {
	var options: BuildOptions
	var waitIPTimeout = 180

	private static func launch(asSystem: Bool, options: BuildOptions, waitIPTimeout: Int, startMode: StartHandler.StartMode, runAsSystem: Bool = false) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(options.name)
		let config = try vmLocation.config()

		return try StartHandler.startVM(on: Root.group.next(), vmLocation: vmLocation, config: config, waitIPTimeout: 180, startMode: startMode, asSystem: runAsSystem)
	}

	static func buildAndLaunchVM(asSystem: Bool, options: BuildOptions, waitIPTimeout: Int, startMode: StartHandler.StartMode) async throws -> String {
		try await BuildHandler.build(name: options.name, options: options, asSystem: asSystem)
		
		let runningIP = try Self.launch(asSystem: asSystem, options: options, waitIPTimeout: waitIPTimeout, startMode: startMode)

		return "VM launched \(options.name) with IP: \(runningIP)"
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			let message = try await Self.buildAndLaunchVM(asSystem: asSystem, options: options, waitIPTimeout: waitIPTimeout, startMode: .service)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.message = message
				}
			}
		}
	}

}
