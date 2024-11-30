import ArgumentParser
import Dispatch
import Foundation
import Compression
import GRPCLib
import GRPC

struct Push: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Push a VM to a registry")

	@Argument(help: "local or remote VM name")
	var localName: String

	@Argument(help: "remote VM name(s)")
	var remoteNames: [String]

	@Flag(help: "connect to the OCI registry via insecure HTTP protocol")
	var insecure: Bool = false

	@Option(help: "network concurrency to use when pushing a local VM to the OCI-compatible registry")
	var concurrency: UInt = 4

	@Option(help: ArgumentHelp("chunk size in MB if registry supports chunked uploads",
	                           discussion: """
	                           By default monolithic method is used for uploading blobs to the registry but some registries support a more efficient chunked method.
	                           For example, AWS Elastic Container Registry supports only chunks larger than 5MB but GitHub Container Registry supports only chunks smaller than 4MB. Google Container Registry on the other hand doesn't support chunked uploads at all.
	                           Please refer to the documentation of your particular registry in order to see if this option is suitable for you and what's the recommended chunk size.
	                           """))
	var chunkSize: Int = 0

	@Option(help: .hidden)
	var diskFormat: String = "v2"

	@Flag(help: ArgumentHelp("cache pushed images locally",
	                         discussion: "Increases disk usage, but saves time if you're going to pull the pushed images later."))
	var populateCache: Bool = false

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "push", arguments: arguments), callOptions: callOptions).response.wait()
	}
}
