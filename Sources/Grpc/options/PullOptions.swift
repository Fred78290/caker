import ArgumentParser
import Foundation

public struct PullOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(
		commandName: "clone",
		abstract: "Clone a VM from a registry",
		discussion: """
			Pulls a virtual machine from a remote OCI-compatible registry. Supports authorization via Keychain (see "login --help"),
			"""
	)

	@Argument(help: "image name")
	public var image: String

	@Argument(help: "VM name")
	public var name: String

	@Flag(help: "Connect to the OCI registry via insecure HTTP protocol")
	public var insecure: Bool = false

	public init() {
	}
}
