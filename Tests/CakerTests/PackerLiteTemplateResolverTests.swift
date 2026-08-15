//
//  PackerLiteTemplateResolverTests.swift
//  CakerTests
//

import XCTest
import Foundation
import GRPCLib

@testable import CakedLib

final class PackerLiteTemplateResolverTests: XCTestCase {
	private func ipswURL(_ filename: String) -> URL {
		URL(fileURLWithPath: "/tmp/\(filename)")
	}

	func testExplicitTemplatePathWinsOverFilenameDetection() throws {
		let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".yaml")
		let content = "boot_command:\n  - \"<enter>\"\n"

		try content.write(to: tmp, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: tmp) }

		let resolved = try PackerLiteTemplateResolver.resolve(
			explicitPath: tmp.path,
			explicitVersion: nil,
			ipswURL: ipswURL("UniversalMac_26.6_25G72_Restore.ipsw"))

		XCTAssertEqual(resolved, content)
	}

	func testAutoDetectsBundledTemplateFromIPSWFilename() throws {
		let resolved = try PackerLiteTemplateResolver.resolve(
			explicitPath: nil,
			explicitVersion: nil,
			ipswURL: ipswURL("UniversalMac_26.6_25G72_Restore.ipsw"))

		XCTAssertTrue(resolved.contains("boot_command"))
	}

	func testExplicitMacOSVersionUsedWhenFilenameCannotBeDetected() throws {
		let resolved = try PackerLiteTemplateResolver.resolve(
			explicitPath: nil,
			explicitVersion: .macos15,
			ipswURL: ipswURL("my-custom-image.ipsw"))

		XCTAssertTrue(resolved.contains("boot_command"))
	}

	func testThrowsWhenVersionCannotBeDeterminedAtAll() {
		XCTAssertThrowsError(try PackerLiteTemplateResolver.resolve(
			explicitPath: nil,
			explicitVersion: nil,
			ipswURL: ipswURL("my-custom-image.ipsw")))
	}

	func testAllBundledVersionsResolve() throws {
		// Every MacOSVersion case now ships a bundled template — macos27 (formerly goldengate) was
		// the last one still missing one.
		for version: MacOSVersion in [.macos12, .macos13, .macos14, .macos15, .macos26, .macos27] {
			let resolved = try PackerLiteTemplateResolver.resolve(
				explicitPath: nil,
				explicitVersion: version,
				ipswURL: ipswURL("my-custom-image.ipsw"))

			XCTAssertTrue(resolved.contains("boot_command"), "\(version.rawValue) should resolve a bundled template")
		}
	}

	// MARK: - Linux (ISO)

	func testLinuxExplicitTemplatePathWinsOverPlatformDetection() throws {
		let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".yaml")
		let content = "boot_command:\n  - title: t\n    command: \"<enter>\"\n"

		try content.write(to: tmp, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: tmp) }

		let resolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(
			explicitPath: tmp.path,
			imageURL: URL(fileURLWithPath: "/tmp/Fedora-Workstation-Live-x86_64-40.iso"))

		XCTAssertEqual(resolved, content)
	}

	func testAllBundledLinuxPlatformsResolveByFilename() throws {
		let cases: [(filename: String, platform: GRPCLib.SupportedPlatform)] = [
			("Fedora-Workstation-Live-x86_64-40-1.14.iso", .fedora),
			("CentOS-Stream-9-latest-x86_64-dvd1.iso", .centos),
			("rhel-9.4-x86_64-dvd.iso", .redhat),
			("openSUSE-Leap-15.6-DVD-x86_64-Media.iso", .openSUSE),
			("debian-12.5.0-amd64-DVD-1.iso", .debian),
		]

		for (filename, platform) in cases {
			let resolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: nil, imageURL: ipswURL(filename))

			XCTAssertNotNil(resolved, "\(filename) should resolve a bundled template (detected as \(platform.rawValue))")
			XCTAssertTrue(resolved?.contains("boot_command") == true)
		}
	}

	func testAllBundledLinuxPlatformsResolveDirectly() throws {
		for platform: GRPCLib.SupportedPlatform in [.fedora, .centos, .redhat, .openSUSE, .debian] {
			let resolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: nil, platform: platform)

			XCTAssertNotNil(resolved, "\(platform.rawValue) should resolve a bundled template")
			XCTAssertTrue(PackerLiteTemplateResolver.hasBuiltInLinuxTemplate(for: platform))
		}
	}

	func testFedoraDesktopFlagPicksBetweenWorkstationAndServerTemplates() throws {
		let desktopResolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: nil, platform: .fedora, desktop: true)
		let serverResolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: nil, platform: .fedora, desktop: false)

		XCTAssertNotNil(desktopResolved)
		XCTAssertNotNil(serverResolved)
		XCTAssertNotEqual(desktopResolved, serverResolved, "desktop and server should resolve to two different bundled templates")
		// Assert on each template's own header comment (its stable filename) rather than an
		// implementation detail of its boot_command flow, which could change independently of which
		// file gets selected.
		XCTAssertTrue(desktopResolved?.contains("# linux-fedora.packerlite.yaml") == true)
		XCTAssertTrue(serverResolved?.contains("# linux-fedora-server.packerlite.yaml") == true)
	}

	func testFedoraDesktopFlagIsIgnoredByOtherPlatforms() throws {
		for platform: GRPCLib.SupportedPlatform in [.centos, .redhat, .openSUSE, .debian] {
			let desktopResolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: nil, platform: platform, desktop: true)
			let serverResolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: nil, platform: platform, desktop: false)

			XCTAssertEqual(desktopResolved, serverResolved, "\(platform.rawValue) has no desktop/server split yet — both should resolve to the same single bundled template")
		}
	}

	func testUbuntuHasNoBuiltInLinuxTemplateAndResolvesToNil() throws {
		XCTAssertFalse(PackerLiteTemplateResolver.hasBuiltInLinuxTemplate(for: .ubuntu))

		let resolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: nil, platform: .ubuntu)

		XCTAssertNil(resolved, "Ubuntu has its own cloud-init/subiquity autoinstall path — no PackerLite template should be selected")
	}

	func testUnknownPlatformHasNoBuiltInLinuxTemplateAndResolvesToNil() throws {
		XCTAssertFalse(PackerLiteTemplateResolver.hasBuiltInLinuxTemplate(for: .unknown))

		let resolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: nil, imageURL: ipswURL("my-custom-linux.iso"))

		XCTAssertNil(resolved)
	}
}
