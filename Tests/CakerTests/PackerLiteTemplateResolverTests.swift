//
//  PackerLiteTemplateResolverTests.swift
//  CakerTests
//

import XCTest
import Foundation

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
			explicitVersion: .sequoia,
			ipswURL: ipswURL("my-custom-image.ipsw"))

		XCTAssertTrue(resolved.contains("boot_command"))
	}

	func testThrowsWhenVersionCannotBeDeterminedAtAll() {
		XCTAssertThrowsError(try PackerLiteTemplateResolver.resolve(
			explicitPath: nil,
			explicitVersion: nil,
			ipswURL: ipswURL("my-custom-image.ipsw")))
	}

	func testThrowsWhenNoBundledTemplateExistsForVersion() {
		// No built-in template is bundled for goldengate (macOS 27) yet.
		XCTAssertThrowsError(try PackerLiteTemplateResolver.resolve(
			explicitPath: nil,
			explicitVersion: .goldengate,
			ipswURL: ipswURL("my-custom-image.ipsw")))
	}

	func testAllBundledVersionsResolve() throws {
		for version: MacOSVersion in [.monterey, .ventura, .sonoma, .sequoia, .tahoe] {
			let resolved = try PackerLiteTemplateResolver.resolve(
				explicitPath: nil,
				explicitVersion: version,
				ipswURL: ipswURL("my-custom-image.ipsw"))

			XCTAssertTrue(resolved.contains("boot_command"), "\(version.rawValue) should resolve a bundled template")
		}
	}
}
