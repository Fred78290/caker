import Foundation
import GRPCLib
import NIOCore

struct LaunchHandler: CakedCommandAsync {
	var options: BuildOptions
	var waitIPTimeout = 180

	private static func launch(runMode: Utils.RunMode, options: BuildOptions, waitIPTimeout: Int, startMode: StartHandler.StartMode) throws -> String {
		let vmLocation = try StorageLocation(runMode: runMode).find(options.name)
		let config = try vmLocation.config()

		return try StartHandler.startVM(on: Root.group.next(), vmLocation: vmLocation, config: config, waitIPTimeout: 180, startMode: startMode, runMode: runMode)
	}

	static func buildAndLaunchVM(runMode: Utils.RunMode, options: BuildOptions, waitIPTimeout: Int, startMode: StartHandler.StartMode) async throws -> String {
		try await BuildHandler.build(name: options.name, options: options, runMode: runMode)

		let runningIP = try Self.launch(runMode: runMode, options: options, waitIPTimeout: waitIPTimeout, startMode: startMode)

		return "VM launched \(options.name) with IP: \(runningIP)"
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			let message = try await Self.buildAndLaunchVM(runMode: runMode, options: options, waitIPTimeout: waitIPTimeout, startMode: .service)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.message = message
				}
			}
		}
	}

}
