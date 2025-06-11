import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import Logging
import SwiftUI

struct Login: AsyncParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Login to a registry")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Login options")
	var login: LoginOptions

	mutating func run() async throws {
		if self.login.passwordStdin {
			self.login.password = readLine(strippingNewline: true)
		}

		Logger.appendNewLine(
			self.common.format.render(
				try LoginHandler.login(host: self.login.host, username: self.login.username!, password: self.login.password!, insecure: self.login.insecure, noValidate: self.login.noValidate, direct: true, runMode: self.common.runMode)))
	}
}
