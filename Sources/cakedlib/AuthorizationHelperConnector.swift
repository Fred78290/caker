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

/// An established connection to the helper tool and the authorization to send with its requests.
struct AuthorizationHelperSession {
	let connection: NSXPCConnection
	let authorization: Data
}

/// Knows how to reach the helper tool.
@MainActor
protocol AuthorizationHelperConnector: AnyObject {
	/// Ensures that we're connected to our helper tool and then calls `completion` on the main actor
	/// with the session, or with an error if the connection could not be established.
	func connect(completion: @escaping @MainActor (Result<AuthorizationHelperSession, Error>) -> Void)
}

@MainActor
public final class DirectAuthorizationHelperConnector: AuthorizationHelperConnector {
	private let log = Logger("DirectAuthorizationHelperConnector")
	private var authorization = Data()
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
		}
		assert(err == errAuthorizationSuccess)

		// If we successfully connected to Authorization Services, add definitions for our default
		// rights (unless they're already in the database).
		if let authRef {
			AuthorizationHelperCommon.setupAuthorizationRights(authRef)
		}
	}

	func connect(completion: @escaping @MainActor (Result<AuthorizationHelperSession, Error>) -> Void) {
		// Ensure that there's a helper tool connection in place.  Note that we never error in this case
		// because, if there is an error connecting to the helper tool, it will be delivered to the error
		// handler passed to remoteObjectProxyWithErrorHandler.
		let connection = self.connection ?? makeConnection()
		completion(.success(AuthorizationHelperSession(connection: connection, authorization: authorization)))
	}

	private func makeConnection() -> NSXPCConnection {
		let connection = NSXPCConnection(machServiceName: AuthorizationHelperCommon.kAuthorizationHelperToolMachServiceName, options: .privileged)
		connection.remoteObjectInterface = NSXPCInterface(with: AuthorizationHelperProtocol.self)
		connection.invalidationHandler = { [weak self, weak connection] in
			// If the connection gets invalidated then, on the main actor, nil out our reference to it.
			// This ensures that we attempt to rebuild it the next time around.
			Task { @MainActor in
				guard let self, self.connection === connection else { return }
				self.connection = nil
				self.log.error("connection invalidated")
			}
		}
		connection.resume()
		self.connection = connection
		return connection
	}

	/// Connects to the helper tool and then runs `command` on the main actor with a proxy for it.
	/// Note that if there is an error talking to the helper tool, it will be logged by the proxy's
	/// error handler.
	private func perform(_ command: @escaping @MainActor (AuthorizationHelperProtocol, Data) -> Void) {
		self.connect { result in
			switch result {
			case .failure(let error):
				self.log.error(error)
			case .success(let session):
				let proxy = session.connection.remoteObjectProxyWithErrorHandler { error in
					self.log.error(error)
				}

				if let helperTool = proxy as? AuthorizationHelperProtocol {
					command(helperTool, session.authorization)
				}
			}
		}
	}

	/// Registers the privileged helper daemon bundled in `Contents/Library/LaunchDaemons`. Does nothing once it is
	/// registered, or when this build doesn't ship it (not running from an app bundle).
	public static func install() {
		let service = SMAppService.daemon(plistName: "com.aldunelabs.caker.authorization.plist")
		let log = Logger("DirectAuthorizationHelperConnector")

		guard service.status == .notRegistered else {
			if service.status == .requiresApproval {
				log.info("The privileged helper is waiting for approval in System Settings > General > Login Items")
			}

			return
		}

		do {
			try service.register()
		} catch {
			log.error("Unable to register the privileged helper: \(error)")
		}

		if service.status == .requiresApproval {
			// The user must approve the daemon in System Settings > General > Login Items.
			SMAppService.openSystemSettingsLoginItems()
		}
	}

	public func startNetwork(networkName: String, runMode: Utils.RunMode) async throws -> StartedNetworkReply {
		let home = try Home(runMode: runMode)

		return try await withCheckedThrowingContinuation { continuation in
			perform { helper, authorization in
				helper.startNetwork(
					authorization: authorization, cakeHome: home.cakeHomeDirectory.absoluteString, networkName: networkName
				) { reply in
					if reply.success {
						continuation.resume(returning: StartedNetworkReply(name: networkName, started: reply.success, reason: reply.reason))
					} else {
						continuation.resume(throwing: ServiceError(reply.reason))
					}
				}
			}
		}
	}

	public func setDHCPLease(leaseTime: Int32) async throws -> String {
		return try await withCheckedThrowingContinuation { continuation in
			perform { helper, authorization in
				helper.setDHCPLease(
					authorization: authorization, leaseTime: leaseTime
				) { reply in
					if reply.success {
						continuation.resume(returning: reply.reason)
					} else {
						continuation.resume(throwing: ServiceError(reply.reason))
					}
				}
			}
		}
	}

	public func importVirtualMachine(arguments: [String], runMode: Utils.RunMode) async throws -> String {
		let home = try Home(runMode: runMode)

		return try await withCheckedThrowingContinuation { continuation in
			perform { helper, authorization in
				helper.importVirtualMachine(
					authorization: authorization, cakeHome: home.cakeHomeDirectory.absoluteString, arguments: arguments
				) { reply in
					if reply.success {
						continuation.resume(returning: reply.reason)
					} else {
						continuation.resume(throwing: ServiceError(reply.reason))
					}
				}
			}
		}
	}

	public func imdsRedirect(externalAddress: String, internalAddress: String, internalPort: Int, install: Bool, runMode: Utils.RunMode) async throws -> String {
		let home = try Home(runMode: runMode)

		return try await withCheckedThrowingContinuation { continuation in
			perform { helper, authorization in
				helper.imdsRedirect(authorization: authorization, cakeHome: home.cakeHomeDirectory.absoluteString, externalAddress: externalAddress, internalAddress: internalAddress, internalPort: internalPort, install: install) { reply in

					if reply.success {
						continuation.resume(returning: reply.reason)
					} else {
						continuation.resume(throwing: ServiceError(reply.reason))
					}
				}
			}
		}
	}

	public func installPriviligedFiles(cakerPath: String) async throws -> String {
		return try await withCheckedThrowingContinuation { continuation in
			perform { helper, authorization in
				helper.installPriviligedFiles(authorization: authorization, cakerPath: cakerPath) { reply in

					if reply.success {
						continuation.resume(returning: reply.reason)
					} else {
						continuation.resume(throwing: ServiceError(reply.reason))
					}
				}
			}
		}
	}
}
