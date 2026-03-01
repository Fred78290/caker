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
			return try createVMRunServiceClient(mode, location: location, runMode: runMode).mount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)

		} catch {
			return MountInfos(success: false, reason: "\(error)", mounts: [])
		}
	}

	public static func Umount(_ mode: VMRunServiceMode, location: VMLocation, mounts: DirectorySharingAttachments, runMode: Utils.RunMode) -> MountInfos {
		do {
			return try createVMRunServiceClient(mode, location: location, runMode: runMode).umount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
		} catch {
			return MountInfos(success: false, reason: "\(error)", mounts: [])
		}
	}
}
