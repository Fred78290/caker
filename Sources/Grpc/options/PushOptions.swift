import ArgumentParser
import Foundation

public struct PushOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: "Push a VM to a registry")

	@Argument(help: "Local or remote VM name")
	public var localName: String

	@Argument(help: "Remote VM name(s)")
	public var remoteNames: [String]

	@Flag(help: "Connect to the OCI registry via insecure HTTP protocol")
	public var insecure: Bool = false

	@Option(
		help: ArgumentHelp(
			"Chunk size in MB if registry supports chunked uploads",
			discussion: """
				By default monolithic method is used for uploading blobs to the registry but some registries support a more efficient chunked method.
				For example, AWS Elastic Container Registry supports only chunks larger than 5MB but GitHub Container Registry supports only chunks smaller than 4MB. Google Container Registry on the other hand doesn't support chunked uploads at all.
				Please refer to the documentation of your particular registry in order to see if this option is suitable for you and what's the recommended chunk size.
				"""))
	public var chunkSize: Int = 0

	public init() {
	}
}
