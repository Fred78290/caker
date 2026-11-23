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

		let location = VMLocation(rootURL: config.locationURL)
		let sockets = try config.socketDeviceAttachments(agentURL: agent, seamlessSocketURL: location.seamlessSocketURL)
		let seamless = try XCTUnwrap(sockets.first { $0.port == SeamlessProtocol.defaultVsockPort })

		XCTAssertEqual(seamless.mode, .connect)
		XCTAssertEqual(seamless.bind, location.seamlessSocketURL.path(percentEncoded: false))
		XCTAssertLessThan(seamless.bind.utf8.count, 104)
		// The agent's own socket is still there.
		XCTAssertTrue(sockets.contains { $0.port == VMLocation.defaultAgentListenPort })
	}

	func testNoSeamlessSocketWhenDisabled() throws {
		let config = try makeConfig(seamless: false)
		let location = VMLocation(rootURL: config.locationURL)
		let sockets = try config.socketDeviceAttachments(agentURL: config.locationURL.appendingPathComponent("agent.sock"), seamlessSocketURL: location.seamlessSocketURL)

		XCTAssertFalse(sockets.contains { $0.port == SeamlessProtocol.defaultVsockPort })
	}

	func testCustomSocketOnTheSeamlessPortIsRejectedNotReplaced() throws {
		let location = { (config: CakeConfig) in VMLocation(rootURL: config.locationURL) }
		let port = SeamlessProtocol.defaultVsockPort

		// With seamless on, a custom mapping on the reserved port is an error naming the port.
		let config = try makeConfig(seamless: true)
		config.sockets = [SocketDevice(mode: .tcp, port: port, bind: "127.0.0.1")]

		XCTAssertThrowsError(try config.socketDeviceAttachments(agentURL: config.locationURL.appendingPathComponent("agent.sock"), seamlessSocketURL: location(config).seamlessSocketURL)) { error in
			XCTAssertTrue("\(error)".contains("\(port)"), "\(error)")
		}

		// With seamless off, the same custom mapping is left alone.
		let off = try makeConfig(seamless: false)
		off.sockets = [SocketDevice(mode: .tcp, port: port, bind: "127.0.0.1")]

		let sockets = try off.socketDeviceAttachments(agentURL: off.locationURL.appendingPathComponent("agent.sock"), seamlessSocketURL: location(off).seamlessSocketURL)

		XCTAssertEqual(sockets.filter { $0.port == port }.map(\.mode), [.tcp])
	}

	func testLongVMPathFallsBackToAShortSocketPath() throws {
		let base = FileManager.default.temporaryDirectory.appendingPathComponent(String(repeating: "long-directory-name-", count: 6))
		let dir = base.appendingPathComponent("vm.vm")

		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: base) }

		// The path comes from the VM's location (the same one for the server, the tunnel and the socket device).
		let location = VMLocation(rootURL: dir)
		let path = location.seamlessSocketURL.path(percentEncoded: false)

		XCTAssertLessThan(path.utf8.count, 104)
		XCTAssertTrue(path.hasSuffix(".smls"), path)
		// Stable: computed separately by each user of it.
		XCTAssertEqual(path, VMLocation(rootURL: dir).seamlessSocketURL.path(percentEncoded: false))
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

	func testBuildOptionsSeamlessCrossesTheWire() throws {
		var options = try BuildOptions.parse(["vm", "--seamless"])

		XCTAssertTrue(options.seamless)

		var request = try Caked_CommonBuildRequest(buildOptions: options)

		XCTAssertTrue(request.hasSeamless)
		XCTAssertTrue(request.seamless)
		XCTAssertTrue(try BuildOptions(request: request, identifier: UUID()).seamless)

		options = try BuildOptions.parse(["vm"])
		request = try Caked_CommonBuildRequest(buildOptions: options)

		XCTAssertFalse(options.seamless)
		XCTAssertFalse(try BuildOptions(request: request, identifier: UUID()).seamless)
	}
}
