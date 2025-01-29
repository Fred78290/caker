import ArgumentParser
import Foundation
import SystemConfiguration
import NIOCore

struct LoginHandler: CakedCommand {
	var username: String
	var password: String
	var insecure: Bool = false
	var noValidate: Bool = false

	@discardableResult static func login(username: String, password: String, insecure: Bool, noValidate: Bool, direct: Bool) throws -> String {
		var arguments: [String] = ["--user=\(username)", "--password-stdin"]

		if insecure {
			arguments.append("--insecure")
		}

		if insecure {
			arguments.append("--no-validate")
		}

		return try Shell.runTart(command: "login", arguments: arguments, direct: direct, input: password)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		on.submit {
			return try Self.login(username: self.username, password: password, insecure: insecure, noValidate: insecure, direct: false)
		}
	}
}
