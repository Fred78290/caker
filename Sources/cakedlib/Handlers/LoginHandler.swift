import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration

public struct LoginHandler {
	@discardableResult
	public static func login(host: String, username: String, password: String, insecure: Bool, noValidate: Bool, direct: Bool, runMode: Utils.RunMode) -> String {
		var arguments: [String] = [host, "--user=\(username)", "--password-stdin"]

		if insecure {
			arguments.append("--insecure")
		}

		if insecure {
			arguments.append("--no-validate")
		}

		do {
			return try Shell.runTart(command: "login", arguments: arguments, direct: direct, input: password, runMode: runMode)
		} catch {
			return "\(error)"
		}
	}
}
