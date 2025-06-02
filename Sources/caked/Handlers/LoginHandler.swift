import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration

struct LoginHandler: CakedCommand {
	let request: Caked_LoginRequest

	@discardableResult static func login(host: String, username: String, password: String, insecure: Bool, noValidate: Bool, direct: Bool, runMode: Utils.RunMode) throws -> String {
		var arguments: [String] = [host, "--user=\(username)", "--password-stdin"]

		if insecure {
			arguments.append("--insecure")
		}

		if insecure {
			arguments.append("--no-validate")
		}

		return try Shell.runTart(command: "login", arguments: arguments, direct: direct, input: password, runMode: runMode)
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.tart = try Caked_TartReply.with {
				$0.message = try Self.login(host: self.request.host, username: self.request.username, password: self.request.password, insecure: self.request.insecure, noValidate: self.request.insecure, direct: false, runMode: runMode)
			}
		}
	}
}
