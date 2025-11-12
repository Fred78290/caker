import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import SystemConfiguration

public struct WaitIPHandler {
	public static func waitIP(name: String, wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) -> WaitIPReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)

			return WaitIPReply.init(name: name, ip: try location.waitIP(wait: wait, runMode: runMode, startedProcess: startedProcess), success: true, reason: "")
		} catch {
			return WaitIPReply.init(name: name, ip: "", success: false, reason: "\(error)")
		}
	}
}
