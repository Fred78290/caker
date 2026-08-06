//
//  PackerLiteTests.swift
//  CakerTests
//

import XCTest
import Foundation

@testable import CakedLib

final class PackerLiteTests: XCTestCase {

	// MARK: - Keyboard translation
	@MainActor func testKeyboardTranslator() {
		if let translator = PackerLiteDriver.LayoutTranslator("com.apple.keylayout.US") {
			let translated = translator.translate(char: "A")

			XCTAssertNotNil(translated, "Failed to translate char, keyboard not found")
		} else {
			XCTFail("Failed to translate char, keyboard not found")
		}
	}

	@MainActor func testCompareCurrentKeyboard() {
		if let translator = PackerLiteDriver.LayoutTranslator("com.apple.keylayout.US") {
			var original: [Character] = []
			var translated: [Character] = []

			for ch in 32..<128 {
				let c = Character(UnicodeScalar(ch)!)

				original.append(c)
				if let cc = translator.translate(char: c) {
					translated.append(cc.characters.first ?? "¿")
				} else {
					translated.append("¿") // placeholder for untranslatable
				}
			}

			let originalDisplay = "|" + original.map { String($0) }.joined(separator: "|") + "|"
			let translatedDisplay = "|" + translated.map { String($0) }.joined(separator: "|") + "|"

			print("- \(originalDisplay)\n- \(translatedDisplay)")
		} else {
			XCTFail("Failed to translate char, keyboard not found")
		}
	}
	// MARK: - Token parsing

	/// `BootCommand.parse` takes a `{title, command}` `PackerLiteTemplate.Command`, not a bare
	/// string — this wraps a raw boot_command string for tests that only care about the parsed steps.
	private func parseSteps(_ raw: String, title: String = "test") async throws -> [BootCommandStep.Step] {
		try await BootCommand.parse(PackerLiteTemplate.Command(title: title, command: raw)).steps
	}

	func testWaitTokenUnits() async throws {
		let a = try await parseSteps("<wait60s><spacebar>")
		XCTAssertEqual(a, [.wait(60), .press(.spacebar)])
		let b = try await parseSteps("<wait5>")
		XCTAssertEqual(b, [.wait(5)])
		let c = try await parseSteps("<wait1m>")
		XCTAssertEqual(c, [.wait(60)])
		let d = try await parseSteps("<wait>")
		XCTAssertEqual(d, [.wait(1)])
	}

	func testLiteralTypingBetweenTokens() async throws {
		let parsed = try await parseSteps("<wait30s>italiano<esc>english<enter>")
		XCTAssertEqual(
			parsed,
			[.wait(30), .type("italiano"), .press(.esc), .type("english"), .press(.enter)]
		)
	}

	func testModifierOnOffPairing() async throws {
		let parsed = try await parseSteps("<leftShiftOn><tab><leftShiftOff><spacebar>")
		XCTAssertEqual(
			parsed,
			[.modifierOn(.leftShift), .press(.tab), .modifierOff(.leftShift), .press(.spacebar)]
		)
	}

	func testFnModifierOnOffPairing() async throws {
		let parsed = try await parseSteps("<leftAltOn><fnOn><f5><fnOff><leftAltOff>")
		XCTAssertEqual(
			parsed,
			[.modifierOn(.leftAlt), .modifierOn(.function), .press(.function(5)), .modifierOff(.function), .modifierOff(.leftAlt)]
		)
	}

	func testClickTextToken() async throws {
		let parsed = try await parseSteps("<wait30s><click 'Select Your Country or Region'><wait5s>united states")
		XCTAssertEqual(
			parsed,
			[.wait(30), .clickText("Select Your Country or Region"), .wait(5), .type("united states")]
		)
	}

	func testClickCoordinatesToken() async throws {
		let parsed = try await parseSteps("<click 100,200>")
		XCTAssertEqual(parsed, [.click(x: 100, y: 200)])
	}

	func testFunctionKeyToken() async throws {
		let parsed = try await parseSteps("<leftAltOn><f5><leftAltOff>")
		XCTAssertEqual(
			parsed,
			[.modifierOn(.leftAlt), .press(.function(5)), .modifierOff(.leftAlt)]
		)
	}

	func testFunctionKeyTokenUpToF20() async throws {
		let parsed = try await parseSteps("<f20>")
		XCTAssertEqual(parsed, [.press(.function(20))])
	}

	func testUnknownTokenThrows() async {
		do {
			_ = try await parseSteps("<notAToken>")
			XCTFail("expected unknownToken error")
		} catch {
			XCTAssertEqual(error as? BootCommandParseError, .unknownToken("notAToken"))
		}
	}

	func testUnterminatedTokenThrows() async {
		do {
			_ = try await parseSteps("<wait30s")
			XCTFail("expected unterminatedToken error")
		} catch {
			guard case .unterminatedToken = error as? BootCommandParseError else {
				return XCTFail("expected unterminatedToken, got \(error)")
			}
		}
	}

	func testMalformedClickThrows() async {
		do {
			_ = try await parseSteps("<click 'unterminated>")
			XCTFail("expected malformedClick error")
		} catch {
			guard case .malformedClick = error as? BootCommandParseError else {
				return XCTFail("expected malformedClick, got \(error)")
			}
		}
	}

	// MARK: - Template loading & variable substitution

	func testTemplateVariableSubstitutionUsesDefaultsThenOverrides() throws {
		// username/password are intentionally NOT template-declared fields — the engine injects
		// them as overrides from CakeConfig.configuredUser/configuredPassword (see VMBuilder.swift),
		// so there is exactly one source of truth for the VM's account. This just exercises the
		// generic ${var.NAME} substitution mechanism those overrides rely on.
		let yaml = """
		variables:
		  greeting: hello
		boot_command:
		  - title: Sign in
		    command: "<wait10s>${var.username}<tab>${var.password}<tab>${var.greeting}<enter>"
		"""

		let defaults = try PackerLiteTemplate.load(from: yaml, variables: ["username": "admin", "password": "admin"])
		XCTAssertEqual(defaults.bootCommand?.first?.command, "<wait10s>admin<tab>admin<tab>hello<enter>")

		let overridden = try PackerLiteTemplate.load(from: yaml, variables: ["username": "admin", "password": "hunter2"])
		XCTAssertEqual(overridden.bootCommand?.first?.command, "<wait10s>admin<tab>hunter2<tab>hello<enter>")
	}

	func testTemplateDurationDefaultsAndParsing() throws {
		let withDurations = try PackerLiteTemplate.load(from: """
		create_grace_time: 30s
		boot_timeout: 45m
		""")
		XCTAssertEqual(withDurations.resolvedCreateGraceTime, 30)
		XCTAssertEqual(withDurations.resolvedBootTimeout, 45 * 60)

		let withoutDurations = try PackerLiteTemplate.load(from: "boot_command: []")
		XCTAssertEqual(withoutDurations.resolvedCreateGraceTime, 30)
		XCTAssertEqual(withoutDurations.resolvedBootTimeout, 45 * 60)
	}

	func testParsedBootCommandWrapsFailureWithOffendingCommand() async throws {
		let template = try PackerLiteTemplate.load(from: """
		boot_command:
		  - title: Fine
		    command: "<enter>"
		  - title: Broken
		    command: "<notAToken>"
		""")

		do {
			_ = try await template.parsedBootCommand()
			XCTFail("expected invalidBootCommand error")
		} catch {
			guard case .invalidBootCommand(let command, _) = error as? PackerLiteTemplateError else {
				return XCTFail("expected invalidBootCommand, got \(error)")
			}
			XCTAssertEqual(command.title, "Broken")
			XCTAssertEqual(command.command, "<notAToken>")
		}
	}

	// MARK: - MacOSVersion

	func testMacOSVersionDetectFromRealIPSWFilenames() {
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_26.6_25G72_Restore.ipsw")?.name, .tahoe)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_26.6_25G72_Restore.ipsw")?.version, "26.6")
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_15.6.1_24G90_Restore.ipsw")?.name, .sequoia)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_15.6.1_24G90_Restore.ipsw")?.version, "15.6")
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_27.0_26A5388g_Restore.ipsw")?.name, .goldengate)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_14.6.1_23G93_Restore.ipsw")?.name, .sonoma)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_13.6_22G120_Restore.ipsw")?.name, .ventura)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_12.7.6_21H1320_Restore.ipsw")?.name, .monterey)
		XCTAssertEqual(
			MacOSVersion.detect(fromIPSWFilename: "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-65618/UniversalMac_26.6_25G72_Restore.ipsw")?.name,
			.tahoe, "should work on a full URL, not just a bare filename")
	}

	func testMacOSVersionDetectReturnsNilForUnknownOrUnrecognizedFilenames() {
		XCTAssertNil(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_11.7.10_20G1345_Restore.ipsw")?.name, "macOS 11 (Big Sur) has no bundled template/codename")
		XCTAssertNil(MacOSVersion.detect(fromIPSWFilename: "my-custom-image.ipsw"))
		XCTAssertNil(MacOSVersion.detect(fromIPSWFilename: ""))
	}

	func testMacOSVersionExpressibleFromRawValue() {
		XCTAssertEqual(MacOSVersion(rawValue: "monterey"), .monterey)
		XCTAssertEqual(MacOSVersion(rawValue: "ventura"), .ventura)
		XCTAssertEqual(MacOSVersion(rawValue: "sonoma"), .sonoma)
		XCTAssertEqual(MacOSVersion(rawValue: "sequoia"), .sequoia)
		XCTAssertEqual(MacOSVersion(rawValue: "tahoe"), .tahoe)
		XCTAssertEqual(MacOSVersion(rawValue: "goldengate"), .goldengate)
		XCTAssertNil(MacOSVersion(rawValue: "bigsur"))
	}

	// MARK: - Real repo templates (Sources/cakedlib/PackerLite/Resources/*.packerlite.yaml)

	func testVanillaSequoiaPackerLiteTemplateFileLoadsAndParses() async throws {
		// Mirrors what VMBuilder.swift injects: username/password come from CakeConfig, not the template.
		let template = try PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-sequoia.packerlite.yaml").path,
			variables: ["username": "admin", "password": "admin"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains { $0.command.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		do {
			_ = try await template.parsedBootCommand()
		} catch {
			XCTFail("unexpected error: \(error)")
		}
	}

	func testVanillaTahoePackerLiteTemplateFileLoadsAndParses() async throws {
		let template = try PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-tahoe.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains(where: { $0.command.contains("hunter2") }) == true)
		XCTAssertTrue(template.bootCommand?.contains { $0.command.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		do {
			_ = try await template.parsedBootCommand()
		} catch {
			XCTFail("unexpected error: \(error)")
		}
	}

	func testVanillaMontereyPackerLiteTemplateFileLoadsAndParses() async throws {
		let template = try PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-monterey.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains(where: { $0.command.contains("hunter2") }) == true)
		XCTAssertTrue(template.bootCommand?.contains { $0.command.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		do {
			_ = try await template.parsedBootCommand()
		} catch {
			XCTFail("unexpected error: \(error)")
		}
	}

	func testVanillaVenturaPackerLiteTemplateFileLoadsAndParses() async throws {
		let template = try PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-ventura.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains(where: { $0.command.contains("hunter2") }) == true)
		XCTAssertTrue(template.bootCommand?.contains { $0.command.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		do {
			_ = try await template.parsedBootCommand()
		} catch {
			XCTFail("unexpected error: \(error)")
		}
	}

	func testVanillaSonomaPackerLiteTemplateFileLoadsAndParses() async throws {
		let template = try PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-sonoma.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains(where: { $0.command.contains("hunter2") }) == true)
		XCTAssertTrue(template.bootCommand?.contains { $0.command.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		do {
			_ = try await template.parsedBootCommand()
		} catch {
			XCTFail("unexpected error: \(error)")
		}
	}

	// MARK: - Reference Linux templates (templates/linux/*.packerlite.yaml, not bundled/auto-resolved)

	func testFedoraWorkstationPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("fedora-workstation.packerlite.yaml")
	}

	func testCentOSStreamPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("centos-stream.packerlite.yaml")
	}

	func testRHELPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("rhel.packerlite.yaml")
	}

	func testOpenSUSELeapPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("opensuse-leap.packerlite.yaml")
	}

	func testDebianPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("debian.packerlite.yaml")
	}

	private func assertLinuxTemplateLoadsAndParses(_ filename: String) async throws {
		let template = try PackerLiteTemplate.load(
			fromFile: Self.linuxTemplatesDirectory.appendingPathComponent(filename).path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains(where: { $0.command.contains("hunter2") }) == true)
		XCTAssertTrue(template.bootCommand?.contains { $0.command.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		do {
			_ = try await template.parsedBootCommand()
		} catch {
			XCTFail("unexpected error: \(error)")
		}
	}

	private static var repoRoot: URL {
		URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
			.deletingLastPathComponent()
	}

	private static var macTemplatesDirectory: URL {
		repoRoot.appendingPathComponent("Sources/cakedlib/PackerLite/Resources")
	}

	private static var linuxTemplatesDirectory: URL {
		repoRoot.appendingPathComponent("templates/linux")
	}
}
