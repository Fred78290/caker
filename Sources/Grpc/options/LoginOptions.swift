import ArgumentParser
import Foundation
import NIOPortForwarding

public struct LoginOptions: ParsableArguments {
	@Argument(help: ArgumentHelp(String(localized: "Host")))
	public var host: String

	@Option(help: ArgumentHelp(String(localized: "Username")))
	public var username: String? = nil

	@Option(help: ArgumentHelp(String(localized: "Password")))
	public var password: String? = nil

	@Flag(help: ArgumentHelp(String(localized: "Password from stdin")))
	public var passwordStdin: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "Connect to the OCI registry via insecure HTTP protocol")))
	public var insecure: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "Skip validation of the registry's credentials before logging-in")))
	public var noValidate: Bool = false

	public init() {
	}

	public func validate() throws {
		let usernameProvided = username != nil
		let passwordProvided = password != nil

		if !usernameProvided {
			throw ValidationError(String(localized: "--username is required"))
		}

		if passwordProvided && passwordStdin {
			throw ValidationError(String(localized: "specify one of --password-stdin or --password not both"))
		}

		if usernameProvided != passwordProvided && usernameProvided != passwordStdin {
			throw ValidationError(String(localized: "both --username and --password-stdin or --password are required"))
		}
	}

}
