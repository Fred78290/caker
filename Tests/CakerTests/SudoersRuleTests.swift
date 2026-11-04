//
//  SudoersRuleTests.swift
//  CakerTests
//

import CryptoKit
import Foundation
import XCTest

@testable import CakedLib

final class SudoersRuleTests: XCTestCase {
	private var directory: URL!

	override func setUpWithError() throws {
		self.directory = FileManager.default.temporaryDirectory.appendingPathComponent("sudoers-rule-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try? FileManager.default.removeItem(at: self.directory)
	}

	func testSHA256MatchesCryptoKit() throws {
		let file = self.directory.appendingPathComponent("caked")
		let data = Data((0..<(3 << 20)).map { UInt8($0 & 0xff) })

		try data.write(to: file)

		let expected = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

		XCTAssertEqual(try SudoCaked.sha256Hex(of: file), expected)
	}

	func testEscapesWhatSudoersUsesAsSeparators() {
		XCTAssertEqual(SudoCaked.escapedForSudoers("/Applications/Caker.app/caked"), "/Applications/Caker.app/caked")
		XCTAssertEqual(SudoCaked.escapedForSudoers("/Apps/My Caker/a,b:c=d"), "/Apps/My\\ Caker/a\\,b\\:c\\=d")
	}

	func testUserOwnedBinaryIsNotTrusted() throws {
		// A freshly written file belongs to the user running the tests (not root), like a drag-and-drop install or a DerivedData build.
		let file = self.directory.appendingPathComponent("caked")

		try Data("#!/bin/sh\n".utf8).write(to: file)

		if geteuid() != 0 {
			XCTAssertFalse(SudoCaked.isProtectedBundledBinary(file))
			XCTAssertThrowsError(try SudoCaked.sudoersRule(uid: getuid(), caked: file))
		}
	}

	func testSystemBinaryIsProtected() {
		XCTAssertTrue(SudoCaked.isProtectedBundledBinary(URL(fileURLWithPath: "/usr/bin/true")))
	}

	func testRuleNamesTheUserAndPinsTheDigest() throws {
		// /bin/echo is root-owned and unmodifiable, so it stands for a package-installed caked.
		let binary = URL(fileURLWithPath: "/bin/echo")
		let rule = try SudoCaked.sudoersRule(uid: 501, caked: binary)
		let digest = try SudoCaked.sha256Hex(of: binary)

		XCTAssertEqual(rule, "#501 ALL=(root:wheel) NOPASSWD:SETENV: sha256:\(digest) /bin/echo\n")
		XCTAssertFalse(rule.contains("%everyone"))
	}

	func testRuleIsAcceptedByVisudo() throws {
		let rule = try SudoCaked.sudoersRule(uid: 501, caked: URL(fileURLWithPath: "/bin/echo"))
		let file = self.directory.appendingPathComponent("caked-sudoers")

		try rule.write(to: file, atomically: true, encoding: .utf8)

		let process = Process()

		process.executableURL = URL(fileURLWithPath: "/usr/sbin/visudo")
		process.arguments = ["-c", "-f", file.path]
		process.standardOutput = FileHandle.nullDevice
		process.standardError = FileHandle.nullDevice

		do {
			try process.run()
		} catch {
			throw XCTSkip("visudo is not available: \(error)")
		}

		process.waitUntilExit()

		XCTAssertEqual(process.terminationStatus, 0)
	}
}
