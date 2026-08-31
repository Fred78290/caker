//
//  PackerLiteTests.swift
//  CakerTests
//

import XCTest
import Foundation
import GRPCLib

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

	/// `BootCommand.parse` takes a `{title, commands}` `PackerLiteTemplate.Command` (`commands` is a
	/// list of token fragments concatenated together, not a bare string) — this wraps a single raw
	/// boot_command string for tests that only care about the parsed steps.
	private func parseSteps(_ raw: String, title: String = "test") async throws -> [BootCommandStep.Step] {
		try await BootCommand.parse(PackerLiteTemplate.Command(title: title, commands: [raw])).steps
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

	func testRepeatSuffixOnNamedKey() async throws {
		let parsed = try await parseSteps("<enter repeat=3>")
		XCTAssertEqual(parsed, [.press(.enter, repeated: 3)])
	}

	func testClickTextLegacyQuotedTokenDefaultsTimeoutToTen() async throws {
		let parsed = try await parseSteps("<wait30s><click 'Select Your Country or Region'><wait5s>united states")
		XCTAssertEqual(
			parsed,
			[.wait(30), .clickText(["Select Your Country or Region"], timeout: 10), .wait(5), .type("united states")]
		)
	}

	func testClickTextAttributeStyleWithExplicitTimeout() async throws {
		let parsed = try await parseSteps("<click timeout=30 text='Select Your Country or Region'>")
		XCTAssertEqual(parsed, [.clickText(["Select Your Country or Region"], timeout: 30)])
	}

	func testClickCoordinatesToken() async throws {
		let parsed = try await parseSteps("<click 100,200>")
		XCTAssertEqual(parsed, [.click(CGPoint(x: 100, y: 200))])
	}

	func testClickPointAttributeStyle() async throws {
		let parsed = try await parseSteps("<click point=\"100,200\">")
		XCTAssertEqual(parsed, [.click(CGPoint(x: 100, y: 200))])
	}

	func testLocateTokenAttributeStyle() async throws {
		let parsed = try await parseSteps("<locate timeout=15 text='Continue'>")
		XCTAssertEqual(parsed, [.locate(["Continue"], timeout: 15)])
	}

	func testLocateTokenQuotedForm() async throws {
		let parsed = try await parseSteps("<locate 'Continue'>")
		XCTAssertEqual(parsed, [.locate(["Continue"], timeout: 10)])
	}

	func testLocateTokenMultiTextOrMatching() async throws {
		let parsed = try await parseSteps("<locate timeout=15 text='Accept|Continue'>")
		XCTAssertEqual(parsed, [.locate(["Accept", "Continue"], timeout: 15)])
	}

	func testSkipStepIfNotFoundAttributeStyle() async throws {
		let parsed = try await parseSteps("<skipStepIfNotFound timeout=5 steps=2 text='Optional Screen'>")
		XCTAssertEqual(parsed, [.skipStepIfNotFound(["Optional Screen"], 2, timeout: 5)])
	}

	func testSkipStepIfNotFoundQuotedFormDefaultsStepsAndTimeout() async throws {
		let parsed = try await parseSteps("<skipStepIfNotFound 'Optional Screen'>")
		XCTAssertEqual(parsed, [.skipStepIfNotFound(["Optional Screen"], 1, timeout: 10)])
	}

	func testScrollTokenAttributeStyle() async throws {
		let parsed = try await parseSteps("<scroll horizontal=5 vertical=-10>")
		XCTAssertEqual(parsed, [.scroll(horizontal: 5, vertical: -10)])
	}

	func testScrollTokenBareVerticalForm() async throws {
		let parsed = try await parseSteps("<scroll 20>")
		XCTAssertEqual(parsed, [.scroll(horizontal: 0, vertical: 20)])
	}

	func testVoiceOverOnBareToken() async throws {
		let parsed = try await parseSteps("<voiceOverOn>")
		XCTAssertEqual(parsed, [.voiceOverOn(confirm: false)])
	}

	func testVoiceOverOnConfirmAttribute() async throws {
		let parsed = try await parseSteps("<voiceOverOn confirm=true>")
		XCTAssertEqual(parsed, [.voiceOverOn(confirm: true)])
	}

	func testVoiceOverOnConfirmAttributeQuotedForm() async throws {
		// This is the exact shape ActionRecorder.Step.command(...) emits for a recorded
		// .voiceOverOn(confirm: true) step (Sources/cakedlib/PackerLite/ActionRecorder.swift) —
		// confirms the recorder's own output round-trips through the parser correctly.
		let parsed = try await parseSteps("<voiceOverOn confirm=\"true\">")
		XCTAssertEqual(parsed, [.voiceOverOn(confirm: true)])
	}

	func testVoiceOverOffToken() async throws {
		let parsed = try await parseSteps("<voiceOverOff>")
		XCTAssertEqual(parsed, [.voiceOverOff])
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

	func testTemplateVariableSubstitutionUsesDefaultsThenOverrides() async throws {
		// username/password are intentionally NOT template-declared fields — the engine injects
		// them as overrides from CakeConfig.configuredUser/configuredPassword (see VMBuilder.swift),
		// so there is exactly one source of truth for the VM's account. This just exercises the
		// generic ${var.NAME} substitution mechanism those overrides rely on.
		let yaml = """
		variables:
		  greeting: hello
		boot_command:
		  - title: Sign in
		    commands:
		      - "<wait10s>${var.username}<tab>${var.password}<tab>${var.greeting}<enter>"
		"""

		let defaults = try await PackerLiteTemplate.load(from: yaml, variables: ["username": "admin", "password": "admin"])
		XCTAssertEqual(defaults.bootCommand.first?.steps, [.wait(10), .type("admin"), .press(.tab), .type("admin"), .press(.tab), .type("hello"), .press(.enter)])

		let overridden = try await PackerLiteTemplate.load(from: yaml, variables: ["username": "admin", "password": "hunter2"])
		XCTAssertEqual(overridden.bootCommand.first?.steps, [.wait(10), .type("admin"), .press(.tab), .type("hunter2"), .press(.tab), .type("hello"), .press(.enter)])
	}

	func testTemplateBootTimeoutDefaultsAndParsing() async throws {
		let withDuration = try await PackerLiteTemplate.load(from: "boot_timeout: 45m")
		XCTAssertEqual(withDuration.bootTimeout, 45 * 60)

		let withoutDuration = try await PackerLiteTemplate.load(from: "boot_command: []")
		XCTAssertEqual(withoutDuration.bootTimeout, 45 * 60)
	}

	func testTemplateIgnoresUnknownCreateGraceTimeKey() async throws {
		// create_grace_time was removed as dead code (PackerLiteEngine never read it), but older or
		// hand-written templates may still declare it — decoding must tolerate the unknown key rather
		// than failing the whole template load.
		let template = try await PackerLiteTemplate.load(from: """
		create_grace_time: 30s
		boot_timeout: 45m
		""")
		XCTAssertEqual(template.bootTimeout, 45 * 60)
	}

	func testParsedBootCommandWrapsFailureWithOffendingCommand() async throws {
		// Parsing now happens inside `load` itself (see ParsedPackerLiteTemplate), so a malformed
		// boot_command entry surfaces as a throw from `load`, not a separate parsing step.
		do {
			_ = try await PackerLiteTemplate.load(from: """
			boot_command:
			  - title: Fine
			    commands:
			      - "<enter>"
			  - title: Broken
			    commands:
			      - "<notAToken>"
			""")
			XCTFail("expected invalidBootCommand error")
		} catch {
			guard case .invalidBootCommand(let command, _) = error as? PackerLiteTemplateError else {
				return XCTFail("expected invalidBootCommand, got \(error)")
			}
			XCTAssertEqual(command.title, "Broken")
			XCTAssertEqual(command.commands, ["<notAToken>"])
		}
	}

	// MARK: - MacOSVersion

	func testMacOSVersionDetectFromRealIPSWFilenames() {
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_26.6_25G72_Restore.ipsw")?.name, .macos26)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_26.6_25G72_Restore.ipsw")?.version, "26.6")
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_15.6.1_24G90_Restore.ipsw")?.name, .macos15)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_15.6.1_24G90_Restore.ipsw")?.version, "15.6")
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_27.0_26A5388g_Restore.ipsw")?.name, .macos27)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_14.6.1_23G93_Restore.ipsw")?.name, .macos14)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_13.6_22G120_Restore.ipsw")?.name, .macos13)
		XCTAssertEqual(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_12.7.6_21H1320_Restore.ipsw")?.name, .macos12)
		XCTAssertEqual(
			MacOSVersion.detect(fromIPSWFilename: "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-65618/UniversalMac_26.6_25G72_Restore.ipsw")?.name,
			.macos26, "should work on a full URL, not just a bare filename")
	}

	func testMacOSVersionDetectReturnsNilForUnknownOrUnrecognizedFilenames() {
		XCTAssertNil(MacOSVersion.detect(fromIPSWFilename: "UniversalMac_11.7.10_20G1345_Restore.ipsw")?.name, "macOS 11 (Big Sur) has no bundled template/codename")
		XCTAssertNil(MacOSVersion.detect(fromIPSWFilename: "my-custom-image.ipsw"))
		XCTAssertNil(MacOSVersion.detect(fromIPSWFilename: ""))
	}

	func testMacOSVersionExpressibleFromRawValue() {
		XCTAssertEqual(MacOSVersion(rawValue: "macos12"), .macos12)
		XCTAssertEqual(MacOSVersion(rawValue: "macos13"), .macos13)
		XCTAssertEqual(MacOSVersion(rawValue: "macos14"), .macos14)
		XCTAssertEqual(MacOSVersion(rawValue: "macos15"), .macos15)
		XCTAssertEqual(MacOSVersion(rawValue: "macos26"), .macos26)
		XCTAssertEqual(MacOSVersion(rawValue: "macos27"), .macos27)
		XCTAssertNil(MacOSVersion(rawValue: "bigsur"))
		// The old marketing names are no longer valid raw values — only `init(argument:)` (the
		// --macos-version CLI parsing path) still accepts them, via a `formerNames` compat lookup.
		XCTAssertNil(MacOSVersion(rawValue: "monterey"))
		XCTAssertNil(MacOSVersion(rawValue: "tahoe"))
	}

	func testMacOSVersionArgumentAcceptsFormerMarketingNames() {
		XCTAssertEqual(MacOSVersion(argument: "monterey"), .macos12)
		XCTAssertEqual(MacOSVersion(argument: "ventura"), .macos13)
		XCTAssertEqual(MacOSVersion(argument: "sonoma"), .macos14)
		XCTAssertEqual(MacOSVersion(argument: "sequoia"), .macos15)
		XCTAssertEqual(MacOSVersion(argument: "tahoe"), .macos26)
		XCTAssertEqual(MacOSVersion(argument: "goldengate"), .macos27)
		// The numeric identifiers themselves still work as --macos-version input too.
		XCTAssertEqual(MacOSVersion(argument: "macos15"), .macos15)
		XCTAssertNil(MacOSVersion(argument: "bigsur"))
	}

	// MARK: - Real repo templates (Sources/cakedlib/PackerLite/Resources/*.packerlite.yaml)

	/// `PackerLiteTemplate.load` now parses `boot_command`/`pre_boot_command` as part of loading
	/// (returning an already-parsed `ParsedPackerLiteTemplate`), so a successful `load` already proves
	/// the file parses — no separate `parsedBootCommand` call needed. `bootCommand`/`preBootCommand`
	/// are non-optional `BootCommandSteps` (`[BootCommandStep]`), each with a `.steps: [Step]`, not the
	/// raw `[Command]`/`commands: [String]` shape the pre-parse `PackerLiteTemplate` type has.
	private func containsUnsubstitutedVariable(_ commands: BootCommandSteps) -> Bool {
		commands.contains { $0.steps.contains { $0.description.contains("${var.") } }
	}

	private func containsText(_ commands: BootCommandSteps, _ text: String) -> Bool {
		commands.contains { $0.steps.contains { $0.description.contains(text) } }
	}

	func testVanillaMacos15PackerLiteTemplateFileLoadsAndParses() async throws {
		// Mirrors what VMBuilder.swift injects: username/password come from CakeConfig, not the template.
		let template = try await PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-macos15.packerlite.yaml").path,
			variables: ["username": "admin", "password": "admin"])

		XCTAssertFalse(template.bootCommand.isEmpty)
		XCTAssertFalse(containsUnsubstitutedVariable(template.bootCommand), "all ${var.*} placeholders should have been substituted")
	}

	func testVanillaMacos26PackerLiteTemplateFileLoadsAndParses() async throws {
		let template = try await PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-macos26.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse(template.bootCommand.isEmpty)
		XCTAssertTrue(containsText(template.bootCommand, "hunter2"))
		XCTAssertFalse(containsUnsubstitutedVariable(template.bootCommand), "all ${var.*} placeholders should have been substituted")
	}

	func testVanillaMacos27PackerLiteTemplateFileLoadsAndParses() async throws {
		let template = try await PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-macos27.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse(template.bootCommand.isEmpty)
		XCTAssertTrue(containsText(template.bootCommand, "hunter2"))
		XCTAssertFalse(containsUnsubstitutedVariable(template.bootCommand), "all ${var.*} placeholders should have been substituted")
	}

	func testVanillaMacos12PackerLiteTemplateFileLoadsAndParses() async throws {
		let template = try await PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-macos12.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse(template.bootCommand.isEmpty)
		XCTAssertTrue(containsText(template.bootCommand, "hunter2"))
		XCTAssertFalse(containsUnsubstitutedVariable(template.bootCommand), "all ${var.*} placeholders should have been substituted")
	}

	func testVanillaMacos13PackerLiteTemplateFileLoadsAndParses() async throws {
		let template = try await PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-macos13.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse(template.bootCommand.isEmpty)
		XCTAssertTrue(containsText(template.bootCommand, "hunter2"))
		XCTAssertFalse(containsUnsubstitutedVariable(template.bootCommand), "all ${var.*} placeholders should have been substituted")
	}

	func testVanillaMacos14PackerLiteTemplateFileLoadsAndParses() async throws {
		let template = try await PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent("vanilla-macos14.packerlite.yaml").path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse(template.bootCommand.isEmpty)
		XCTAssertTrue(containsText(template.bootCommand, "hunter2"))
		XCTAssertFalse(containsUnsubstitutedVariable(template.bootCommand), "all ${var.*} placeholders should have been substituted")
	}

	// MARK: - Built-in Linux templates (Sources/cakedlib/PackerLite/Resources/linux-*.packerlite.yaml)

	func testLinuxFedoraPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("linux-fedora.packerlite.yaml")
	}

	func testLinuxFedoraServerPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("linux-fedora-server.packerlite.yaml")
	}

	func testLinuxCentOSPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("linux-centos.packerlite.yaml")
	}

	func testLinuxRedHatPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("linux-redhat.packerlite.yaml")
	}

	func testLinuxOpenSUSEPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("linux-opensuse.packerlite.yaml")
	}

	func testLinuxDebianPackerLiteTemplateFileLoadsAndParses() async throws {
		try await assertLinuxTemplateLoadsAndParses("linux-debian.packerlite.yaml")
	}

	private func assertLinuxTemplateLoadsAndParses(_ filename: String) async throws {
		let template = try await PackerLiteTemplate.load(
			fromFile: Self.macTemplatesDirectory.appendingPathComponent(filename).path,
			variables: ["username": "admin", "password": "hunter2"])

		XCTAssertFalse(template.bootCommand.isEmpty)
		XCTAssertTrue(containsText(template.bootCommand, "hunter2"))
		XCTAssertFalse(containsUnsubstitutedVariable(template.bootCommand), "all ${var.*} placeholders should have been substituted")
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
}
