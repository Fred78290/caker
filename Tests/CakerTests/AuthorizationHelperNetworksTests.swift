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
		var selectors: [Selector] = [
			#selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:withReply:)),
			#selector(AuthorizationHelperProtocol.setDHCPLease(authorization:leaseTime:withReply:)),
			#selector(AuthorizationHelperProtocol.importVirtualMachine(authorization:cakeHome:arguments:withReply:)),
			#selector(AuthorizationHelperProtocol.imdsRedirect(authorization:externalAddress:internalAddress:internalPort:install:withReply:)),
			#selector(AuthorizationHelperProtocol.installPriviligedFiles(authorization:cakerPath:withReply:)),
		]

		#if !APPSTORE
			selectors.append(#selector(AuthorizationHelperProtocol.runNetwork(authorization:cakeHome:arguments:fileHandle:withReply:)))
		#endif

		// Only the sandboxed build has the other network operations.
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			selectors += [
				#selector(AuthorizationHelperProtocol.getSerialization(authorization:cakeHome:networkName:withReply:)),
				#selector(AuthorizationHelperProtocol.createNetwork(authorization:cakeHome:networkName:options:withReply:)),
				#selector(AuthorizationHelperProtocol.configureNetwork(authorization:cakeHome:networkName:options:withReply:)),
				#selector(AuthorizationHelperProtocol.restartNetwork(authorization:cakeHome:networkName:withReply:)),
				#selector(AuthorizationHelperProtocol.stopNetwork(authorization:cakeHome:networkName:withReply:)),
				#selector(AuthorizationHelperProtocol.deleteNetwork(authorization:cakeHome:networkName:withReply:)),
				#selector(AuthorizationHelperProtocol.listNetwork(authorization:cakeHome:withReply:)),
				#selector(AuthorizationHelperProtocol.infosNetwork(authorization:cakeHome:networkName:withReply:)),
				#selector(AuthorizationHelperProtocol.getSharedNetworks(authorization:cakeHome:withReply:)),
				#selector(AuthorizationHelperProtocol.setSharedNetworks(authorization:cakeHome:configuration:withReply:)),
			]
		#endif

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

#if APPSTORE && USE_AUTHORIZATION_HELPER
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
#endif

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
			{ "managed" : true, "name" : "demo", "dhcpLease" : 600, "nat66Prefix" : "", "gateway" : "192.168.201.1/24", "mode" : "shared",
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

	// MARK: Cake home of the caller

	/// The helper is root and serves several users in turn, while `getHome` answers the same thing for the life of a process: the home of
	/// the caller must be what the network handlers see during its call, and only then.
	func testWithCakeHomeScopesTheHomeToOneCall() throws {
		let before = try Utils.getHome(runMode: .user)
		let first = FileManager.default.temporaryDirectory.appendingPathComponent("cake-home-\(UUID().uuidString)", isDirectory: true)
		let second = FileManager.default.temporaryDirectory.appendingPathComponent("cake-home-\(UUID().uuidString)", isDirectory: true)

		for home in [first, second] {
			try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
		}

		defer {
			for home in [first, second] {
				try? FileManager.default.removeItem(at: home)
			}
		}

		let seen = try Utils.withCakeHome(first) {
			(try Utils.getHome(runMode: .user), try Home(runMode: .user).cakeHomeDirectory)
		}

		XCTAssertEqual(seen.0.standardizedFileURL.path, first.standardizedFileURL.path)
		XCTAssertEqual(seen.1.standardizedFileURL.path, first.standardizedFileURL.path)
		XCTAssertEqual(try Utils.getHome(runMode: .user), before, "the previous home comes back")

		// A call inside a call (a handler calling another) sees the same home, and the outer one gets it back afterwards.
		let nested = try Utils.withCakeHome(first) { () throws -> [String] in
			let outer = try Utils.getHome(runMode: .user).standardizedFileURL.path
			let inner = try Utils.withCakeHome(second) { try Utils.getHome(runMode: .user).standardizedFileURL.path }

			return [outer, inner, try Utils.getHome(runMode: .user).standardizedFileURL.path]
		}

		XCTAssertEqual(nested, [first.standardizedFileURL.path, second.standardizedFileURL.path, first.standardizedFileURL.path])
		XCTAssertEqual(try Utils.getHome(runMode: .user), before)
	}

	/// Two callers at the same time never see each other's home.
	func testWithCakeHomeSerializesConcurrentCallers() async throws {
		let homes = try (0..<8).map { _ -> URL in
			let home = FileManager.default.temporaryDirectory.appendingPathComponent("cake-home-\(UUID().uuidString)", isDirectory: true)

			try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

			return home
		}

		defer {
			homes.forEach { try? FileManager.default.removeItem(at: $0) }
		}

		let mismatches = await withTaskGroup(of: Int.self) { group in
			for home in homes {
				group.addTask {
					var wrong = 0

					for _ in 0..<50 {
						let seen = try? Utils.withCakeHome(home) { () throws -> String in
							Thread.sleep(forTimeInterval: 0.0005)

							return try Utils.getHome(runMode: .user).standardizedFileURL.path
						}

						if seen != home.standardizedFileURL.path {
							wrong += 1
						}
					}

					return wrong
				}
			}

			return await group.reduce(0, +)
		}

		XCTAssertEqual(mismatches, 0)
	}
}
