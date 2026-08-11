import Foundation
import GRPCLib

/// Relocates the cake home directory (CAKE_HOME) to a new location on disk.
///
/// Only available for non-App Store builds: the App Store build is sandboxed and its cake home
/// is pinned to the app's App Group container, which cannot be moved.
public struct CakeHomeHandler {
	public static func currentHome(runMode: Utils.RunMode) throws -> URL {
		try Utils.getHome(runMode: runMode, createItIfNotExists: false)
	}

	/// Human readable reasons why a relocation is currently refused, empty when relocation is safe.
	public static func activeBlockers(runMode: Utils.RunMode) -> [String] {
		var blockers: [String] = []

		if ServiceHandler.isAgentRunning(runMode: runMode).running {
			blockers.append(String(localized: "the caked daemon is running"))
		}

		if let locations = try? StorageLocation(runMode: runMode).list() {
			let runningCount = locations.values.filter { $0.status.isRunning }.count

			if runningCount > 0 {
				blockers.append(String(localized: "\(runningCount) virtual machine(s) running"))
			}
		} else {
			// Be conservative: if we can't enumerate VMs (permissions/IO error), don't silently
			// treat that as "nothing running" — relocating out from under a VM we failed to see
			// would risk corrupting its disk.
			blockers.append(String(localized: "unable to determine whether any virtual machine is running"))
		}

		let runningNetworks = NetworksHandler.networks(all: true, runMode: runMode).networks.filter { $0.running }
		if runningNetworks.isEmpty == false {
			blockers.append(String(localized: "\(runningNetworks.count) network(s) running"))
		}

		return blockers
	}

	/// Moves the whole cake home directory to `newPath` and remembers the new location in
	/// `UserDefaults.shared` so subsequent `getHome` calls resolve to it.
	@discardableResult
	public static func relocate(to newPath: String, runMode: Utils.RunMode) throws -> URL {
		guard Bundle.isApplicationSandboxed == false else {
			throw ServiceError(String(localized: "Relocating the cake home directory is not supported in the App Store build"))
		}

		let blockers = Self.activeBlockers(runMode: runMode)
		guard blockers.isEmpty else {
			throw ServiceError(String(localized: "Cannot relocate cake home while caked is active (\(blockers.joined(separator: ", "))). Stop the caked service, all virtual machines and all networks first."))
		}

		let trimmed = newPath.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.isEmpty == false else {
			throw ServiceError(String(localized: "The new cake home path must not be empty"))
		}

		let destination = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL
		guard destination.path(percentEncoded: false).hasPrefix("/") else {
			throw ServiceError(String(localized: "The new cake home path must be an absolute path"))
		}

		let source = try Utils.getHome(runMode: runMode, createItIfNotExists: false).resolvingSymlinksInPath()

		guard try source.exists() else {
			throw ServiceError(String(localized: "Current cake home directory does not exist: \(source.path(percentEncoded: false))"))
		}

		guard destination.resolvingSymlinksInPath() != source else {
			throw ServiceError(String(localized: "The new cake home path is the same as the current one"))
		}

		let sourcePrefix = source.path(percentEncoded: false).hasSuffix("/") ? source.path(percentEncoded: false) : source.path(percentEncoded: false) + "/"
		guard destination.path(percentEncoded: false).hasPrefix(sourcePrefix) == false else {
			throw ServiceError(String(localized: "The new cake home path cannot be located inside the current cake home directory"))
		}

		let fm = FileManager.default
		let destinationParent = destination.deletingLastPathComponent()
		let destinationExists = try destination.exists()
		// Used to detect same-volume vs. cross-volume moves. When the destination itself already
		// exists (e.g. the user picked the root of a mounted external volume such as
		// /Volumes/ExternalSSD) it must be stat'ed directly: its parent (/Volumes) can be on a
		// completely different volume than the mount point itself.
		let destinationVolumeReference = destinationExists ? destination : destinationParent

		if destinationExists {
			var isDirectory: ObjCBool = false
			fm.fileExists(atPath: destination.path(percentEncoded: false), isDirectory: &isDirectory)

			guard isDirectory.boolValue else {
				throw ServiceError(String(localized: "Destination path exists and is not a directory: \(destination.path(percentEncoded: false))"))
			}

			// Ignore hidden entries: the root of a freshly mounted volume commonly carries
			// invisible system metadata (.Spotlight-V100, .fseventsd, .Trashes, ...), which
			// shouldn't disqualify it as a relocation target.
			guard try fm.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).isEmpty else {
				throw ServiceError(String(localized: "Destination directory is not empty: \(destination.path(percentEncoded: false))"))
			}
		} else {
			guard fm.fileExists(atPath: destinationParent.path(percentEncoded: false)) else {
				throw ServiceError(String(localized: "Parent directory does not exist: \(destinationParent.path(percentEncoded: false))"))
			}
		}

		let sourceDevice = Self.deviceID(for: source)
		let destinationDevice = Self.deviceID(for: destinationVolumeReference)

		if let sourceDevice, let destinationDevice, sourceDevice == destinationDevice {
			if destinationExists {
				try destination.delete()
			}

			try fm.moveItem(at: source, to: destination)
		} else {
			try Self.relocateAcrossVolumes(source: source, destination: destination, destinationExists: destinationExists, stagingParent: destinationVolumeReference)
		}

		CakedKeyConfig.cakeHome.set(destination.path(percentEncoded: false))
		Utils.resetHomeCache()

		return destination
	}

	/// Copies the source directory tree to the destination volume, verifies the copy, then
	/// removes the original. Used whenever source and destination are not on the same volume,
	/// since a rename(2) cannot cross filesystem boundaries.
	///
	/// `stagingParent` is a directory already known to be on the destination volume: either the
	/// destination's parent (when the destination itself does not exist yet) or the destination
	/// directory itself (when the user picked an already-existing, empty directory such as the
	/// root of a mounted volume, whose *parent* may well be on a different volume).
	private static func relocateAcrossVolumes(source: URL, destination: URL, destinationExists: Bool, stagingParent: URL) throws {
		let fm = FileManager.default
		let requiredAllocatedBytes = try source.allocatedSizeBytes()
		let requiredLogicalBytes = try source.sizeBytes()
		let availableBytes = try Self.availableCapacity(at: stagingParent)

		guard availableBytes > requiredAllocatedBytes else {
			throw ServiceError(
				String(
					localized:
						"Not enough free space at destination: need \(ByteCountFormatter.string(fromByteCount: Int64(requiredAllocatedBytes), countStyle: .file)), only \(ByteCountFormatter.string(fromByteCount: Int64(availableBytes), countStyle: .file)) available"
				))
		}

		let staging = stagingParent.appendingPathComponent(".relocating-\(UUID().uuidString.prefix(8))", isDirectory: true)

		try? fm.removeItem(at: staging)

		do {
			try fm.copyItem(at: source, to: staging)
		} catch {
			try? fm.removeItem(at: staging)
			throw ServiceError(String(localized: "Failed to copy cake home to the new volume: \(error.reason)"))
		}

		do {
			// Compare apparent (logical) size rather than allocated size: block allocation can
			// legitimately differ across filesystems (compression, block size, sparseness), but
			// the copied byte content must match exactly.
			let copiedLogicalBytes = try staging.sizeBytes()
			guard copiedLogicalBytes == requiredLogicalBytes else {
				throw ServiceError(String(localized: "Copy verification failed: expected \(requiredLogicalBytes) bytes, found \(copiedLogicalBytes)"))
			}

			if destinationExists {
				// staging is nested inside the already-existing destination: promote its
				// children up one level instead of renaming staging itself over destination.
				for item in try fm.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
					try fm.moveItem(at: item, to: destination.appendingPathComponent(item.lastPathComponent))
				}

				try fm.removeItem(at: staging)
			} else {
				try fm.moveItem(at: staging, to: destination)
			}
		} catch {
			try? fm.removeItem(at: staging)
			throw error
		}

		// Best-effort: the data is already safe on the new volume, so a failure to clean up
		// the old copy should not be reported as a relocation failure.
		try? fm.removeItem(at: source)
	}

	private static func availableCapacity(at url: URL) throws -> UInt64 {
		let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])

		guard let capacity = values.volumeAvailableCapacityForImportantUsage else {
			throw ServiceError(String(localized: "Unable to determine free space at \(url.path(percentEncoded: false))"))
		}

		return UInt64(capacity)
	}

	/// Returns the device ID of the filesystem backing `url`, walking up to the nearest existing
	/// ancestor when `url` itself does not exist yet. Used to detect whether a move crosses
	/// volumes, since `rename(2)` (and therefore `FileManager.moveItem`) cannot cross them.
	private static func deviceID(for url: URL) -> dev_t? {
		var candidate = url.standardizedFileURL
		let fm = FileManager.default

		while fm.fileExists(atPath: candidate.path(percentEncoded: false)) == false {
			let parent = candidate.deletingLastPathComponent()

			if parent == candidate {
				return nil
			}

			candidate = parent
		}

		var info = stat()
		guard stat(candidate.path(percentEncoded: false), &info) == 0 else {
			return nil
		}

		return info.st_dev
	}
}
