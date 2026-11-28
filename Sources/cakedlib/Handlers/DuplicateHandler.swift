
import CakeAgentLib
import Foundation
import GRPCLib
import NIOCore
import Virtualization

public struct DuplicateHandler {
	public static var cancelledReason: String {
		TemporaryVMCancellation.cancelledReason
	}

	public static func duplicate(vmURL: URL, to: String, resetMacAddress: Bool, runMode: Utils.RunMode, cancellation: TemporaryVMCancellation? = nil) -> DuplicatedReply {
		guard let location = try? VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode) else {
			return DuplicatedReply(from: vmURL.absoluteString, to: to, duplicated: false, reason: String(localized: "Source vm not found"))
		}

		return duplicate(location: location, to: to, resetMacAddress: resetMacAddress, runMode: runMode, cancellation: cancellation)
	}

	public static func duplicate(from: String, to: String, resetMacAddress: Bool, runMode: Utils.RunMode, cancellation: TemporaryVMCancellation? = nil) -> DuplicatedReply {
		guard let location = try? StorageLocation(runMode: runMode).find(from) else {
			return DuplicatedReply(from: from, to: to, duplicated: false, reason: String(localized: "Source vm not found"))
		}

		return duplicate(location: location, to: to, resetMacAddress: resetMacAddress, runMode: runMode, cancellation: cancellation)
	}

	/// Cancellable form: cancelling the calling task kills and destroys the temporary VM and returns a
	/// reply with `duplicated == false` and `cancelledReason`.
	public static func duplicate(vmURL: URL, to: String, resetMacAddress: Bool, runMode: Utils.RunMode) async -> DuplicatedReply {
		await cancellable(runMode: runMode) { cancellation in
			duplicate(vmURL: vmURL, to: to, resetMacAddress: resetMacAddress, runMode: runMode, cancellation: cancellation)
		}
	}

	/// Cancellable form of `duplicate(from:to:resetMacAddress:runMode:)`, see `duplicate(vmURL:...) async`.
	public static func duplicate(from: String, to: String, resetMacAddress: Bool, runMode: Utils.RunMode) async -> DuplicatedReply {
		await cancellable(runMode: runMode) { cancellation in
			duplicate(from: from, to: to, resetMacAddress: resetMacAddress, runMode: runMode, cancellation: cancellation)
		}
	}

	private static func cancellable(runMode: Utils.RunMode, _ work: @escaping @Sendable (TemporaryVMCancellation) -> DuplicatedReply) async -> DuplicatedReply {
		await TemporaryVMCancellation.run(runMode: runMode, work)
	}

	public static func duplicate(location: VMLocation, to: String, resetMacAddress: Bool, runMode: Utils.RunMode, cancellation: TemporaryVMCancellation? = nil) -> DuplicatedReply {
		let storageLocation = StorageLocation(runMode: runMode)
		// The temporary copy being prepared; never the source VM, so a failure can only delete the copy.
		var temporary: VMLocation? = nil

		defer {
			temporary?.destroyTemporaryVirtualMachine(runMode: runMode)
		}

		do {
			// Check if the VM exists
			guard location.status == .stopped else {
				return DuplicatedReply(from: location.name, to: to, duplicated: false, reason: String(localized: "Source vm is running or paused"))
			}

			guard storageLocation.exists(to) == false else {
				return DuplicatedReply(from: location.name, to: to, duplicated: false, reason: String(localized: "Target vm already exists"))
			}

			try cancellation?.checkCancellation()

			let sourceConfig = try location.config()
			let tempLocation = try VMLocation.tempDirectory(runMode: runMode)

			temporary = tempLocation
			try cancellation?.register(tempLocation)

			_ = try location.copyTo(tempLocation)
			try cancellation?.checkCancellation()

			func resetMacAddress(_ location: VMLocation) throws -> CakeConfig {
				let config = try location.config()
				config.resetMacAddress()
				config.instanceID = "i-\(String(format: "%x", Int(Date().timeIntervalSince1970)))"
				config.imdsMacAddress = VZMACAddress.randomLocallyAdministered().string

				try config.save()

				return config
			}

			if sourceConfig.os == .linux && sourceConfig.useCloudInit {
				try TemplateHandler.cleanCloudInit(temporary: tempLocation, startMode: .background, runMode: runMode)
				try cancellation?.checkCancellation()
				try tempLocation.waitTemporaryVirtualMachineExit(runMode: runMode, cancellation: cancellation)
				try cancellation?.checkCancellation()

				// Change mac address and network mode
				let config = try resetMacAddress(tempLocation)

				// Rebuild a new cloud-init iso with new mac address and network mode
				let cdrom = URL(fileURLWithPath: cloudInitIso, relativeTo: tempLocation.configURL)
				let cloudInit = try CloudInit(
					plateform: config.configuredPlatform,
					userName: config.configuredUser,
					password: config.configuredPassword,
					mainGroup: config.configuredGroup,
					otherGroups: config.configuredGroups,
					clearPassword: config.clearPassword,
					sshAuthorizedKeyPath: config.sshPrivateKeyPath,
					vendorDataPath: nil,
					userDataPath: nil,
					networkConfigPath: nil,
					netIfnames: config.ifname,
					runMode: runMode)

				try? cdrom.delete()
				try cloudInit.createDefaultCloudInit(config: config, name: to, cdromURL: cdrom)
			} else {
				// Change mac address and network mode
				_ = try resetMacAddress(tempLocation)
			}

			if let cancellation {
				try cancellation.commit {
					try storageLocation.relocate(to, from: tempLocation)
				}
			} else {
				try storageLocation.relocate(to, from: tempLocation)
			}

			// Moved into place: nothing left to destroy.
			temporary = nil

			return DuplicatedReply(from: location.name, to: to, duplicated: true, reason: String(localized: "VM duplicated"))
		} catch {
			if error is CancellationError || cancellation?.isCancelled == true {
				Logger(self).info("Duplicate of \(location.name) to \(to) cancelled")

				return DuplicatedReply(from: location.name, to: to, duplicated: false, reason: Self.cancelledReason)
			}

			return DuplicatedReply(from: location.name, to: to, duplicated: false, reason: error.reason)
		}
	}
}
