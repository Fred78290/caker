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

	@Option(
		help: ArgumentHelp(String(localized: "Chunk size in MB if registry supports chunked uploads"),
			discussion: String(localized: """
				By default monolithic method is used for uploading blobs to the registry but some registries support a more efficient chunked method.
				For example, AWS Elastic Container Registry supports only chunks larger than 5MB but GitHub Container Registry supports only chunks smaller than 4MB. Google Container Registry on the other hand doesn't support chunked uploads at all.
				Please refer to the documentation of your particular registry in order to see if this option is suitable for you and what's the recommended chunk size.
				""")))
	public var chunkSize: Int = 0

	public init() {
	}
}
