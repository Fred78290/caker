import CakeAgentLib
//
//  AuthorizationHelperConnector.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/11/2026.
//
import Foundation
import GRPCLib
import ServiceManagement

/// The helper tool can't be reached: not installed, not approved, not running or not signed like the caller.
/// Callers fall back to `sudo` on this error, and report any other one.
public struct AuthorizationHelperUnavailable: Error, LocalizedError {
	public let underlying: Error?

	public var errorDescription: String? {
		String(localized: "The privileged helper is not available")
	}
}

/// Resumes a continuation once: the error handler of an XPC proxy and its reply can both fire.
private final class OneShot<Value: Sendable>: @unchecked Sendable {
	private let lock = NSLock()
	private var continuation: CheckedContinuation<Value, Error>?

	init(_ continuation: CheckedContinuation<Value, Error>) {
		self.continuation = continuation
	}

	private func take() -> CheckedContinuation<Value, Error>? {
		self.lock.lock()
		defer { self.lock.unlock() }

		let continuation = self.continuation

		self.continuation = nil

		return continuation
	}

	func resume(returning value: Value) {
		self.take()?.resume(returning: value)
	}

	func resume(throwing error: Error) {
		self.take()?.resume(throwing: error)
	}
}

public final class DirectAuthorizationHelperConnector: @unchecked Sendable {
	public static let shared = DirectAuthorizationHelperConnector()

	private let log = Logger("DirectAuthorizationHelperConnector")
	private let lock = NSLock()
	private var authorization = Data()
	private var authorizationRef: AuthorizationRef?
	private var connection: NSXPCConnection?

	public init() {
		// Create our connection to the authorization system.
		//
		// If we can't create an authorization reference then the app is not going to be able to do
		// anything requiring authorization.  Generally this only happens when you launch the app in
		// some wacky, and typically unsupported, way.  In the debug build we flag that with an assert.
		// In the release build we continue with an empty authorization, which will cause all
		// authorized operations to fail.
		var authRef: AuthorizationRef?
		var extForm = AuthorizationExternalForm()
		var err = AuthorizationCreate(nil, nil, [], &authRef)
		if err == errAuthorizationSuccess, let authRef {
			err = AuthorizationMakeExternalForm(authRef, &extForm)
		}
		if err == errAuthorizationSuccess {
			authorization = withUnsafeBytes(of: &extForm) { Data($0) }
			authorizationRef = authRef
		}
		assert(err == errAuthorizationSuccess)

		// If we successfully connected to Authorization Services, add definitions for our default
		// rights (unless they're already in the database).
		if let authRef {
			AuthorizationHelperCommon.setupAuthorizationRights(authRef)
		}
	}

	private func currentConnection() -> NSXPCConnection {
		self.lock.lock()
		defer { self.lock.unlock() }

		if let connection = self.connection {
			return connection
		}

		let connection = NSXPCConnection(machServiceName: AuthorizationHelperCommon.kAuthorizationHelperToolMachServiceName, options: .privileged)
		connection.remoteObjectInterface = AuthorizationHelperCommon.makeInterface()
		connection.invalidationHandler = { [weak self, weak connection] in
			// If the connection gets invalidated then nil out our reference to it.
			// This ensures that we attempt to rebuild it the next time around.
			guard let self, let connection else { return }

			self.lock.lock()
			defer { self.lock.unlock() }

			if self.connection === connection {
				self.connection = nil
			}
		}
		connection.resume()
		self.connection = connection

		return connection
	}

	/// Sends one request to the helper tool and returns the reason of its reply. Throws `AuthorizationHelperUnavailable`
	/// when the helper can't be reached, and a `ServiceError` when it refused or failed.
	private func call(_ invoke: @escaping @Sendable (AuthorizationHelperProtocol, Data, @escaping @Sendable (AuthorizationHelperReply) -> Void) -> Void) async throws -> String {
		let connection = self.currentConnection()
		let authorization = self.authorization

		return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
			let once = OneShot(continuation)

			let proxy = connection.remoteObjectProxyWithErrorHandler { error in
				// 4097...4102 are the NSXPCConnection errors: interrupted, invalid, code signing requirement not met.
				let nsError = error as NSError

				if nsError.domain == NSCocoaErrorDomain, (4097...4102).contains(nsError.code) {
					once.resume(throwing: AuthorizationHelperUnavailable(underlying: error))
				} else {
					once.resume(throwing: error)
				}
			}

			guard let helper = proxy as? AuthorizationHelperProtocol else {
				once.resume(throwing: AuthorizationHelperUnavailable(underlying: nil))
				return
			}

			invoke(helper, authorization) { reply in
				if reply.success {
					once.resume(returning: reply.reason)
				} else {
					once.resume(throwing: ServiceError(reply.reason))
				}
			}
		}
	}

	/// Asks the user to authorize `command` (an administrator password for the rights that need one). The helper has no UI:
	/// it only checks that the authorization it receives already holds the right, so this must run first.
	private func preAuthorize(_ command: Selector) async throws {
		guard let authorizationRef = self.authorizationRef, let right = AuthorizationHelperCommon.authorizationRight(for: command) else {
			throw ServiceError(String(localized: "Unable to authorize the privileged helper"))
		}

		nonisolated(unsafe) let reference = authorizationRef

		let status: OSStatus = await withCheckedContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				let status = right.withCString { name -> OSStatus in
					var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)

					return withUnsafeMutablePointer(to: &item) { items in
						var rights = AuthorizationRights(count: 1, items: items)

						return AuthorizationCopyRights(reference, &rights, nil, [.interactionAllowed, .extendRights, .preAuthorize], nil)
					}
				}

				continuation.resume(returning: status)
			}
		}

		guard status == errAuthorizationSuccess else {
			throw ServiceError(String(localized: "The privileged helper was not authorized (\(status))"))
		}
	}

	/// State of the helper daemon registered by `install()`.
	public static var daemonStatus: SMAppService.Status {
		SMAppService.daemon(plistName: "com.aldunelabs.caker.authorization.plist").status
	}

	/// Registers the privileged helper daemon bundled in `Contents/Library/LaunchDaemons`. Does nothing once it is
	/// registered, or when this build doesn't ship it (not running from an app bundle).
	public static func install() -> Bool {
		let service = SMAppService.daemon(plistName: "com.aldunelabs.caker.authorization.plist")

		// Service is already installed and running, nothing to do.
		guard service.status != .enabled else {
			return true
		}

		if service.status == .requiresApproval {
			// The user must approve the daemon in System Settings > General > Login Items.
			SMAppService.openSystemSettingsLoginItems()
			return false
		}

		do {
			try service.register()
		} catch {
			Logger(self).error("Unable to register the privileged helper: \(error)")
		}

		if service.status == .requiresApproval {
			// The user must approve the daemon in System Settings > General > Login Items.
			SMAppService.openSystemSettingsLoginItems()

			return false
		}

		return true
	}

	/// Runs `body` against the shared helper connection. Returns `nil` when the helper is not an option here (sandboxed,
	/// App Store build, system run mode, or helper unreachable), so the caller can use `sudo` instead; real failures are thrown.
	public static func viaHelper<T: Sendable>(runMode: Utils.RunMode, _ body: @escaping @Sendable (DirectAuthorizationHelperConnector) async throws -> T) async throws -> T? {
		#if !APPSTORE || USE_AUTHORIZATION_HELPER
			// The helper works on the calling user's cake home only. A sandboxed process is the very reason for it to exist (it can't
			// run a network, nor reach what root created), and root itself, the helper's own children included, never asks it.
			guard runMode.isSystem == false, geteuid() != 0 else {
				return nil
			}

			do {
				return try await body(Self.shared)
			} catch let error as AuthorizationHelperUnavailable {
				Logger("DirectAuthorizationHelperConnector").debug("Privileged helper unavailable, using sudo: \(error.underlying.map { "\($0)" } ?? "no proxy")")

				return nil
			}
		#else
			return nil
		#endif
	}

	/// Blocking variant of `viaHelper` for synchronous callers. Don't call it from a Swift Concurrency actor.
	public static func viaHelperSync<T: Sendable>(runMode: Utils.RunMode, _ body: @escaping @Sendable (DirectAuthorizationHelperConnector) async throws -> T) throws -> T? {
		try Task.sync {
			try await viaHelper(runMode: runMode, body)
		}
	}

	public func startNetwork(networkName: String, runMode: Utils.RunMode) async throws -> StartedNetworkReply {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)
		let reason = try await call { helper, authorization, reply in
			helper.startNetwork(authorization: authorization, cakeHome: home, networkName: networkName, withReply: reply)
		}

		return StartedNetworkReply(name: networkName, started: true, reason: reason)
	}

	/// The reply of a network operation: the JSON the `caked networks` command printed, decoded as that command would have rendered it.
	private func decode<T: Decodable>(_ type: T.Type, from reason: String) throws -> T {
		do {
			return try JSONDecoder().decode(type, from: Data(reason.utf8))
		} catch {
			// The command reported something else than the reply (a message instead of the structure): show it as it is.
			throw ServiceError(reason)
		}
	}

	private func networkOptions(_ network: VZSharedNetwork, includeMode: Bool) -> NetworkOptions {
		var options: [String: Any] = [
			"gateway": network.dhcpStart,
			"dhcp-end": network.dhcpEnd,
			"netmask": network.netmask,
			"interface-id": network.interfaceID,
			"dns": network.dns ?? false,
		]

		if includeMode {
			options["mode"] = network.mode == .host ? "host" : "shared"
		}

		if let lease = network.dhcpLease {
			options["dhcp-lease"] = Int(lease)
		}

		if network.nat66Prefix.isEmpty == false {
			options["nat66-prefix"] = network.nat66Prefix
		}

		return NetworkOptions(values: options)
	}

	/// Options for the helper: a property list, which is not `Sendable` for the compiler though nothing mutates it once built.
	private struct NetworkOptions: @unchecked Sendable {
		let values: [String: Any]
	}

	public func createNetwork(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) async throws -> CreatedNetworkReply {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)
		let options = self.networkOptions(network, includeMode: true)
		let reason = try await call { helper, authorization, reply in
			helper.createNetwork(authorization: authorization, cakeHome: home, networkName: networkName, options: options.values, withReply: reply)
		}

		return try self.decode(CreatedNetworkReply.self, from: reason)
	}

	/// `network` is the whole configuration the network must have afterwards, not only what changed.
	public func configureNetwork(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) async throws -> ConfiguredNetworkReply {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)
		let options = self.networkOptions(network, includeMode: false)
		let reason = try await call { helper, authorization, reply in
			helper.configureNetwork(authorization: authorization, cakeHome: home, networkName: networkName, options: options.values, withReply: reply)
		}

		return try self.decode(ConfiguredNetworkReply.self, from: reason)
	}

	public func restartNetwork(networkName: String, runMode: Utils.RunMode) async throws -> String {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)

		return try await call { helper, authorization, reply in
			helper.restartNetwork(authorization: authorization, cakeHome: home, networkName: networkName, withReply: reply)
		}
	}

	public func stopNetwork(networkName: String, runMode: Utils.RunMode) async throws -> StoppedNetworkReply {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)
		let reason = try await call { helper, authorization, reply in
			helper.stopNetwork(authorization: authorization, cakeHome: home, networkName: networkName, withReply: reply)
		}

		return try self.decode(StoppedNetworkReply.self, from: reason)
	}

	public func deleteNetwork(networkName: String, runMode: Utils.RunMode) async throws -> DeleteNetworkReply {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)
		let reason = try await call { helper, authorization, reply in
			helper.deleteNetwork(authorization: authorization, cakeHome: home, networkName: networkName, withReply: reply)
		}

		return try self.decode(DeleteNetworkReply.self, from: reason)
	}

	public func listNetwork(runMode: Utils.RunMode) async throws -> [BridgedNetwork] {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)
		let reason = try await call { helper, authorization, reply in
			helper.listNetwork(authorization: authorization, cakeHome: home, withReply: reply)
		}

		// The command prints the flat rendering of a network, not the Codable shape of `BridgedNetwork`.
		return try self.decode([FlatBridgedNetwork].self, from: reason).map(\.network)
	}

	public func infosNetwork(networkName: String, runMode: Utils.RunMode) async throws -> FlatBridgedNetwork {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)
		let reason = try await call { helper, authorization, reply in
			helper.infosNetwork(authorization: authorization, cakeHome: home, networkName: networkName, withReply: reply)
		}

		return try self.decode(FlatBridgedNetwork.self, from: reason)
	}

	public func setDHCPLease(leaseTime: Int32) async throws -> String {
		try await call { helper, authorization, reply in
			helper.setDHCPLease(authorization: authorization, leaseTime: leaseTime, withReply: reply)
		}
	}

	public func importVirtualMachine(arguments: [String], runMode: Utils.RunMode) async throws -> String {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)

		return try await call { helper, authorization, reply in
			helper.importVirtualMachine(authorization: authorization, cakeHome: home, arguments: arguments, withReply: reply)
		}
	}

	public func imdsRedirect(externalAddress: String, internalAddress: String, internalPort: Int, install: Bool, runMode: Utils.RunMode) async throws -> String {
		return try await call { helper, authorization, reply in
			helper.imdsRedirect(authorization: authorization, externalAddress: externalAddress, internalAddress: internalAddress, internalPort: internalPort, install: install, withReply: reply)
		}
	}

	/// Runs `caked networks run` as root on `fileHandle` (duplicated by XPC, the caller keeps its own copy) and returns its pid.
	public func runNetwork(arguments: [String], pidFile: URL, fileHandle: FileHandle, runMode: Utils.RunMode) async throws -> pid_t {
		let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)
		let pidFile = pidFile.path(percentEncoded: false)
		let reason = try await call { helper, authorization, reply in
			helper.runNetwork(authorization: authorization, cakeHome: home, arguments: arguments, pidFile: pidFile, fileHandle: fileHandle, withReply: reply)
		}

		guard let pid = pid_t(reason) else {
			throw ServiceError("Invalid pid '\(reason)' returned by the helper")
		}

		return pid
	}

	public func installPriviligedFiles(cakerPath: String) async throws -> String {
		try await self.preAuthorize(#selector(AuthorizationHelperProtocol.installPriviligedFiles(authorization:cakerPath:withReply:)))

		return try await call { helper, authorization, reply in
			helper.installPriviligedFiles(authorization: authorization, cakerPath: cakerPath, withReply: reply)
		}
	}
}
