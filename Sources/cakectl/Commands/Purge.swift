import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Purge: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Purge OCI and IPSW caches or local VMs")

	@OptionGroup var options: Client.Options

	@Option(help: ArgumentHelp("Entries to remove: \"caches\" targets OCI and IPSW caches and \"vms\" targets local VMs."))
	var entries: String = "caches"

	@Option(help: ArgumentHelp("Remove entries that were last accessed more than n days ago",
	                           discussion: "For example, --older-than=7 will remove entries that weren't accessed by Tart in the last 7 days.",
	                           valueName: "n"))
	var olderThan: UInt?

	@Option(help: .hidden)
	var cacheBudget: UInt?

	@Option(help: ArgumentHelp("Remove the least recently used entries that do not fit the specified space size budget n, expressed in gigabytes",
	                           discussion: "For example, --space-budget=50 will effectively shrink all entries to a total size of 50 gigabytes.",
	                           valueName: "n"))
	var spaceBudget: UInt?

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.purge(Caked_PurgeRequest(command: self), callOptions: callOptions).response.wait()
	}
}
