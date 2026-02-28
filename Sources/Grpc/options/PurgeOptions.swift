import ArgumentParser
import Foundation

public struct PurgeOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: "Purge caches or local VMs", aliases: ["prune"])

	public enum PurgeEntry: String, ExpressibleByArgument, CaseIterable {
		case both
		case caches
		case vms
	}

	@Option(help: ArgumentHelp("Entries to remove: \"caches\" targets caches and \"vms\" targets local VMs or boths."))
	public var entries: PurgeEntry = .caches

	@Option(
		help: ArgumentHelp(
			"Remove entries that were last accessed more than n days ago",
			discussion: "For example, --older-than=7 will remove entries that weren't accessed by caked in the last 7 days.",
			valueName: "n"))
	public var olderThan: UInt? = nil

	@Option(
		help: ArgumentHelp(
			"Remove the least recently used entries that do not fit the specified space size budget n, expressed in gigabytes",
			discussion: "For example, --space-budget=50 will effectively shrink all entries to a total size of 50 gigabytes.",
			valueName: "n"))
	public var spaceBudget: UInt? = nil

	public init() {
	}

	public func validate() throws {
		if olderThan == nil && spaceBudget == nil {
			throw ValidationError("at least one pruning criteria must be specified")
		}
	}

}
