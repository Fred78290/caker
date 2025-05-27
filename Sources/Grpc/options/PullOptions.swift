import ArgumentParser
import Foundation

public struct PullOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(
		abstract: "Pull a VM from a registry",
		discussion: """
			Pulls a virtual machine from a remote OCI-compatible registry. Supports authorization via Keychain (see "tart login --help"),
			Docker credential helpers defined in ~/.docker/config.json or via TART_REGISTRY_USERNAME/TART_REGISTRY_PASSWORD environment variables.

			By default, Tart checks available capacity in Tart's home directory and tries to reclaim minimum possible storage for the remote image
			to fit. This behaviour is called "automatic pruning" and can be disabled by setting TART_NO_AUTO_PRUNE environment variable.
			"""
	)

	@Argument(help: "remote VM name")
	public var remoteName: String

	@Flag(help: "Connect to the OCI registry via insecure HTTP protocol")
	public var insecure: Bool = false

	@Option(help: "Network concurrency to use when pulling a remote VM from the OCI-compatible registry")
	public var concurrency: UInt = 4

	@Flag(help: .hidden)
	public var deduplicate: Bool = false

	public init() {
	}

	public func arguments() -> [String] {
		var args: [String] = [remoteName]

		if insecure {
			args.append("--insecure")
		}

		if concurrency > 0 {
			args.append("--concurrency")
			args.append("\(concurrency)")
		}

		if deduplicate {
			args.append("--deduplicate")
		}

		return args
	}
}
