import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import SystemConfiguration

public struct WaitIPHandler {
	public static func waitIP(name: String, wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let vmLocation = try StorageLocation(runMode: runMode).find(name)

		return try vmLocation.waitIP(wait: wait, runMode: runMode, startedProcess: startedProcess)
	}
}
