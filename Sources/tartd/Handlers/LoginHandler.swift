import Dispatch
import Foundation
import SwiftUI

struct LoginHandler: TartdCommand {
	var host: String
	var username: String?
	var passwordStdin: Bool = false
	var insecure: Bool = false
	var noValidate: Bool = false

	func run() async throws -> String {
		var arguments: [String] = []

		arguments.append(host)

		if let username = self.username {
			arguments.append(username)
		}

		if passwordStdin {
			arguments.append("--password-stdin")
		}

		if insecure {
			arguments.append("--insecure")
		}

		return try Shell.runTart(command: "login", arguments: arguments)
	}
}
