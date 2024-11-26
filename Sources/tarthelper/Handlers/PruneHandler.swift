import ArgumentParser
import Foundation
import SystemConfiguration

struct PruneHandler: TartdCommand, PruneArguments {
	var entries: String = "caches"
	var olderThan: UInt?
	var spaceBudget: UInt?

	@discardableResult static func prune(direct: Bool, _ self: PruneArguments) async throws -> String {
		var arguments: [String] = [ self.entries ]

		if let olderThan = self.olderThan {
			arguments.append("--older-than=\(olderThan)")
		}

		if let spaceBudget = self.spaceBudget {
			arguments.append("--space-budget=\(spaceBudget)")
		}

		if self.entries == "caches" {
			let prunableStorages = [try CloudImageCache(), try RawImageCache(), try SimpleStreamsImageCache(name: "")]

			if let olderThan = self.olderThan {
				let olderThanInterval = Int(exactly: olderThan)!.days.timeInterval
				let olderThanDate = Date() - olderThanInterval

				try Self.pruneOlderThan(prunableStorages: prunableStorages, olderThanDate: olderThanDate)
			}

			if let spaceBudget = self.spaceBudget {
				try Self.pruneSpaceBudget(prunableStorages: prunableStorages, spaceBudgetBytes: UInt64(spaceBudget) * 1024 * 1024 * 1024)
			}
		}

		return try Shell.runTart(command: "prune", arguments: arguments, direct: direct)
	}

	static func pruneOlderThan(prunableStorages: [PurgeableStorage], olderThanDate: Date) throws {
		let purgeables: [Purgeable] = try prunableStorages.flatMap { try $0.purgeables() }

		try purgeables.filter { try $0.accessDate() <= olderThanDate }.forEach { try $0.delete() }
	}

	static func pruneSpaceBudget(prunableStorages: [PurgeableStorage], spaceBudgetBytes: UInt64) throws {
		let purgeables: [Purgeable] = try prunableStorages
			.flatMap { try $0.purgeables() }
			.sorted { try $0.accessDate() > $1.accessDate() }

		var spaceBudgetBytes = spaceBudgetBytes
		var purgeablesToDelete: [Purgeable] = []

		for prunable in purgeables {
			let prunableSizeBytes = UInt64(try prunable.allocatedSizeBytes())

			if prunableSizeBytes <= spaceBudgetBytes {
				// Don't mark for deletion as
				// there's a budget available
				spaceBudgetBytes -= prunableSizeBytes
			} else {
				// Mark for deletion
				purgeablesToDelete.append(prunable)
			}
		}

		try purgeablesToDelete.forEach { try $0.delete() }
	}

	func run(asSystem: Bool) async throws -> String {
		return try await Self.prune(direct: false, self)
	}
}
