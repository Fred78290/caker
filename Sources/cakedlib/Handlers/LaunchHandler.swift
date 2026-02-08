import Foundation
import GRPCLib
import NIOCore
import CakeAgentLib

public struct LaunchHandler {
	public static func buildAndLaunchVM(runMode: Utils.RunMode, options: BuildOptions, waitIPTimeout: Int, startMode: StartHandler.StartMode) async -> LaunchReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(options.name)
			let config = try location.config()

			let build = await BuildHandler.build(options: options, runMode: runMode, progressHandler: ProgressObserver.progressHandler)

			if build.builded {
				let reply = StartHandler.startVM(on: Utilities.group.next(), location: location, config: config, waitIPTimeout: 180, startMode: startMode, runMode: runMode)

				return LaunchReply(name: reply.name, ip: reply.ip, launched: reply.started, reason: reply.reason)
			}

			return LaunchReply(name: options.name, ip: "", launched: false, reason: build.reason)
		} catch {
			return LaunchReply(name: options.name, ip: "", launched: false, reason: "\(error)")
		}
	}
}
