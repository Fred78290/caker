import ArgumentParser
import Foundation
import GRPCLib
import NIOCore

public struct LogoutHandler {
	@discardableResult
	public static func logout(host: String, direct: Bool, runMode: Utils.RunMode) -> String {
		do {
			return try Shell.runTart(command: "logout", arguments: [host], direct: direct, runMode: runMode)
		} catch {
			return "\(error)"
		}
	}
}
