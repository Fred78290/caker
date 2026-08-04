//
//  PackerLiteTests.swift
//  CakerTests
//

import XCTest
import Foundation

@testable import CakedLib

final class PackerLiteTests: XCTestCase {

	// MARK: - Keyboard translation
	func testKeyboardTranslator() {
		if let translator = PackerLiteDriver.LayoutTranslator("com.apple.keylayout.US") {
			let translated = translator.translate(char: "A")

			XCTAssertEqual(translated, "Q")
		} else {
			XCTFail("Failed to translate char, keyboard not found")
		}
	}

	// MARK: - Token parsing

	func testWaitTokenUnits() throws {
		XCTAssertEqual(try BootCommand.parse("<wait60s><spacebar>"), [.wait(60), .press(.spacebar)])
		XCTAssertEqual(try BootCommand.parse("<wait5>"), [.wait(5)])
		XCTAssertEqual(try BootCommand.parse("<wait1m>"), [.wait(60)])
		XCTAssertEqual(try BootCommand.parse("<wait>"), [.wait(1)])
	}

	func testLiteralTypingBetweenTokens() throws {
		XCTAssertEqual(
			try BootCommand.parse("<wait30s>italiano<esc>english<enter>"),
			[.wait(30), .type("italiano"), .press(.esc), .type("english"), .press(.enter)]
		)
	}

	func testModifierOnOffPairing() throws {
		XCTAssertEqual(
			try BootCommand.parse("<leftShiftOn><tab><leftShiftOff><spacebar>"),
			[.modifierOn(.leftShift), .press(.tab), .modifierOff(.leftShift), .press(.spacebar)]
		)
	}

	func testClickTextToken() throws {
		XCTAssertEqual(
			try BootCommand.parse("<wait30s><click 'Select Your Country or Region'><wait5s>united states"),
			[.wait(30), .clickText("Select Your Country or Region"), .wait(5), .type("united states")]
		)
	}

	func testClickCoordinatesToken() throws {
		XCTAssertEqual(try BootCommand.parse("<click 100,200>"), [.click(x: 100, y: 200)])
	}

	func testFunctionKeyToken() throws {
		XCTAssertEqual(
			try BootCommand.parse("<leftAltOn><f5><leftAltOff>"),
			[.modifierOn(.leftAlt), .press(.function(5)), .modifierOff(.leftAlt)]
		)
	}

	func testUnknownTokenThrows() {
		XCTAssertThrowsError(try BootCommand.parse("<notAToken>")) { error in
			XCTAssertEqual(error as? BootCommandParseError, .unknownToken("notAToken"))
		}
	}

	func testUnterminatedTokenThrows() {
		XCTAssertThrowsError(try BootCommand.parse("<wait30s")) { error in
			guard case .unterminatedToken = error as? BootCommandParseError else {
				return XCTFail("expected unterminatedToken, got \(error)")
			}
		}
	}

	func testMalformedClickThrows() {
		XCTAssertThrowsError(try BootCommand.parse("<click 'unterminated>")) { error in
			guard case .malformedClick = error as? BootCommandParseError else {
				return XCTFail("expected malformedClick, got \(error)")
			}
		}
	}

	// MARK: - Reference templates (transcribed from templates/macos/*.pkr.hcl)

	func testVanillaSequoiaBootCommandParsesEveryStep() throws {
		for (index, command) in Self.vanillaSequoiaBootCommand.enumerated() {
			XCTAssertNoThrow(try BootCommand.parse(command), "boot_command[\(index)] failed to parse: \(command)")
		}
	}

	func testVanillaTahoeBootCommandParsesEveryStep() throws {
		for (index, command) in Self.vanillaTahoeBootCommand.enumerated() {
			XCTAssertNoThrow(try BootCommand.parse(command), "boot_command[\(index)] failed to parse: \(command)")
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
		  - "<wait10s>${var.username}<tab>${var.password}<tab>${var.greeting}<enter>"
		"""

		let defaults = try PackerLiteTemplate.load(from: yaml, variables: ["username": "admin", "password": "admin"])
		XCTAssertEqual(defaults.bootCommand?.first, "<wait10s>admin<tab>admin<tab>hello<enter>")

		let overridden = try PackerLiteTemplate.load(from: yaml, variables: ["username": "admin", "password": "hunter2"])
		XCTAssertEqual(overridden.bootCommand?.first, "<wait10s>admin<tab>hunter2<tab>hello<enter>")
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

	func testParsedBootCommandWrapsFailureWithIndex() throws {
		let template = try PackerLiteTemplate.load(from: """
		boot_command:
		  - "<enter>"
		  - "<notAToken>"
		""")

		XCTAssertThrowsError(try template.parsedBootCommand()) { error in
			guard case .invalidBootCommand(let index, let command, _) = error as? PackerLiteTemplateError else {
				return XCTFail("expected invalidBootCommand, got \(error)")
			}
			XCTAssertEqual(index, 1)
			XCTAssertEqual(command, "<notAToken>")
		}
	}

	// MARK: - MacOSVersion

	func testMacOSVersionDetectFromRealIPSWFilenames() {
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_26.6_25G72_Restore.ipsw"), .tahoe)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_15.6.1_24G90_Restore.ipsw"), .sequoia)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_27.0_26A5388g_Restore.ipsw"), .goldengate)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_14.6.1_23G93_Restore.ipsw"), .sonoma)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_13.6_22G120_Restore.ipsw"), .ventura)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_12.7.6_21H1320_Restore.ipsw"), .monterey)
		XCTAssertEqual(
			MacOSVersion.detect(fromIPSWFilename: "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-65618/UniversalMac_26.6_25G72_Restore.ipsw"),
			.tahoe, "should work on a full URL, not just a bare filename")
	}

	func testMacOSVersionDetectReturnsNilForUnknownOrUnrecognizedFilenames() {
		XCTAssertNil(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_11.7.10_20G1345_Restore.ipsw"), "macOS 11 (Big Sur) has no bundled template/codename")
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

	func testVanillaSequoiaPackerLiteTemplateFileLoadsAndParses() throws {
		// Mirrors what VMBuilder.swift injects: username/password come from CakeConfig, not the template.
		let template = try PackerLiteTemplate.load(
			fromFile: Self.templatesDirectory.appendingPathComponent("vanilla-sequoia.packerlite.yaml").path,
			variables: ["username": "admin", "password": "admin"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains { $0.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		XCTAssertNoThrow(try template.parsedBootCommand())
	}

	func testVanillaTahoePackerLiteTemplateFileLoadsAndParses() throws {
		let template = try PackerLiteTemplate.load(
			fromFile: Self.templatesDirectory.appendingPathComponent("vanilla-tahoe.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains(where: { $0.contains("hunter2") }) == true)
		XCTAssertTrue(template.bootCommand?.contains { $0.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		XCTAssertNoThrow(try template.parsedBootCommand())
	}

	func testVanillaMontereyPackerLiteTemplateFileLoadsAndParses() throws {
		let template = try PackerLiteTemplate.load(
			fromFile: Self.templatesDirectory.appendingPathComponent("vanilla-monterey.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains(where: { $0.contains("hunter2") }) == true)
		XCTAssertTrue(template.bootCommand?.contains { $0.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		XCTAssertNoThrow(try template.parsedBootCommand())
	}

	func testVanillaVenturaPackerLiteTemplateFileLoadsAndParses() throws {
		let template = try PackerLiteTemplate.load(
			fromFile: Self.templatesDirectory.appendingPathComponent("vanilla-ventura.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains(where: { $0.contains("hunter2") }) == true)
		XCTAssertTrue(template.bootCommand?.contains { $0.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		XCTAssertNoThrow(try template.parsedBootCommand())
	}

	func testVanillaSonomaPackerLiteTemplateFileLoadsAndParses() throws {
		let template = try PackerLiteTemplate.load(
			fromFile: Self.templatesDirectory.appendingPathComponent("vanilla-sonoma.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse((template.bootCommand ?? []).isEmpty)
		XCTAssertTrue(template.bootCommand?.contains(where: { $0.contains("hunter2") }) == true)
		XCTAssertTrue(template.bootCommand?.contains { $0.contains("${var.") } == false, "all ${var.*} placeholders should have been substituted")
		XCTAssertNoThrow(try template.parsedBootCommand())
	}

	private static var templatesDirectory: URL {
		URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()
			.deletingLastPathComponent()
			.deletingLastPathComponent()
			.appendingPathComponent("Sources/cakedlib/PackerLite/Resources")
	}

	// MARK: - Fixtures

	private static let vanillaSequoiaBootCommand: [String] = [
		"<wait60s><spacebar>",
		"<wait30s>italiano<esc>english<enter>",
		"<wait30s><click 'Select Your Country or Region'><wait5s>united states<leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><tab><tab><spacebar><tab><tab><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s>Managed via Tart<tab>admin<tab>admin<tab>admin<tab><tab><spacebar><tab><tab><spacebar>",
		"<wait120s><leftAltOn><f5><leftAltOff>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><spacebar>",
		"<wait10s><tab><tab>UTC<enter><leftShiftOn><tab><tab><leftShiftOff><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><spacebar>",
		"<wait10s><tab><spacebar><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><spacebar>",
		"<wait10s><spacebar>",
		"<leftAltOn><f5><leftAltOff>",
		"<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
		"<wait10s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",
		"<wait10s><leftAltOn>q<leftAltOff>",
		"<wait10s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",
		"<wait10s><leftCtrlOn><f2><leftCtrlOff><right><right><right><down>Sharing<enter>",
		"<wait10s><tab><tab><tab><tab><tab><tab><tab><spacebar>",
		"<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",
		"<wait10s><leftAltOn>q<leftAltOff>",
		"<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
		"<wait10s>sudo spctl --global-disable<enter>",
		"<wait10s>admin<enter>",
		"<wait10s><leftAltOn>q<leftAltOff>",
		"<wait10s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",
		"<wait10s><leftCtrlOn><f2><leftCtrlOff><right><right><right><down>Privacy & Security<enter>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff>",
		"<wait10s><down><wait1s><down><wait1s><enter>",
		"<wait10s>admin<enter>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><wait1s><spacebar>",
		"<wait10s><leftAltOn>q<leftAltOff>",
	]

	private static let vanillaTahoeBootCommand: [String] = [
		"<wait60s><spacebar>",
		"<wait30s>italiano<esc>english<enter>",
		"<wait60s><click 'Select Your Country or Region'><wait5s>united states<leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><tab><tab><spacebar><tab><tab><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><tab><tab><tab><tab><tab>Managed via Tart<tab>admin<tab>admin<tab>admin<tab><tab><spacebar><tab><tab><spacebar>",
		"<wait120s><leftAltOn><f5><leftAltOff>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar><up><spacebar>",
		"<wait10s><tab><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><spacebar>",
		"<wait10s><tab><tab><tab><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><spacebar>",
		"<wait10s><tab><tab><tab>UTC<enter><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><tab><spacebar>",
		"<wait10s><tab><spacebar><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><leftShiftOn><tab><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><spacebar>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",
		"<wait10s><tab><tab><spacebar>",
		"<wait30s><spacebar>",
		"<wait10s><leftAltOn><f5><leftAltOff>",
		"<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<wait10s><enter>",
		"<wait10s><wait10s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",
		"<wait10s>open '/System/Applications/System Settings.app'<enter>",
		"<wait120s>",
		"<wait10s><leftCtrlOn><f2><leftCtrlOff><right><right><right><down>Sharing<enter>",
		"<wait10s><tab><tab><tab><tab><tab><spacebar>",
		"<wait10s>admin<enter>",
		"<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",
		"<wait10s><leftAltOn>q<leftAltOff>",
		"<wait10s>sudo spctl --global-disable<enter>",
		"<wait10s>admin<enter>",
		"<wait10s>open '/System/Applications/System Settings.app'<enter>",
		"<wait10s><leftCtrlOn><f2><leftCtrlOff><right><right><right><down>Privacy & Security<enter>",
		"<wait10s><leftShiftOn><tab><tab><tab><tab><tab><tab><leftShiftOff>",
		"<wait10s><down><wait1s><down><wait1s><enter>",
		"<wait10s>admin<enter>",
		"<wait10s><leftShiftOn><tab><leftShiftOff><wait1s><spacebar>",
		"<wait10s><leftAltOn>q<leftAltOff>",
	]
}
