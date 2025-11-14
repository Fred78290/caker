import ArgumentParser
import Foundation

public struct PullOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(
		abstract: "Pull a VM from a registry",
		discussion: """
			Pulls a virtual machine from a remote OCI-compatible registry. Supports authorization via Keychain (see "cakectl login --help"),
			"""
	)

	@Argument(help: "image name")
	public var image: String

	@Argument(help: "VM name")
	public var name: String

	@Flag(help: "Connect to the OCI registry via insecure HTTP protocol")
	public var insecure: Bool = false

	@Option(help: "Network concurrency to use when pulling a remote VM from the OCI-compatible registry")
	public var concurrency: UInt = 4

	@Flag(help: .hidden)
	public var deduplicate: Bool = false

	public init() {
	}
}
