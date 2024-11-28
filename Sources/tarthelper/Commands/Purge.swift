import ArgumentParser
import Dispatch
import SwiftDate

protocol PruneArguments {
	var entries: String { get }
	var olderThan: UInt? { get }
	var spaceBudget: UInt? { get }
}

struct Purge: AsyncParsableCommand, PruneArguments {
	static var configuration = CommandConfiguration(abstract: "Purge caches or local VMs")

	@Option(help: ArgumentHelp("Entries to remove: \"caches\" targets caches and \"vms\" targets local VMs."))
	var entries: String = "caches"

	@Option(help: ArgumentHelp("Remove entries that were last accessed more than n days ago",
	                           discussion: "For example, --older-than=7 will remove entries that weren't accessed by Tart in the last 7 days.",
	                           valueName: "n"))
	var olderThan: UInt?

	@Option(help: ArgumentHelp("Remove the least recently used entries that do not fit the specified space size budget n, expressed in gigabytes",
	                           discussion: "For example, --space-budget=50 will effectively shrink all entries to a total size of 50 gigabytes.",
	                           valueName: "n"))
	var spaceBudget: UInt?

	mutating func validate() throws {
		if olderThan == nil && spaceBudget == nil {
			throw ValidationError("at least one pruning criteria must be specified")
		}
	}

	mutating func run() async throws {
		try await PruneHandler.prune(direct: true, self)
	}
}
