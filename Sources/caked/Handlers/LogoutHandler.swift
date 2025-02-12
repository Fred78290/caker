import ArgumentParser
import Foundation
import SystemConfiguration
import NIOCore
import GRPCLib

struct LogoutHandler: CakedCommand {
	let request: Caked_LogoutRequest

	@discardableResult static func logout(host: String, direct: Bool) throws -> String {
		return try Shell.runTart(command: "logout", arguments: [host], direct: direct)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		on.submit {
			return try Self.logout(host: self.request.host, direct: false)
		}
	}
}
