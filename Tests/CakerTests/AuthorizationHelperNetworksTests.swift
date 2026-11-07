//
//  AuthorizationHelperNetworksTests.swift
//  CakerTests
//

import Foundation
import XCTest

@testable import CakedLib
@testable import GRPCLib

/// Only the part of the helper that a test can run without a root daemon: how the requests travel over XPC, and how the
/// client reads what `caked networks ... --json` printed for it.
final class AuthorizationHelperNetworksTests: XCTestCase {
	/// Every operation of the protocol has an authorization right, or the helper refuses it ("paramErr") before running anything.
	func testEveryOperationHasAnAuthorizationRight() {
		let selectors: [Selector] = [
			#selector(AuthorizationHelperProtocol.createNetwork(authorization:cakeHome:networkName:options:withReply:)),
			#selector(AuthorizationHelperProtocol.configureNetwork(authorization:cakeHome:networkName:options:withReply:)),
			#selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:withReply:)),
			#selector(AuthorizationHelperProtocol.runNetwork(authorization:cakeHome:arguments:pidFile:fileHandle:withReply:)),
			#selector(AuthorizationHelperProtocol.restartNetwork(authorization:cakeHome:networkName:withReply:)),
			#selector(AuthorizationHelperProtocol.stopNetwork(authorization:cakeHome:networkName:withReply:)),
			#selector(AuthorizationHelperProtocol.deleteNetwork(authorization:cakeHome:networkName:withReply:)),
			#selector(AuthorizationHelperProtocol.listNetwork(authorization:cakeHome:withReply:)),
			#selector(AuthorizationHelperProtocol.infosNetwork(authorization:cakeHome:networkName:withReply:)),
			#selector(AuthorizationHelperProtocol.setDHCPLease(authorization:leaseTime:withReply:)),
			#selector(AuthorizationHelperProtocol.importVirtualMachine(authorization:cakeHome:arguments:withReply:)),
			#selector(AuthorizationHelperProtocol.imdsRedirect(authorization:externalAddress:internalAddress:internalPort:install:withReply:)),
			#selector(AuthorizationHelperProtocol.installPriviligedFiles(authorization:cakerPath:withReply:)),
		]

		var rights = Set<String>()

		for selector in selectors {
			guard let right = AuthorizationHelperCommon.authorizationRight(for: selector) else {
				return XCTFail("\(selector) has no authorization right")
			}

			XCTAssertTrue(right.hasPrefix("com.aldunelabs.caker.authorization."))
			rights.insert(right)
		}

		XCTAssertEqual(rights.count, selectors.count, "two operations share a right")
	}

	// MARK: XPC

	/// Answers `createNetwork` with what it received, as a list of `key=value (type)`. It doesn't declare the protocol: only the
	/// selector under test is needed, and NSXPCConnection finds it by name.
	private final class EchoHelper: NSObject, NSXPCListenerDelegate {
		func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
			newConnection.exportedInterface = AuthorizationHelperCommon.makeInterface()
			newConnection.exportedObject = self
			newConnection.resume()

			return true
		}

		@objc(createNetworkWithAuthorization:cakeHome:networkName:options:withReply:)
		func createNetwork(authorization: Data, cakeHome: String, networkName: String, options: [String: Any], withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
			let received = options.keys.sorted().map { key -> String in
				let value = options[key]!

				switch value {
				case let text as String: return "\(key)=\(text)"
				case let number as NSNumber: return "\(key)=\(number) (number)"
				default: return "\(key)=? (\(type(of: value)))"
				}
			}

			reply(AuthorizationHelperReply(operation: networkName, success: true, reason: received.joined(separator: ";")))
		}
	}

	/// `options: [String: Any]` is a collection: without the allowed classes of `makeInterface()` the connection drops the request.
	func testOptionsSurviveTheXPCRoundTrip() async throws {
		let helper = EchoHelper()
		let listener = NSXPCListener.anonymous()

		listener.delegate = helper
		listener.resume()

		defer {
			listener.invalidate()
		}

		let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)

		connection.remoteObjectInterface = AuthorizationHelperCommon.makeInterface()
		connection.resume()

		defer {
			connection.invalidate()
		}

		let reply: AuthorizationHelperReply = try await withCheckedThrowingContinuation { continuation in
			let proxy = connection.remoteObjectProxyWithErrorHandler { error in
				continuation.resume(throwing: error)
			}

			guard let remote = proxy as? AuthorizationHelperProtocol else {
				return continuation.resume(throwing: ServiceError("No proxy"))
			}

			remote.createNetwork(authorization: Data(), cakeHome: "/tmp/home", networkName: "demo", options: ["gateway": "192.168.201.1", "dhcp-lease": 600, "dns": true, "mode": "host"]) { reply in
				continuation.resume(returning: reply)
			}
		}

		XCTAssertTrue(reply.success)
		XCTAssertEqual(reply.operation, "demo")
		XCTAssertEqual(reply.reason, "dhcp-lease=600 (number);dns=1 (number);gateway=192.168.201.1;mode=host")
	}

	// MARK: What `caked networks ... --json` prints

	private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
		try JSONDecoder().decode(type, from: Data(json.utf8))
	}

	func testReadsTheRepliesOfTheNetworkCommands() throws {
		let created = try decode(CreatedNetworkReply.self, #"{ "name" : "demo", "reason" : "Network demo created", "created" : true }"#)

		XCTAssertEqual(created.name, "demo")
		XCTAssertTrue(created.created)

		let configured = try decode(ConfiguredNetworkReply.self, #"{ "reason" : "Network demo is not running", "configured" : true, "name" : "demo" }"#)

		XCTAssertTrue(configured.configured)

		let stopped = try decode(StoppedNetworkReply.self, #"{ "name" : "demo", "reason" : "Network demo is not running", "stopped" : true }"#)

		XCTAssertTrue(stopped.stopped)

		let deleted = try decode(DeleteNetworkReply.self, #"{ "deleted" : true, "name" : "demo", "reason" : "Network demo deleted" }"#)

		XCTAssertTrue(deleted.deleted)
	}

	func testReadsTheNetworkInfosAndTheList() throws {
		let infos = """
			{ "managed" : true, "name" : "demo", "dhcpLease" : "600", "gateway" : "192.168.201.1/24", "mode" : "shared",
			  "dhcpEnd" : "192.168.201.254/24", "interfaceID" : "1A86C1F3-1360-4EB5-B33F-A0541A120A65", "dns" : true,
			  "description" : "Shared network", "usedBy" : 0, "endpoint" : "", "active" : 0, "running" : false }
			"""
		let network = try decode(FlatBridgedNetwork.self, infos).network

		XCTAssertEqual(network.name, "demo")
		XCTAssertFalse(network.running)
		XCTAssertEqual(network.usedBy.active, 0)
		XCTAssertEqual(network.mode, .shared)
		XCTAssertEqual(network.dhcpStart, "192.168.201.1")
		XCTAssertTrue(network.dns)

		let list = try decode([FlatBridgedNetwork].self, "[\(infos), \(infos.replacingOccurrences(of: "\"demo\"", with: "\"other\""))]").map(\.network)

		XCTAssertEqual(list.map(\.name), ["demo", "other"])
	}
}
