import Foundation
import GRPCLib
import NIOCore
import Virtualization

public struct DuplicateHandler {
	public static func duplicate(from: String, to: String, resetMacAddress: Bool, startMode: StartHandler.StartMode, runMode: Utils.RunMode) -> DuplicatedReply {
		do {
			let storageLocation = StorageLocation(runMode: runMode)

			guard var fromLocation = try? storageLocation.find(from) else {
				return DuplicatedReply(from: from, to: to, duplicated: false, reason: "Source vm not found")
			}

			// Check if the VM exists
			guard fromLocation.status == .stopped else {
				return DuplicatedReply(from: from, to: to, duplicated: false, reason: "Source vm is running or paused")
			}

			guard storageLocation.exists(to) == false else {
				return DuplicatedReply(from: from, to: to, duplicated: false, reason: "Target vm already exists")
			}

			var config = try fromLocation.config()

			defer {
				try? fromLocation.delete()
			}

			func resetMacAddress(_ location: VMLocation) throws -> CakeConfig {
				let config = try fromLocation.config()
				config.resetMacAddress()
				config.instanceID = "i-\(String(format: "%x", Int(Date().timeIntervalSince1970)))"

				try config.save()

				return config
			}

			if config.os == .linux && config.useCloudInit {
				fromLocation = try TemplateHandler.cleanCloudInit(source: fromLocation, config: config, startMode: startMode, runMode: runMode)

				// Change mac address and network mode
				config = try resetMacAddress(fromLocation)

				// Rebuild a new cloud-init iso with new mac address and network mode
				let cdrom = URL(fileURLWithPath: cloudInitIso, relativeTo: fromLocation.diskURL)
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
				fromLocation = try fromLocation.duplicateTemporary(runMode: runMode)
				
				// Change mac address and network mode
				config = try resetMacAddress(fromLocation)
			}

			try storageLocation.relocate(to, from: fromLocation)

			return DuplicatedReply(from: from, to: to, duplicated: true, reason: "VM duplicated")
		} catch {
			return DuplicatedReply(from: from, to: to, duplicated: false, reason: "\(error)")
		}
	}
}
