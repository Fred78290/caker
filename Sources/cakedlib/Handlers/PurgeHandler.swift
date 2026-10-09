import ArgumentParser
import CakeAgentLib
import Foundation
import GRPCLib
import NIOCore
import SwiftDate

public struct PurgeHandler {
	@discardableResult
	public static func purge(direct: Bool, runMode: Utils.RunMode, options: PurgeOptions) -> PurgeReply {
		do {
			var purgeableStorages: [PurgeableStorage]

			if options.entries == .vms {
				purgeableStorages = [StorageLocation(runMode: runMode)]
			} else {
				purgeableStorages = [
					try OCIImageCache(runMode: runMode),
					try PurgeableContentStore(runMode: runMode),
					try CloudImageCache(runMode: runMode),
					try RawImageCache(runMode: runMode),
					try IsoCache(runMode: runMode),
					try SimpleStreamsImageCache(name: String.empty, runMode: runMode),
				]

				if options.entries != .caches {
					purgeableStorages.append(StorageLocation(runMode: runMode))
				}

				#if arch(arm64)
					purgeableStorages.append(try IPSWCache(runMode: runMode))
				#endif
			}

			if let olderThan = options.olderThan {
				let olderThanInterval = Int(exactly: olderThan)!.days.timeInterval
				let olderThanDate = Date() - olderThanInterval

				try Self.purgeOlderThan(purgeableStorages: purgeableStorages, olderThanDate: olderThanDate)
			}

			if let spaceBudget = options.spaceBudget {
				try Self.purgeSpaceBudget(purgeableStorages: purgeableStorages, spaceBudgetBytes: spaceBudget * GoB)
			}

			return PurgeReply(purged: true, reason: String(localized: "Purged"))
		} catch {
			return PurgeReply(purged: false, reason: error.reason)
		}
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
}
