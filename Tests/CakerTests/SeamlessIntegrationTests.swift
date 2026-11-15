//
//  SeamlessIntegrationTests.swift
//  CakerTests
//

import Foundation
import XCTest

@testable import CakedLib
@testable import GRPCLib

final class SeamlessIntegrationTests: XCTestCase {

	private static func config(at dir: URL, os: VirtualizedOS, user: String) -> CakeConfig {
		CakeConfig(
			location: dir, rootDisk: nil, diskFormat: .raw, os: os, autostart: false, configuredUser: user, configuredPassword: "x",
			configuredGroup: "adm", configuredGroups: nil, configuredPlatform: .unknown, clearPassword: false, displayRefit: false,
			ifname: false, cpuCountMin: 2, memorySize: 4096 * MoB, memorySizeMin: 512 * MoB, screenSize: .init(width: 1024, height: 768))
	}

	private func makeConfig(os: VirtualizedOS = .linux, seamless: Bool, user: String = "admin") throws -> CakeConfig {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("seamless-\(UUID().uuidString.prefix(6))")

		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

		let config = Self.config(at: dir, os: os, user: user)

		config.seamless = seamless

		return config
	}

	// MARK: - Layout

	func testKeyboardLayoutMapping() {
		XCTAssertEqual(SeamlessKeyboardLayout.xkbLayout(forInputSourceID: "com.apple.keylayout.French"), "fr")
		XCTAssertEqual(SeamlessKeyboardLayout.xkbLayout(forInputSourceID: "com.apple.keylayout.US"), "us")
		XCTAssertEqual(SeamlessKeyboardLayout.xkbLayout(forInputSourceID: "com.apple.keylayout.ABC"), "us")
		XCTAssertEqual(SeamlessKeyboardLayout.xkbLayout(forInputSourceID: "com.apple.keylayout.British"), "gb")
		XCTAssertNil(SeamlessKeyboardLayout.xkbLayout(forInputSourceID: "com.apple.keylayout.Dvorak"))
		XCTAssertNil(SeamlessKeyboardLayout.xkbLayout(forInputSourceID: "org.example.layout.French"))
	}

	// MARK: - Config and socket device

	func testSeamlessIsOffByDefaultAndPersists() throws {
		let config = try makeConfig(seamless: false)

		XCTAssertFalse(config.seamless)
		XCTAssertFalse(config.supportsSeamlessWindows)

		config.seamless = true

		XCTAssertTrue(config.seamless)
		XCTAssertTrue(config.supportsSeamlessWindows)
	}

	func testOnlyLinuxGuestsSupportSeamlessWindows() throws {
		XCTAssertFalse(try makeConfig(os: .darwin, seamless: true).supportsSeamlessWindows)
	}

	func testSeamlessAddsAConnectSocketToTheServerPort() throws {
		let config = try makeConfig(seamless: true)
		let agent = config.locationURL.appendingPathComponent("agent.sock")

		let sockets = try config.socketDeviceAttachments(agentURL: agent)
		let seamless = try XCTUnwrap(sockets.first { $0.port == SeamlessProtocol.defaultVsockPort })

		XCTAssertEqual(seamless.mode, .connect)
		XCTAssertEqual(seamless.bind, config.seamlessSocketPath)
		XCTAssertLessThan(seamless.bind.utf8.count, 104)
		// The agent's own socket is still there.
		XCTAssertTrue(sockets.contains { $0.port == VMLocation.defaultAgentListenPort })
	}

	func testNoSeamlessSocketWhenDisabled() throws {
		let config = try makeConfig(seamless: false)
		let sockets = try config.socketDeviceAttachments(agentURL: config.locationURL.appendingPathComponent("agent.sock"))

		XCTAssertFalse(sockets.contains { $0.port == SeamlessProtocol.defaultVsockPort })
	}

	func testLongVMPathFallsBackToAShortSocketPath() throws {
		let base = FileManager.default.temporaryDirectory.appendingPathComponent(String(repeating: "long-directory-name-", count: 6))
		let dir = base.appendingPathComponent("vm.vm")

		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: base) }

		let config = Self.config(at: dir, os: .linux, user: "admin")
		let path = try XCTUnwrap(config.seamlessSocketPath)

		XCTAssertLessThan(path.utf8.count, 100)
		XCTAssertTrue(path.hasSuffix(".sock"))
		// Stable: the server and the socket device compute it separately.
		XCTAssertEqual(path, config.seamlessSocketPath)
	}

	// MARK: - Agent service flags

	func testAgentServiceFlagsCarryTheSeamlessOptionsOnlyWhenEnabled() throws {
		XCTAssertFalse(try makeConfig(seamless: false).agentServiceFlags.contains("--seamless"))

		let flags = try makeConfig(seamless: true, user: "alice").agentServiceFlags

		XCTAssertTrue(flags.contains("--seamless "), flags)
		XCTAssertTrue(flags.contains("--seamless-user=alice"), flags)
	}

	func testAgentServiceFlagsNeverPassAnUnsafeUserName() throws {
		let flags = try makeConfig(seamless: true, user: "evil; rm -rf /").agentServiceFlags

		XCTAssertFalse(flags.contains("evil"), flags)
		XCTAssertTrue(flags.hasPrefix("--seamless"), flags)
	}

	// MARK: - Configure options and gRPC

	func testConfigureOptionsRoundTripThroughTheRequest() throws {
		var options = try ConfigureOptions.parse(["vm", "--seamless", "true"])

		XCTAssertEqual(options.seamless, true)

		let request = Caked_ConfigureRequest(options: options)

		XCTAssertTrue(request.hasSeamless)
		XCTAssertTrue(request.seamless)
		XCTAssertEqual(ConfigureOptions(request: request).seamless, true)

		options = try ConfigureOptions.parse(["vm"])

		XCTAssertNil(options.seamless)
		XCTAssertFalse(Caked_ConfigureRequest(options: options).hasSeamless)
		XCTAssertNil(ConfigureOptions(request: Caked_ConfigureRequest(options: options)).seamless)
	}
}
