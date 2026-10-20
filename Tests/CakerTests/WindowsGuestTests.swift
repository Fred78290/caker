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
		let xml = WindowsInstallResources.unattend(username: "admin", password: "p<a>&ss", computerName: "CAKER", language: "fr-FR", architecture: .arm64)

		XCTAssertTrue(xml.contains("<Value>p&lt;a&gt;&amp;ss</Value>"))
		XCTAssertTrue(xml.contains("<UILanguage>fr-FR</UILanguage>"))
		XCTAssertTrue(xml.contains("<ComputerName>CAKER</ComputerName>"))
		XCTAssertTrue(xml.contains("\r\n"), "Windows tools expect CRLF")
	}

	func testInstallScriptsUseCRLFOnly() {
		for script in [WindowsInstallResources.installScript(for: .arm64), WindowsInstallResources.installScript(for: .amd64), WindowsInstallResources.peScript, WindowsInstallResources.setupComplete, WindowsInstallResources.winpeshl] {
			XCTAssertFalse(script.replacingOccurrences(of: "\r\n", with: "").contains("\n"), "a bare LF would break cmd.exe's line handling")
		}
	}

	/// The `Machine` field of a PE image's COFF header, which firmware compares with its own architecture before loading.
	private func machineType(of image: Data) -> UInt16? {
		guard image.count > 0x40, image.prefix(2) == Data("MZ".utf8) else {
			return nil
		}

		let peOffset = Int(image.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x3c, as: UInt32.self) })

		guard image.count >= peOffset + 6, image.subdata(in: peOffset..<(peOffset + 4)) == Data([0x50, 0x45, 0, 0]) else {
			return nil
		}

		return image.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: peOffset + 4, as: UInt16.self) }
	}

	func testEmbeddedEFIBinariesArePortableExecutables() {
		for architecture in WindowsArchitecture.allCases {
			for binary in [WindowsEFIBinaries.framebuffer(for: architecture), WindowsEFIBinaries.loader(for: architecture)] {
				XCTAssertNotNil(self.machineType(of: binary), "\(architecture)")
				XCTAssertLessThan(binary.count, 16 * 1024)
			}
		}
	}

	func testEmbeddedEFIBinariesMatchTheirGuestArchitecture() {
		// IMAGE_FILE_MACHINE_ARM64 / IMAGE_FILE_MACHINE_AMD64: firmware refuses an image of another machine type
		XCTAssertEqual(self.machineType(of: WindowsEFIBinaries.framebuffer(for: .arm64)), 0xAA64)
		XCTAssertEqual(self.machineType(of: WindowsEFIBinaries.loader(for: .arm64)), 0xAA64)
		XCTAssertEqual(self.machineType(of: WindowsEFIBinaries.framebuffer(for: .amd64)), 0x8664)
		XCTAssertEqual(self.machineType(of: WindowsEFIBinaries.loader(for: .amd64)), 0x8664)
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

		let install = WindowsInstallResources.installScript(for: .arm64)

		XCTAssertTrue(install.contains("copy /y %T%\\winfsp.msi W:\\ProgramData\\caker\\winfsp.msi"))
		XCTAssertTrue(install.contains("copy /y %T%\\virtiofs.exe W:\\ProgramData\\caker\\virtiofs.exe"))
	}

	func testSetupInstallsTheCakeAgentServiceOverVsockWithCertificates() {
		let setup = WindowsInstallResources.setupComplete

		XCTAssertTrue(setup.contains("setlocal EnableDelayedExpansion"), "the exit code is read inside a block")
		XCTAssertTrue(setup.contains("cakeagent.exe\" service install --listen=vsock://any:\(VMLocation.defaultAgentListenPort)"), "the host reaches the agent through the VM's vsock device")
		XCTAssertTrue(setup.contains("--ca-cert=") && setup.contains("--tls-cert=") && setup.contains("--tls-key="))
		XCTAssertTrue(setup.contains("icacls C:\\ProgramData\\CakeAgent /inheritance:r"), "the private key is not readable by everyone")
		XCTAssertFalse(setup.contains("name=\"CakeAgent\""), "vsock is not IP traffic: no firewall rule for the agent")
		XCTAssertTrue(setup.contains("agent=%AGENT%"))

		let install = WindowsInstallResources.installScript(for: .arm64)

		XCTAssertTrue(install.contains("copy /y %T%\\cakeagent.exe W:\\ProgramData\\caker\\cakeagent.exe"))
		XCTAssertTrue(install.contains("xcopy /y /i /q %T%\\certs W:\\ProgramData\\caker\\certs"))
	}

	func testSetupRunsTheAgentInFrontWhenTheServiceIsNotRunning() {
		let setup = WindowsInstallResources.setupComplete

		XCTAssertTrue(setup.contains("serve --listen=vsock://any:5000"), "to see why the service isn't running")
		XCTAssertTrue(setup.contains("> S:\\EFI\\caker\\agent.log 2>&1"), "the output goes where the host can read it")
		XCTAssertTrue(setup.contains("taskkill /f /im cakeagent.exe"))
	}

	func testMediaCopiesTheCakeAgentAndItsCertificatesOnlyWhenGiven() {
		XCTAssertNil(WindowsInstallationMedia.Options(username: "a", password: "b", computerName: "c").cakeAgent)
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

	// MARK: - Guest architecture

	func testArchitectureValuesDifferWhereWindowsDiffers() {
		XCTAssertEqual(WindowsArchitecture.arm64.bootFile, "bootaa64.efi")
		XCTAssertEqual(WindowsArchitecture.amd64.bootFile, "bootx64.efi")
		XCTAssertEqual(WindowsArchitecture.arm64.removableBootPath, "S:\\EFI\\BOOT\\BOOTAA64.EFI")
		XCTAssertEqual(WindowsArchitecture.amd64.removableBootPath, "S:\\EFI\\BOOT\\BOOTX64.EFI")
		XCTAssertEqual(WindowsArchitecture.arm64.virtioFolder, "ARM64")
		XCTAssertEqual(WindowsArchitecture.amd64.virtioFolder, "amd64")
		XCTAssertEqual(WindowsArchitecture.arm64.unattendArchitecture, "arm64")
		XCTAssertEqual(WindowsArchitecture.amd64.unattendArchitecture, "amd64")
	}

	func testHostArchitectureMatchesTheAgentBuildTheInstallerDownloads() {
		// Utilities.cakeagentWindowsBinary picks the agent by Architecture.current(): it must be the guest's
		XCTAssertEqual(WindowsArchitecture.host.agentSuffix, Architecture.current().rawValue)
	}

	func testBothGuestsBootThroughTheFramebufferShimUntilIntelSaysOtherwise() {
		for architecture in WindowsArchitecture.allCases {
			XCTAssertTrue(architecture.usesFramebufferShim, "\(architecture)")
		}
	}

	func testDetectFindsTheArchitectureFromTheBootLoader() throws {
		XCTAssertEqual(try WindowsArchitecture.detect(name: "w.iso", host: .amd64) { $0 == "efi/boot/bootx64.efi" }, .amd64)
		XCTAssertEqual(try WindowsArchitecture.detect(name: "w.iso", host: .arm64) { $0 == "efi/boot/bootaa64.efi" }, .arm64)
	}

	func testDetectRefusesAnISOTheHostCannotRun() {
		XCTAssertThrowsError(try WindowsArchitecture.detect(name: "arm.iso", host: .amd64) { $0 == "efi/boot/bootaa64.efi" }) {
			XCTAssertTrue("\($0)".contains("ARM64") || "\($0)".contains("x64"))
		}

		XCTAssertThrowsError(try WindowsArchitecture.detect(name: "x64.iso", host: .arm64) { $0 == "efi/boot/bootx64.efi" })
	}

	func testDetectRefusesAnISOWithoutABootLoader() {
		XCTAssertThrowsError(try WindowsArchitecture.detect(name: "empty.iso", host: .amd64) { _ in false })
	}

	func testDetectPrefersTheHostWhenAnISOCarriesBothLoaders() throws {
		XCTAssertEqual(try WindowsArchitecture.detect(name: "both.iso", host: .amd64) { $0.hasPrefix("efi/boot/") }, .amd64)
		XCTAssertEqual(try WindowsArchitecture.detect(name: "both.iso", host: .arm64) { $0.hasPrefix("efi/boot/") }, .arm64)
	}

	/// An ISO's file tree reduced to what `validate` looks at.
	private func makeISORoot(files: [String]) throws -> URL {
		let root = self.directory.appendingPathComponent("iso-\(UUID().uuidString)", isDirectory: true)

		for file in files {
			let url = root.appendingPathComponent(file)

			try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
			try Data().write(to: url)
		}

		return root
	}

	func testValidateReturnsTheGuestArchitectureOfAnX64ISO() throws {
		let root = try self.makeISORoot(files: ["sources/install.wim", "efi/boot/bootx64.efi"])

		XCTAssertEqual(try WindowsInstallationMedia.validate(isoRoot: root, name: "x64.iso", host: .amd64), .amd64)
		XCTAssertThrowsError(try WindowsInstallationMedia.validate(isoRoot: root, name: "x64.iso", host: .arm64), "an Apple silicon Mac can't run an x64 guest")
	}

	func testValidateReturnsTheGuestArchitectureOfAnARMISO() throws {
		let root = try self.makeISORoot(files: ["sources/install.esd", "efi/boot/bootaa64.efi"])

		XCTAssertEqual(try WindowsInstallationMedia.validate(isoRoot: root, name: "arm.iso", host: .arm64), .arm64)
		XCTAssertThrowsError(try WindowsInstallationMedia.validate(isoRoot: root, name: "arm.iso", host: .amd64), "an Intel Mac can't run an ARM guest")
	}

	func testValidateRejectsAnISOWithoutAnInstallImage() throws {
		let root = try self.makeISORoot(files: ["efi/boot/bootx64.efi"])

		XCTAssertThrowsError(try WindowsInstallationMedia.validate(isoRoot: root, name: "other.iso", host: .amd64))
	}

	func testUnattendUsesTheGuestArchitectureInEveryComponent() {
		let amd64 = WindowsInstallResources.unattend(username: "admin", password: "admin", computerName: "CAKER", language: "en-US", architecture: .amd64)
		let arm64 = WindowsInstallResources.unattend(username: "admin", password: "admin", computerName: "CAKER", language: "en-US", architecture: .arm64)

		XCTAssertEqual(amd64.components(separatedBy: "processorArchitecture=\"amd64\"").count - 1, 3)
		XCTAssertFalse(amd64.contains("arm64"))
		XCTAssertEqual(arm64.components(separatedBy: "processorArchitecture=\"arm64\"").count - 1, 3)
		XCTAssertFalse(arm64.contains("amd64"))
	}

	func testInstallScriptPutsTheLoaderAtTheArchitecturesRemovableMediaPath() {
		let arm64 = WindowsInstallResources.installScript(for: .arm64)
		let amd64 = WindowsInstallResources.installScript(for: .amd64)

		XCTAssertTrue(arm64.contains("copy /y %T%\\loader.efi S:\\EFI\\BOOT\\BOOTAA64.EFI"))
		XCTAssertFalse(arm64.contains("BOOTX64"))
		XCTAssertTrue(amd64.contains("copy /y %T%\\loader.efi S:\\EFI\\BOOT\\BOOTX64.EFI"))
		XCTAssertFalse(amd64.contains("BOOTAA64"))

		for script in [arm64, amd64] {
			XCTAssertTrue(script.contains("copy /y S:\\EFI\\Microsoft\\Boot\\bootmgfw.efi S:\\EFI\\BOOT\\windows.efi"))
			XCTAssertTrue(script.contains("framebuffer.efi"))
			XCTAssertFalse(script.contains("\\#"), "the interpolation of a raw string must be resolved")
		}
	}

	func testInstallScriptWithoutTheShimLeavesWindowsBootManagerInPlace() {
		for architecture in WindowsArchitecture.allCases {
			let script = WindowsInstallResources.installScript(for: architecture, usingFramebufferShim: false)

			XCTAssertFalse(script.contains("loader.efi"))
			XCTAssertFalse(script.contains("framebuffer.efi"))
			XCTAssertFalse(script.contains("windows.efi"))
			XCTAssertTrue(script.contains("bcdboot W:\\Windows /s S: /f UEFI"), "bcdboot still writes the boot files")
			XCTAssertTrue(script.contains("echo OK> %T%\\result"))
		}
	}

	func testInstallScriptsDifferOnlyByTheShim() {
		for architecture in WindowsArchitecture.allCases {
			let with = WindowsInstallResources.installScript(for: architecture, usingFramebufferShim: true).components(separatedBy: "\r\n")
			let without = WindowsInstallResources.installScript(for: architecture, usingFramebufferShim: false).components(separatedBy: "\r\n")

			XCTAssertEqual(with.first, without.first)
			XCTAssertEqual(with.last, without.last)
			XCTAssertGreaterThan(with.count, without.count)
		}
	}

	/// Opt-in check against a real Windows ISO: `CAKER_WINDOWS_ISO=/path/to/Win11.iso swift test --filter testRealISO`.
	func testRealISOIsRecognisedAsTheHostArchitecture() throws {
		guard let path = ProcessInfo.processInfo.environment["CAKER_WINDOWS_ISO"] else {
			throw XCTSkip("set CAKER_WINDOWS_ISO to a Windows 11 ISO of the host's architecture")
		}

		let mount = self.directory.appendingPathComponent("real-iso", isDirectory: true)

		try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
		try Process.capture("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-mountpoint", mount.path, path])

		defer { _ = try? Process.capture("/usr/bin/hdiutil", ["detach", mount.path]) }

		XCTAssertEqual(try WindowsInstallationMedia.validate(isoRoot: mount, name: URL(fileURLWithPath: path).lastPathComponent), WindowsArchitecture.host)
	}

	// MARK: - OpenSSH server

	func testSetupInstallsTheOpenSSHServerFromTheMedia() {
		let setup = WindowsInstallResources.setupComplete

		XCTAssertTrue(setup.contains("install-sshd.ps1"), "the Win32-OpenSSH installer registers the service")
		XCTAssertTrue(setup.contains("administrators_authorized_keys"), "the host's keys are for the administrators")
		XCTAssertTrue(setup.contains("icacls C:\\ProgramData\\ssh\\administrators_authorized_keys /inheritance:r"), "sshd ignores a keys file others can write")
		XCTAssertTrue(setup.contains("localport=22"))
		XCTAssertTrue(setup.contains("sc config sshd start= auto"), "it starts with Windows")
		XCTAssertTrue(setup.contains("net start sshd"))
		XCTAssertTrue(setup.contains("ssh=%SSH%"), "the outcome goes in the marker the host reads")

		let install = WindowsInstallResources.installScript(for: .arm64)

		XCTAssertTrue(install.contains("xcopy /e /i /y /q %T%\\openssh W:\\ProgramData\\caker\\openssh"))
		XCTAssertTrue(install.contains("copy /y %T%\\authorized_keys W:\\ProgramData\\caker\\authorized_keys"))
	}

	func testOpenSSHArchivesArePinnedPerArchitecture() {
		let arm = WindowsInstallationMedia.openSSHArchive(for: .arm64)
		let intel = WindowsInstallationMedia.openSSHArchive(for: .amd64)

		XCTAssertEqual(arm.url.lastPathComponent, "OpenSSH-ARM64.zip")
		XCTAssertEqual(intel.url.lastPathComponent, "OpenSSH-Win64.zip")

		for release in [arm, intel] {
			XCTAssertEqual(release.url.scheme, "https")
			XCTAssertTrue(release.url.path.contains(WindowsInstallationMedia.openSSHRelease), "the archive comes from the pinned release")
			XCTAssertEqual(release.sha256.count, 64)
		}

		XCTAssertNotEqual(arm.sha256, intel.sha256)
	}

	private func makeOpenSSHZip(topFolder: String?, includingSshd: Bool) throws -> URL {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("openssh-test-\(UUID().uuidString)", isDirectory: true)
		let content = topFolder.map { directory.appendingPathComponent("tree/\($0)", isDirectory: true) } ?? directory.appendingPathComponent("tree", isDirectory: true)

		try FileManager.default.createDirectory(at: content, withIntermediateDirectories: true)
		try Data("exe".utf8).write(to: content.appendingPathComponent(includingSshd ? "sshd.exe" : "ssh.exe"))
		try Data("ps1".utf8).write(to: content.appendingPathComponent("install-sshd.ps1"))
		addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

		let archive = directory.appendingPathComponent("OpenSSH.zip")

		_ = try Process.capture("/bin/sh", ["-c", "cd '\(directory.appendingPathComponent("tree").path)' && /usr/bin/zip -q -r '\(archive.path)' ."])

		return archive
	}

	func testExtractOpenSSHDropsTheTopLevelFolder() throws {
		let archive = try self.makeOpenSSHZip(topFolder: "OpenSSH-ARM64", includingSshd: true)
		let destination = archive.deletingLastPathComponent().appendingPathComponent("out", isDirectory: true)

		try WindowsInstallationMedia.extractOpenSSH(archive, to: destination)

		XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("sshd.exe")), Data("exe".utf8))
		XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("install-sshd.ps1").path))
	}

	func testExtractOpenSSHAcceptsAFlatArchive() throws {
		let archive = try self.makeOpenSSHZip(topFolder: nil, includingSshd: true)
		let destination = archive.deletingLastPathComponent().appendingPathComponent("out", isDirectory: true)

		try WindowsInstallationMedia.extractOpenSSH(archive, to: destination)

		XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("sshd.exe").path))
	}

	func testExtractOpenSSHRejectsAnArchiveWithoutTheServer() throws {
		let archive = try self.makeOpenSSHZip(topFolder: "OpenSSH-ARM64", includingSshd: false)
		let destination = archive.deletingLastPathComponent().appendingPathComponent("out", isDirectory: true)

		XCTAssertThrowsError(try WindowsInstallationMedia.extractOpenSSH(archive, to: destination))
		XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
	}

	// MARK: - Display resizing

	/// Virtualization.framework's virtio GPU corrupts the picture once viogpudo re-creates its framebuffer for another
	/// width (only 1024 works), so the guest keeps the size it boots with and nothing follows the host's resizes.
	func testNothingFollowsTheHostsDisplayResizes() {
		let setup = WindowsInstallResources.setupComplete

		XCTAssertFalse(setup.contains("display.ps1"))
		XCTAssertFalse(setup.contains("CakerDisplay"))
		XCTAssertFalse(setup.contains("gpu="))

		for architecture in WindowsArchitecture.allCases {
			XCTAssertFalse(WindowsInstallResources.installScript(for: architecture).contains("display.ps1"))
		}
	}

	// MARK: - First-boot marker

	func testAgentIsRunningOnlyWhenTheMarkerSaysSo() {
		XCTAssertTrue(WindowsInstaller.agentIsRunning(marker: "done\r\nagent=0-running\r\nssh=0-running\r\n"))
		XCTAssertFalse(WindowsInstaller.agentIsRunning(marker: "done\r\nagent=0\r\n"), "installed, but not running")
		XCTAssertFalse(WindowsInstaller.agentIsRunning(marker: "done\r\nagent=1\r\n"))
		XCTAssertFalse(WindowsInstaller.agentIsRunning(marker: "done\r\nagent=none\r\n"))
	}

	// MARK: - GPU driver

	func testOnlyARM64UsesCakersGPUDriver() {
		XCTAssertTrue(WindowsArchitecture.arm64.usesCakerGPUDriver)
		XCTAssertFalse(WindowsArchitecture.amd64.usesCakerGPUDriver)
	}

	func testGPUDriverIsAnARM64KernelDriverWithItsCertificate() throws {
		let sys = WindowsGPUDriverBinaries.sys

		XCTAssertEqual(sys.prefix(2), Data("MZ".utf8))
		XCTAssertEqual(sys.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: Int($0.loadUnaligned(fromByteOffset: 0x3C, as: UInt32.self)) + 4, as: UInt16.self) }, 0xAA64, "an ARM64 image")

		XCTAssertTrue(String(decoding: WindowsGPUDriverBinaries.inf, as: UTF8.self).lowercased().contains("viogpudo.sys"))
		XCTAssertFalse(WindowsGPUDriverBinaries.cat.isEmpty)
		XCTAssertEqual(WindowsGPUDriverBinaries.certificate.first, 0x30, "a DER certificate")
		XCTAssertNotNil(SecCertificateCreateWithData(nil, WindowsGPUDriverBinaries.certificate as CFData), "the certificate parses")
	}

	func testInstallAddsTheTestSignedDriverOnARM64Only() {
		XCTAssertTrue(WindowsInstallResources.installScript(for: .arm64).contains("/Add-Driver /Driver:%T%\\drivers /Recurse /ForceUnsigned"))
		XCTAssertFalse(WindowsInstallResources.installScript(for: .amd64).contains("/ForceUnsigned"))

		for architecture in WindowsArchitecture.allCases {
			XCTAssertTrue(WindowsInstallResources.installScript(for: architecture).contains("copy /y %T%\\caker-test-signing.cer W:\\ProgramData\\caker\\caker-test-signing.cer"), "it is copied when the media has it")
		}
	}

	func testSetupTrustsTheCertificateAndTurnsTestSigningOn() {
		let setup = WindowsInstallResources.setupComplete

		XCTAssertTrue(setup.contains("certutil -f -addstore Root C:\\ProgramData\\caker\\caker-test-signing.cer"))
		XCTAssertTrue(setup.contains("certutil -f -addstore TrustedPublisher C:\\ProgramData\\caker\\caker-test-signing.cer"))
		XCTAssertTrue(setup.contains("bcdedit /set testsigning on"))
		XCTAssertTrue(setup.contains("gpudriver=%GPUDRV%"), "the outcome goes in the marker the host reads")
	}
}
