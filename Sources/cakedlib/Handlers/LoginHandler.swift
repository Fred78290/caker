import ArgumentParser
import ContainerizationOCI
import Foundation
import GRPCLib
import NIOCore
import Synchronization
import SystemConfiguration

public struct LoginHandler {
	@discardableResult
	public static func login(host: String, username: String, password: String, insecure: Bool, noValidate: Bool, direct: Bool, runMode: Utils.RunMode) async -> LoginReply {
		let keychain = KeychainHelper(id: Utilities.keychainID)
		let server = Reference.resolveDomain(domain: host)
		let scheme = insecure ? "http" : "https"
		let client = RegistryClient(
			host: server,
			scheme: scheme,
			authentication: BasicAuthentication(username: username, password: password),
			retryOptions: .init(
				maxRetries: 10,
				retryInterval: 300_000_000,
				shouldRetry: ({ response in
					response.status.code >= 500
				})
			)
		)

		do {
			try await client.ping()
			try keychain.save(domain: server, username: username, password: password)

			return LoginReply(success: true, message: "Login succeeded")
		} catch {
			return LoginReply(success: false, message: "\(error)")
		}
	}
}
