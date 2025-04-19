import Foundation
import ArgumentParser
import NIOPortForwarding

public struct CloneOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(
		abstract: "Clone a VM",
		discussion: """
		Creates a local virtual machine by cloning either a remote or another local virtual machine.

		Due to copy-on-write magic in Apple File System, a cloned VM won't actually claim all the space right away.
		Only changes to a cloned disk will be written and claim new space. This also speeds up clones enormously.

		By default, Tart checks available capacity in Tart's home directory and tries to reclaim minimum possible storage for the cloned image
		to fit. This behaviour is called "automatic pruning" and can be disabled by setting TART_NO_AUTO_PRUNE environment variable.
		"""
	)

	@Argument(help: "source VM name")
	public var sourceName: String

	@Argument(help: "new VM name")
	public var newName: String

	@Flag(help: "connect to the OCI registry via insecure HTTP protocol")
	public var insecure: Bool = false

	@Option(help: "network concurrency to use when pulling a remote VM from the OCI-compatible registry")
	public var concurrency: UInt = 4

	@Flag(help: .hidden)
	public var deduplicate: Bool = false

	public init() {
	}

	public func validate() throws {
		if concurrency < 1 {
			throw ValidationError("network concurrency cannot be less than 1")
		}

		if newName.contains("/") {
			throw ValidationError("<new-name> should be a local name")
		}

		if concurrency < 1 {
			throw ValidationError("network concurrency cannot be less than 1")
		}
	}
}
