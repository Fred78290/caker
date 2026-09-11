import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore

public struct MountHandler {
	public static func Mount(_ mode: VMRunServiceMode, location: VMLocation, mounts: DirectorySharingAttachments, runMode: Utils.RunMode) -> MountInfos {
		do {
			guard let client = try mode.client(location: location, runMode: runMode) else {
				return MountInfos(success: false, reason: String(localized: "VM service is not running"), mounts: [])
			}

			return try client.mount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
		} catch {
			return MountInfos(success: false, reason: error.reason, mounts: [])
		}
	}

	public static func Umount(_ mode: VMRunServiceMode, location: VMLocation, mounts: DirectorySharingAttachments, runMode: Utils.RunMode) -> MountInfos {
		do {
			guard let client = try mode.client(location: location, runMode: runMode) else {
				return MountInfos(success: false, reason: String(localized: "VM service is not running"), mounts: [])
			}

			return try client.umount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
		} catch {
			return MountInfos(success: false, reason: error.reason, mounts: [])
		}
	}
}
