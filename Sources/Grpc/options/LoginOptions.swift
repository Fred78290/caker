import Foundation
import ArgumentParser
import NIOPortForwarding

public struct LoginOptions: ParsableArguments {
	@Argument(help: "Host")
	public var host: String

	@Option(help: "Username")
	public var username: String? = nil

	@Option(help: "Password")
	public var password: String? = nil

	@Flag(help: "Password from stdin")
	public var passwordStdin: Bool = false

	@Flag(help: "Connect to the OCI registry via insecure HTTP protocol")
	public var insecure: Bool = false

	@Flag(help: "Skip validation of the registry's credentials before logging-in")
	public var noValidate: Bool = false

	public init() {
	}

	public func validate() throws {
		let usernameProvided = username != nil
		let passwordProvided = password != nil

		if !usernameProvided {
			throw ValidationError("--username is required")
		}

		if passwordProvided && passwordStdin {
			throw ValidationError("specify one of --password-stdin or --password not both")
		}

		if usernameProvided != passwordProvided && usernameProvided != passwordStdin {
			throw ValidationError("both --username and --password-stdin or --password are required")
		}
	}

}
