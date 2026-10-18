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

		XCTAssertTrue(try self.makeConfig(os: .windows, platform: .windows).rootDiskAttachment(rootDiskURL: disk) is VZNVMExpressControllerDeviceConfiguration)
		XCTAssertTrue(try self.makeConfig(platform: .ubuntu).rootDiskAttachment(rootDiskURL: disk) is VZVirtioBlockDeviceConfiguration)
	}

	// MARK: - Installation media

	func testCRC32MatchesTheStandardCheckValue() {
		XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926)
	}

	/// Builds a minimal GPT disk: protective-less, 48 sectors, a primary header at LBA 1 and a backup one at LBA 40,
	/// four 128-byte entries each, the first two typed as "Microsoft basic data".
	private func makeGPT() throws -> URL {
		let sector = 512
		var disk = Data(count: 48 * sector)
		let basicData = UUID(uuidString: "EBD0A0A2-B9E5-4433-87C7-68B6B72699C7")!.uuid

		func store<T: FixedWidthInteger>(_ value: T, into data: inout Data, at offset: Int) {
			withUnsafeBytes(of: value.littleEndian) { data.replaceSubrange(offset..<(offset + MemoryLayout<T>.size), with: $0) }
		}

		var entries = Data(count: 4 * 128)

		for index in 0..<2 {
			// Only the first 8 bytes of the GUID need the little-endian field swap; the test only compares
			// what setEFISystemPartition writes, so any non-ESP value will do for the others.
			entries.replaceSubrange((index * 128)..<(index * 128 + 16), with: withUnsafeBytes(of: basicData) { Data($0) })
		}

		func header(current: Int, backup: Int, entriesLBA: Int) -> Data {
			var header = Data(count: 92)

			header.replaceSubrange(0..<8, with: Data("EFI PART".utf8))
			store(UInt32(0x0001_0000), into: &header, at: 8)
			store(UInt32(92), into: &header, at: 12)
			store(UInt64(current), into: &header, at: 24)
			store(UInt64(backup), into: &header, at: 32)
			store(UInt64(34), into: &header, at: 40)
			store(UInt64(39), into: &header, at: 48)
			store(UInt64(entriesLBA), into: &header, at: 72)
			store(UInt32(4), into: &header, at: 80)
			store(UInt32(128), into: &header, at: 84)
			store(CRC32.checksum(entries), into: &header, at: 88)
			store(CRC32.checksum(header), into: &header, at: 16)

			return header
		}

		disk.replaceSubrange(sector..<(sector + 92), with: header(current: 1, backup: 40, entriesLBA: 2))
		disk.replaceSubrange((2 * sector)..<(2 * sector + entries.count), with: entries)
		disk.replaceSubrange((40 * sector)..<(40 * sector + 92), with: header(current: 40, backup: 1, entriesLBA: 41))
		disk.replaceSubrange((41 * sector)..<(41 * sector + entries.count), with: entries)

		let url = self.directory.appendingPathComponent("gpt.img")

		try disk.write(to: url)

		return url
	}

	func testSetEFISystemPartitionRetypesOnlyTheRequestedPartitionAndKeepsChecksumsValid() throws {
		let url = try self.makeGPT()

		try WindowsInstallationMedia.setEFISystemPartition(of: url, partition: 2)

		let disk = try Data(contentsOf: url)
		let sector = 512
		let esp = Data([0x28, 0x73, 0x2A, 0xC1, 0x1F, 0xF8, 0xD2, 0x11, 0xBA, 0x4B, 0x00, 0xA0, 0xC9, 0x3E, 0xC9, 0x3B])

		for entriesLBA in [2, 41] {
			let entries = disk.subdata(in: (entriesLBA * sector)..<(entriesLBA * sector + 4 * 128))

			XCTAssertNotEqual(entries.subdata(in: 0..<16), esp, "partition 1 must keep its type")
			XCTAssertEqual(entries.subdata(in: 128..<144), esp, "partition 2 must be an EFI system partition")
		}

		for headerLBA in [1, 40] {
			var header = disk.subdata(in: (headerLBA * sector)..<(headerLBA * sector + 92))
			let stored = header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 16, as: UInt32.self) }
			let entriesLBA = headerLBA == 1 ? 2 : 41
			let entries = disk.subdata(in: (entriesLBA * sector)..<(entriesLBA * sector + 4 * 128))
			let storedEntriesCRC = header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 88, as: UInt32.self) }

			header.replaceSubrange(16..<20, with: Data(count: 4))

			XCTAssertEqual(stored, CRC32.checksum(header), "header \(headerLBA) checksum")
			XCTAssertEqual(storedEntriesCRC, CRC32.checksum(entries), "entries checksum of header \(headerLBA)")
		}
	}

	func testSetEFISystemPartitionRejectsADiskWithoutGPT() throws {
		let url = self.directory.appendingPathComponent("blank.img")

		try Data(count: 48 * 512).write(to: url)

		XCTAssertThrowsError(try WindowsInstallationMedia.setEFISystemPartition(of: url, partition: 2))
	}

	func testComputerNameIsAValidWindowsHostName() {
		XCTAssertEqual(WindowsInstaller.computerName(for: "win11"), "win11")
		XCTAssertEqual(WindowsInstaller.computerName(for: "my vm_01"), "my-vm-01")
		XCTAssertEqual(WindowsInstaller.computerName(for: "averyveryverylongvmname").count, 15)
		XCTAssertEqual(WindowsInstaller.computerName(for: "12345"), "CAKER-WIN", "a computer name can't be all digits")
		XCTAssertEqual(WindowsInstaller.computerName(for: "---"), "CAKER-WIN")
	}

	func testUnattendEscapesCredentialsAndUsesTheImageLanguage() {
		let xml = WindowsInstallResources.unattend(username: "admin", password: "p<a>&ss", computerName: "CAKER", language: "fr-FR")

		XCTAssertTrue(xml.contains("<Value>p&lt;a&gt;&amp;ss</Value>"))
		XCTAssertTrue(xml.contains("<UILanguage>fr-FR</UILanguage>"))
		XCTAssertTrue(xml.contains("<ComputerName>CAKER</ComputerName>"))
		XCTAssertTrue(xml.contains("\r\n"), "Windows tools expect CRLF")
	}

	func testInstallScriptsUseCRLFOnly() {
		for script in [WindowsInstallResources.installScript, WindowsInstallResources.peScript, WindowsInstallResources.setupComplete, WindowsInstallResources.winpeshl] {
			XCTAssertFalse(script.replacingOccurrences(of: "\r\n", with: "").contains("\n"), "a bare LF would break cmd.exe's line handling")
		}
	}

	func testEmbeddedEFIBinariesArePortableExecutables() {
		for binary in [WindowsEFIBinaries.framebuffer, WindowsEFIBinaries.loader] {
			XCTAssertEqual(binary.prefix(2), Data("MZ".utf8))
			XCTAssertLessThan(binary.count, 16 * 1024)
		}
	}

	func testWindowsMediaDiskIsWritableUSBStorage() throws {
		let media = try self.makeImage(named: "install.\(DiskAttachement.windowsMediaExtension)")
		let device = try DiskAttachement(diskPath: media, readOnly: false).configuration(relativeTo: self.directory, windowsGuest: true)

		XCTAssertTrue(device is VZUSBMassStorageDeviceConfiguration)
		XCTAssertEqual((device.attachment as? VZDiskImageStorageDeviceAttachment)?.isReadOnly, false)
	}

	func testPEShellLoadsTheGPUDriverBeforeInstalling() {
		let script = WindowsInstallResources.peScript
		let driver = script.range(of: "drvload %M%\\caker\\drivers\\viogpudo\\viogpudo.inf")
		let install = script.range(of: "call %M%\\caker\\install.cmd")

		XCTAssertNotNil(driver)
		XCTAssertNotNil(install)
		XCTAssertLessThan(driver!.lowerBound, install!.lowerBound)
	}

	func testSharingSupportIsInstalledOnFirstBoot() {
		let setup = WindowsInstallResources.setupComplete

		XCTAssertTrue(setup.contains("start /wait \"\" msiexec /i C:\\ProgramData\\caker\\winfsp.msi /qn /norestart"), "msiexec must be waited for to get its exit code")
		XCTAssertTrue(setup.contains("sc create VirtioFsSvc binpath= C:\\ProgramData\\caker\\virtiofs.exe start= auto depend= WinFsp.Launcher/VirtioFsDrv"))
		XCTAssertTrue(setup.contains("winfsp=%MSI%") && setup.contains("service=%SVC%") && setup.contains("share=%SHARE%"), "the outcome goes in the marker the host reads")
		XCTAssertFalse(setup.contains("from-windows"), "setup must not write into the user's shared folders")

		let install = WindowsInstallResources.installScript

		XCTAssertTrue(install.contains("copy /y %T%\\winfsp.msi W:\\ProgramData\\caker\\winfsp.msi"))
		XCTAssertTrue(install.contains("copy /y %T%\\virtiofs.exe W:\\ProgramData\\caker\\virtiofs.exe"))
	}

	func testMediaCarriesTheSocketDriver() {
		XCTAssertTrue(WindowsInstallationMedia.virtioDrivers.contains("viosock"), "virtio-vsock, so the guest can talk to the host over AF_VSOCK")
		XCTAssertTrue(WindowsInstallResources.setupComplete.contains("vsock=%VSOCK%"), "the driver state goes in the marker")
	}

	func testMediaCarriesTheFileSystemDriverAndAPinnedWinFsp() {
		XCTAssertTrue(WindowsInstallationMedia.virtioDrivers.contains("viofs"))
		XCTAssertEqual(WindowsInstallationMedia.winFspSHA256.count, 64)
		XCTAssertEqual(WindowsInstallationMedia.winFspURL.scheme, "https")
		XCTAssertTrue(WindowsInstallationMedia.winFspURL.lastPathComponent.hasSuffix(".msi"))
	}
}
