import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration
import ContainerizationOCI
import Synchronization

public struct LoginHandler {
	@discardableResult
	public static func login(host: String, username: String, password: String, insecure: Bool, noValidate: Bool, direct: Bool, runMode: Utils.RunMode) -> String {
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
		
		let semaphore = DispatchSemaphore(value: 0)
		var result = "Login succeeded"

		Task {
			do {
				try await client.ping()
				try keychain.save(domain: server, username: username, password: password)
				semaphore.signal()
			} catch {
				result = "Failed to login: \(error)"
			}
		}
		
		semaphore.wait()
		
		return result
	}
}
