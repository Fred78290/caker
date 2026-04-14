import ArgumentParser
import Foundation

public struct PushOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Push a VM to a registry"))

	@Argument(help: ArgumentHelp(String(localized: "Local or remote VM name")))
	public var localName: String

	@Argument(help: ArgumentHelp(String(localized: "Remote VM name(s)")))
	public var remoteNames: [String]

	@Flag(help: ArgumentHelp(String(localized: "Connect to the OCI registry via insecure HTTP protocol")))
	public var insecure: Bool = false

	@Option(help: ArgumentHelp(String(localized: "Network concurrency to use when pushing a local VM to the OCI-compatible registry")))
	public var concurrency: UInt = 4

	@Flag(help: ArgumentHelp(String(localized: "Push vm in foreground"), discussion: String(localized: "This option allow display window of running vm to debug it"), visibility: .hidden))
	public var foreground: Bool = false

	@Option(help: ArgumentHelp(String(localized: "Chunk size in MB if registry supports chunked uploads"), discussion: String(localized: "push_options_help")))
	public var chunkSize: Int = 0

	public init() {
	}
}
