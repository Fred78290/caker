//
//  WindowsGuestTests.swift
//  CakerTests
//

import Foundation
import Virtualization
import XCTest

@testable import CakedLib
@testable import GRPCLib

final class WindowsGuestTests: XCTestCase {
	private var directory: URL!

	override func setUpWithError() throws {
		self.directory = FileManager.default.temporaryDirectory.appendingPathComponent("windows-guest-\(UUID().uuidString)")

		try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try? FileManager.default.removeItem(at: self.directory)
	}

	/// A 1 MiB zero-filled file: block-aligned, which is all `VZDiskImageStorageDeviceAttachment` asks of a raw image.
	private func makeImage(named name: String) throws -> URL {
		let url = self.directory.appendingPathComponent(name)

		try Data(count: 1024 * 1024).write(to: url)

		return url
	}

	private func makeConfig(os: VirtualizedOS = .linux, platform: SupportedPlatform) -> CakeConfig {
		CakeConfig(
			location: self.directory,
			rootDisk: nil,
			diskFormat: .raw,
			os: os,
			autostart: false,
			configuredUser: "admin",
			configuredPassword: "admin",
			configuredGroup: "adm",
			configuredGroups: nil,
			configuredPlatform: platform,
			clearPassword: false,
			displayRefit: false,
			ifname: false,
			cpuCountMin: 2,
			memorySize: 4096 * MoB,
			memorySizeMin: 512 * MoB,
			screenSize: .init(width: 1024, height: 768))
	}

	// MARK: - Platform detection

	func testMicrosoftIsoFilenamesAreDetectedAsWindows() {
		XCTAssertEqual(SupportedPlatform(rawValue: "Win11_25H2_English_Arm64_v2.iso"), .windows)
		XCTAssertEqual(SupportedPlatform(rawValue: "Win10_22H2_English_x64.iso"), .windows)
		XCTAssertEqual(SupportedPlatform(rawValue: "https://example.com/Windows11.iso"), .windows)
	}

	func testWindowsAliasDoesNotCaptureOtherPlatforms() {
		XCTAssertEqual(SupportedPlatform(rawValue: "ubuntu-24.04-live-server-arm64.iso"), .ubuntu)
		XCTAssertEqual(SupportedPlatform(rawValue: "debian-12.5.0-amd64-DVD-1.iso"), .debian)
		XCTAssertEqual(SupportedPlatform(rawValue: "darwin-install.iso"), .unknown)
	}

	func testIsWindowsGuestOnlyForGenericPlatformWindowsConfig() {
		XCTAssertTrue(self.makeConfig(platform: .windows).isWindowsGuest)
		XCTAssertFalse(self.makeConfig(platform: .ubuntu).isWindowsGuest)
		XCTAssertFalse(self.makeConfig(platform: .unknown).isWindowsGuest)
	}

	// MARK: - Storage devices

	func testWindowsIsoIsAttachedAsReadOnlyUSBMassStorage() throws {
		let iso = try self.makeImage(named: "Win11_Arm64.iso")
		let device = try DiskAttachement(diskPath: iso, readOnly: false).configuration(relativeTo: self.directory, windowsGuest: true)

		XCTAssertTrue(device is VZUSBMassStorageDeviceConfiguration)
		XCTAssertEqual((device.attachment as? VZDiskImageStorageDeviceAttachment)?.isReadOnly, true)
	}

	func testWindowsDataDiskIsAttachedAsNVMe() throws {
		let image = try self.makeImage(named: "data.img")
		let device = try DiskAttachement(diskPath: image, readOnly: true).configuration(relativeTo: self.directory, windowsGuest: true)

		XCTAssertTrue(device is VZNVMExpressControllerDeviceConfiguration)
	}

	func testNonWindowsDisksKeepVirtioBlock() throws {
		let iso = try self.makeImage(named: "ubuntu.iso")
		let device = try DiskAttachement(diskPath: iso, readOnly: true).configuration(relativeTo: self.directory)

		XCTAssertTrue(device is VZVirtioBlockDeviceConfiguration)
	}

	@MainActor
	func testRootDiskIsNVMeForWindowsAndVirtioBlockOtherwise() throws {
		let disk = try self.makeImage(named: "disk.img")

		XCTAssertTrue(try self.makeConfig(platform: .windows).rootDiskAttachment(rootDiskURL: disk) is VZNVMExpressControllerDeviceConfiguration)
		XCTAssertTrue(try self.makeConfig(platform: .ubuntu).rootDiskAttachment(rootDiskURL: disk) is VZVirtioBlockDeviceConfiguration)
	}
}
