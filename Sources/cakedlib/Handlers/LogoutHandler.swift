import ArgumentParser
import ContainerizationOCI
import Foundation
import GRPCLib
import NIOCore

public struct LogoutHandler {
	@discardableResult
	public static func logout(host: String, direct: Bool, runMode: Utils.RunMode) -> LogoutReply {
		do {
			let keychain = KeychainHelper(id: Utilities.keychainID)

			try keychain.delete(domain: host)

			return LogoutReply(success: true, message: "Logged out")
		} catch {
			return LogoutReply(success: false, message: "\(error)")
		}
	}
}
