import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import Shout
import NIOCore

struct StopHandler: CakedCommand {
	var name: String
	var force: Bool = false

	static func stopVM(name: String, force: Bool, asSystem: Bool) async throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)
		let config = try vmLocation.config()
		let home = try Home(asSystem: asSystem)

		if vmLocation.status != .running {
			throw ServiceError("vm \(name) is not running")
		}

		if force || config.useCloudInit == false {
			return try Shell.runTart(command: "stop", arguments: [name])
		}

		guard let ip = try? await WaitIPHandler.waitIP(name: name, wait: 60, asSystem: asSystem) else {
			return try Shell.runTart(command: "stop", arguments: [name])
		}

		let ssh = try SSH(host: ip)
		try ssh.authenticate(username: config.configuredUser, privateKey: home.sshPrivateKey.path(), publicKey: home.sshPublicKey.path(), passphrase: "")
		try ssh.execute("sudo shutdown now")

		return "stopped \(name)"
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		on.makeFutureWithTask {
			return try await StopHandler.stopVM(name: self.name, force: self.force, asSystem: runAsSystem)
		}
	}
}
