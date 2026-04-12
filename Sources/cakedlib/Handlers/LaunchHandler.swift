import Foundation
import GRPCLib
import NIOCore
import CakeAgentLib

public struct LaunchHandler {
	public static func buildAndLaunchVM(runMode: Utils.RunMode, options: BuildOptions, waitIPTimeout: Int, startMode: StartHandler.StartMode, gcd: Bool, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> LaunchReply {
		let storageLocation: StorageLocation = StorageLocation(runMode: runMode)

		guard storageLocation.exists(options.name) == false else {
			return LaunchReply(name: options.name, ip: String.empty, launched: false, reason: String(localized: "VM already exists"))
		}

		let build = await BuildHandler.build(options: options, runMode: runMode, progressHandler: progressHandler)

		guard build.builded else {
			return LaunchReply(name: options.name, ip: String.empty, launched: false, reason: build.reason)
		}

		do {
			let reply = try StartHandler.startVM(on: Utilities.group.next(), location: storageLocation.find(options.name), screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: 180, startMode: startMode, gcd: gcd, runMode: runMode)

			return LaunchReply(name: reply.name, ip: reply.ip, launched: reply.started, reason: reply.reason)
		} catch {
			return LaunchReply(name: options.name, ip: String.empty, launched: false, reason: error.reason)
		}
	}
}
