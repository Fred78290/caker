//
//  helper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/11/2026.
//

import Foundation
import Security
import GRPCLib
import CakedLib

final class AuthorizationHelperTool: NSObject, NSXPCListenerDelegate, AuthorizationHelperProtocol {
	private let listener: NSXPCListener

	override init() {
		// Set up our XPC listener to handle requests on our Mach service.
		listener = NSXPCListener(machServiceName: AuthorizationHelperCommon.kAuthorizationHelperToolMachServiceName)
		super.init()
		listener.delegate = self
	}

	/// Starts processing requests and runs the run loop forever.
	func run() -> Never {
		listener.resume()
		RunLoop.current.run()
		fatalError("the run loop should never return")
	}

	// MARK: NSXPCListenerDelegate

	/// Called by our XPC listener when a new connection comes in.  We configure the connection with
	/// our protocol and ourselves as the main object.
	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		newConnection.exportedInterface = NSXPCInterface(with: AuthorizationHelperProtocol.self)
		newConnection.exportedObject = self
		newConnection.resume()
		return true
	}

	// MARK: Helpers

	/// Checks that the client denoted by `authData` is allowed to run the specified command.
	/// `authData` is expected to be a Data with an AuthorizationExternalForm embedded inside.
	private func checkAuthorization(_ authData: Data, command: Selector) -> NSError? {
		// First check that authData looks reasonable.
		guard authData.count == MemoryLayout<AuthorizationExternalForm>.size,
			  let rightName = AuthorizationHelperCommon.authorizationRight(for: command) else {
			return NSError(domain: NSOSStatusErrorDomain, code: Int(paramErr))
		}

		// Create an authorization ref from the external form data contained within.
		var authRef: AuthorizationRef?
		var err = authData.withUnsafeBytes { buffer in
			AuthorizationCreateFromExternalForm(buffer.baseAddress!.assumingMemoryBound(to: AuthorizationExternalForm.self), &authRef)
		}
		defer {
			if let authRef {
				let junk = AuthorizationFree(authRef, [])
				assert(junk == errAuthorizationSuccess)
			}
		}

		// Authorize the right associated with the command.
		if err == errAuthorizationSuccess, let authRef {
			err = rightName.withCString { name in
				var oneRight = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
				return withUnsafeMutablePointer(to: &oneRight) { items in
					var rights = AuthorizationRights(count: 1, items: items)
					return AuthorizationCopyRights(authRef, &rights, nil, [.extendRights, .interactionAllowed], nil)
				}
			}
		}

		return err == errAuthorizationSuccess ? nil : NSError(domain: NSOSStatusErrorDomain, code: Int(err))
	}

	// MARK: HelperToolProtocol implementation

	// IMPORTANT: NSXPCConnection can call these methods on any thread.  It turns out that our
	// implementation of these methods is thread safe but if that's not the case for your code
	// you have to implement your own protection (for example, having your own serial queue and
	// dispatching over to it).
	func startNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		if let error = checkAuthorization(authData, command: #selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:withReply:))) {
			reply(AuthorizationHelperReply(operation: "start-network", success: false, reason: error.reason))
		} else {
			/// Call caked network start in detached process
		}
	}

	func setDHCPLease(authorization authData: Data, leaseTime: Int32, withReply reply: @escaping @Sendable (CakedLib.AuthorizationHelperReply) -> Void) {
		if let error = checkAuthorization(authData, command: #selector(AuthorizationHelperProtocol.setDHCPLease(authorization:leaseTime:withReply:))) {
			reply(AuthorizationHelperReply(operation: "imds-redirect", success: false, reason: error.reason))
		} else {
			/// Call setDHCPLease
		}
	}
	
	func imdsRedirect(authorization authData: Data, cakeHome: String, externalAddress: String, internalAddress: String, internalPort: Int, install: Bool, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		if let error = checkAuthorization(authData, command: #selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:withReply:))) {
			reply(AuthorizationHelperReply(operation: "imds-redirect", success: false, reason: error.reason))
		} else {
			/// Call caked network stop...., collect output to forward as reason
		}
	}

	func importVirtualMachine(authorization authData: Data, cakeHome: String, arguments: [String], withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		if let error = checkAuthorization(authData, command: #selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:withReply:))) {
			reply(AuthorizationHelperReply(operation: "import-virtual-machine", success: false, reason: error.reason))
		} else {
			/// Call caked import...., collect output to forward as reason
		}
	}
	
	func installPriviligedFiles(authorization authData: Data, cakerPath: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		if let error = checkAuthorization(authData, command: #selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:withReply:))) {
			reply(AuthorizationHelperReply(operation: "install-priviliged-files", success: false, reason: error.reason))
		} else {
		}
	}
}
