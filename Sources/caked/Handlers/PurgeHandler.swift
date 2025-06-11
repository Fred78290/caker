import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import SwiftDate
import SystemConfiguration

struct PurgeHandler: CakedCommand {
	var options: PurgeOptions

	@discardableResult static func purge(direct: Bool, runMode: Utils.RunMode, options: PurgeOptions) throws -> String {
		var arguments: [String] = ["--entries=\(options.entries)"]

		if let olderThan = options.olderThan {
			arguments.append("--older-than=\(olderThan)")
		}

		if let spaceBudget = options.spaceBudget {
			arguments.append("--space-budget=\(spaceBudget)")
		}

		if options.entries == "caches" {
			let purgeableStorages = [
				try OCIImageCache(runMode: runMode),
				try CloudImageCache(runMode: runMode),
				try RawImageCache(runMode: runMode),
				try SimpleStreamsImageCache(name: "", runMode: runMode),
			]

			if let olderThan = options.olderThan {
				let olderThanInterval = Int(exactly: olderThan)!.days.timeInterval
				let olderThanDate = Date() - olderThanInterval

				try Self.purgeOlderThan(purgeableStorages: purgeableStorages, olderThanDate: olderThanDate)
			}

			if let spaceBudget = options.spaceBudget {
				try Self.purgeSpaceBudget(purgeableStorages: purgeableStorages, spaceBudgetBytes: UInt64(spaceBudget) * 1024 * 1024 * 1024)
			}
		}

		if Root.tartIsPresent {
			return try Shell.runTart(command: "prune", arguments: arguments, direct: direct, runMode: runMode)
		}

		return ""
	}

	static func purgeOlderThan(purgeableStorages: [PurgeableStorage], olderThanDate: Date) throws {
		let purgeables: [Purgeable] = try purgeableStorages.flatMap { try $0.purgeables() }

		try purgeables.filter { try $0.accessDate() <= olderThanDate }.forEach { try $0.delete() }
	}

	static func purgeSpaceBudget(purgeableStorages: [PurgeableStorage], spaceBudgetBytes: UInt64) throws {
		let purgeables: [Purgeable] =
			try purgeableStorages
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

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.vms = try Caked_VirtualMachineReply.with {
				$0.message = try Self.purge(direct: runMode.isSystem, runMode: runMode, options: self.options)
			}
		}
	}
}
