import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore

public struct MountHandler {
	public static func VncURL(_ mode: VMRunServiceMode, location: VMLocation, runMode: Utils.RunMode) throws -> URL? {
		return try createVMRunServiceClient(mode, location: location, runMode: runMode).vncURL()
	}

	public static func Mount(_ mode: VMRunServiceMode, location: VMLocation, mounts: DirectorySharingAttachments, runMode: Utils.RunMode) throws -> MountInfos {
		return try createVMRunServiceClient(mode, location: location, runMode: runMode).mount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
	}

	public static func Umount(_ mode: VMRunServiceMode, location: VMLocation, mounts: DirectorySharingAttachments, runMode: Utils.RunMode) throws -> MountInfos {
		return try createVMRunServiceClient(mode, location: location, runMode: runMode).umount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
	}
}
