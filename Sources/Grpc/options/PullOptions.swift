import ArgumentParser
import Foundation

public struct PullOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(
		commandName: "pull",
		abstract: String(localized: "Clone a VM from a registry"),
		discussion: String(localized: "Pulls a virtual machine from a remote OCI-compatible registry. Supports authorization via Keychain (see \"login --help\"),"),
		aliases: ["clone"]
	)

	@Argument(help: ArgumentHelp(String(localized: "image name")))
	public var image: String

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	public var name: String

	@Flag(help: ArgumentHelp(String(localized: "Connect to the OCI registry via insecure HTTP protocol")))
	public var insecure: Bool = false

	public init() {
	}
}
