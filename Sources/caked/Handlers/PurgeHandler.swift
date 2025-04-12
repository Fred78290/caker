import ArgumentParser
import Foundation
import SystemConfiguration
import NIOCore
import GRPCLib

struct PurgeHandler: CakedCommand, PurgeArguments {
	var entries: String = "caches"
	var olderThan: UInt?
	var spaceBudget: UInt?

	@discardableResult static func purge(direct: Bool, _ self: PurgeArguments) throws -> String {
		var arguments: [String] = [ self.entries ]

		if let olderThan = self.olderThan {
			arguments.append("--older-than=\(olderThan)")
		}

		if let spaceBudget = self.spaceBudget {
			arguments.append("--space-budget=\(spaceBudget)")
		}

		if self.entries == "caches" {
			let purgeableStorages = [try OCIImageCache(), try CloudImageCache(), try RawImageCache(), try SimpleStreamsImageCache(name: "")]

			if let olderThan = self.olderThan {
				let olderThanInterval = Int(exactly: olderThan)!.days.timeInterval
				let olderThanDate = Date() - olderThanInterval

				try Self.purgeOlderThan(purgeableStorages: purgeableStorages, olderThanDate: olderThanDate)
			}

			if let spaceBudget = self.spaceBudget {
				try Self.purgeSpaceBudget(purgeableStorages: purgeableStorages, spaceBudgetBytes: UInt64(spaceBudget) * 1024 * 1024 * 1024)
			}
		}

		if Root.tartIsPresent {
			return try Shell.runTart(command: "prune", arguments: arguments, direct: direct)
		}

		return ""
	}

	static func purgeOlderThan(purgeableStorages: [PurgeableStorage], olderThanDate: Date) throws {
		let purgeables: [Purgeable] = try purgeableStorages.flatMap { try $0.purgeables() }

		try purgeables.filter { try $0.accessDate() <= olderThanDate }.forEach { try $0.delete() }
	}

	static func purgeSpaceBudget(purgeableStorages: [PurgeableStorage], spaceBudgetBytes: UInt64) throws {
		let purgeables: [Purgeable] = try purgeableStorages
			.flatMap { try $0.purgeables() }
			.sorted { try $0.accessDate() > $1.accessDate() }

		var spaceBudgetBytes = spaceBudgetBytes
		var purgeablesToDelete: [Purgeable] = []

		for purgeable in purgeables {
			let purgeableSizeBytes = UInt64(try purgeable.allocatedSizeBytes())

			if purgeableSizeBytes <= spaceBudgetBytes {
				// Don't mark for deletion as
				// there's a budget available
				spaceBudgetBytes -= purgeableSizeBytes
			} else {
				// Mark for deletion
				purgeablesToDelete.append(purgeable)
			}
		}

		try purgeablesToDelete.forEach { try $0.delete() }
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.vms = try Caked_VirtualMachineReply.with {
				$0.message = try Self.purge(direct: asSystem, self)
			}
		}
	}
}
