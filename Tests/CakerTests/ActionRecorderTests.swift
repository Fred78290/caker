//
//  ActionRecorderTests.swift
//  CakerTests
//
//  Unit tests for ActionRecorder's serialization logic in isolation — feed a synthetic sequence
//  of RecordedAction values (no real VM/VNC needed) and assert the emitted boot_command YAML
//  contains the expected tokens: character coalescing, special-key token mapping, modifier on/off
//  pairing, click-point tokens, wait-gap sizing, and credential scrubbing.
//

import AppKit
import Foundation
import XCTest

@testable import CakedLib

final class ActionRecorderTests: XCTestCase {
	private let base = Date(timeIntervalSince1970: 1_700_000_000)
	// A bare, unbacked NSView stands in for the real VNCVirtualMachineView/VNC-tap sender — record(_:_:)
	// only dereferences it for OCR-related bookkeeping gated on the Fn modifier, which none of these
	// tests hold, so an unbacked placeholder view is safe here.
	private let view = NSView(frame: .zero)

	private func keyAction(_ keyCode: CGKeyCode, characters: String = String.empty, isDown: Bool = true, at offset: TimeInterval) -> RecordedAction {
		.key(keyCode: keyCode, modifiers: [], characters: characters, charactersIgnoringModifiers: characters, isDown: isDown, timestamp: base.addingTimeInterval(offset))
	}

	private func pointerAction(x: Int, y: Int, buttonMask: UInt8, at offset: TimeInterval) -> RecordedAction {
		.pointer(x: x, y: y, buttonMask: buttonMask, timestamp: base.addingTimeInterval(offset))
	}

	// MARK: - Character coalescing

	func testCoalescesConsecutiveCharacterKeystrokes() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		for (index, char) in "Hello".enumerated() {
			recorder.record(view, keyAction(0, characters: String(char), at: TimeInterval(index) * 0.05))
		}

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("Hello"), "Expected coalesced literal text 'Hello' in:\n\(yaml)")
		// Exactly one `commands:` block should carry the coalesced run, not one per character —
		// stepCount is read after finish() flushes the still-pending text run into a step.
		XCTAssertEqual(recorder.stepCount, 1)
	}

	func testKeyUpEventsDoNotDuplicateText() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, keyAction(0, characters: "H", isDown: true, at: 0))
		recorder.record(view, keyAction(0, characters: "H", isDown: false, at: 0.05))
		recorder.record(view, keyAction(1, characters: "i", isDown: true, at: 0.1))
		recorder.record(view, keyAction(1, characters: "i", isDown: false, at: 0.15))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("Hi"))
		XCTAssertFalse(yaml.contains("HHi"))
	}

	// MARK: - Special-key token mapping

	func testSpecialKeyProducesNamedToken() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .enter), at: 0))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("<enter>"), "Expected <enter> token in:\n\(yaml)")
	}

	func testFunctionKeyProducesNamedToken() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .function(5)), at: 0))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("<F5>"), "Expected <F5> token in:\n\(yaml)")
	}

	// MARK: - Modifier on/off pairing

	func testModifierDownUpWrapsIntermediateText() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .leftShift), isDown: true, at: 0))
		recorder.record(view, keyAction(2, characters: "A", isDown: true, at: 0.05))
		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .leftShift), isDown: false, at: 0.1))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("<leftShiftOn>"), "Expected <leftShiftOn> in:\n\(yaml)")
		XCTAssertTrue(yaml.contains("<leftShiftOff>"), "Expected <leftShiftOff> in:\n\(yaml)")

		let onIndex = yaml.range(of: "<leftShiftOn>")!.lowerBound
		let textIndex = yaml.range(of: "\"A\"")?.lowerBound ?? yaml.range(of: "A")!.lowerBound
		let offIndex = yaml.range(of: "<leftShiftOff>")!.lowerBound

		XCTAssertTrue(onIndex < textIndex && textIndex < offIndex, "Expected on/text/off in chronological order in:\n\(yaml)")
	}

	// MARK: - Locate mode: an explicit toolbar toggle, not inferred from any held key

	func testGenuineFunctionKeyPressStillRecordsNormally() {
		// Fn is heavily used by real macOS accessibility shortcuts an operator legitimately needs to
		// *record* — VoiceOver's Fn+F5, Full Keyboard Access's Fn+Control+F7 — so, unlike an earlier
		// revision of this feature, a plain Fn press must never be suppressed on its own.
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .function), isDown: true, at: 0))
		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .function), isDown: false, at: 0.2))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("<fnOn>"), "Expected a genuine Fn press to record normally in:\n\(yaml)")
		XCTAssertTrue(yaml.contains("<fnOff>"), "Expected a genuine Fn press to record normally in:\n\(yaml)")
	}

	func testModifierWhileLocateModeActiveIsNotRecorded() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		// Option is the actual clickText-vs-locate selector (see recordPointer), but the
		// suppression rule in recordKey is modifier-agnostic — it skips *any* modifier while locate
		// mode is armed, so this deliberately exercises a different modifier (Shift) than the real
		// selector to confirm that genericness, not just the one modifier the UI happens to use.
		recorder.setLocateModeActive(true, sender: view)
		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .leftShift), isDown: true, at: 0))
		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .leftShift), isDown: false, at: 0.05))
		recorder.setLocateModeActive(false, sender: view)

		let yaml = recorder.finish()

		XCTAssertFalse(yaml.contains("<leftShiftOn>"), "Any modifier held while locate mode is armed must not be recorded in:\n\(yaml)")
		XCTAssertFalse(yaml.contains("<leftShiftOff>"), "Any modifier held while locate mode is armed must not be recorded in:\n\(yaml)")
		XCTAssertEqual(recorder.stepCount, 0)
	}

	func testOptionModifierWhileLocateModeActiveIsNotRecorded() {
		// The real clickText-vs-locate selector: Option+click. Confirms it too is suppressed while
		// locate mode is armed, not just recordKey's suppression rule in general (above).
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.setLocateModeActive(true, sender: view)
		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .leftAlt), isDown: true, at: 0))
		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .leftAlt), isDown: false, at: 0.05))
		recorder.setLocateModeActive(false, sender: view)

		let yaml = recorder.finish()

		XCTAssertFalse(yaml.contains("<leftAltOn>"), "Option held only to select clickText while locate mode is armed must not be recorded in:\n\(yaml)")
		XCTAssertFalse(yaml.contains("<leftAltOff>"), "Option held only to select clickText while locate mode is armed must not be recorded in:\n\(yaml)")
		XCTAssertEqual(recorder.stepCount, 0)
	}

	func testModifierOutsideLocateModeIsStillRecorded() {
		// Regression guard: the locate-mode suppression must not swallow ordinary modifier steps
		// when locate mode was never armed at all — testModifierDownUpWrapsIntermediateText above
		// already covers this, this just makes that intent explicit as its own case.
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .leftShift), isDown: true, at: 0))
		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .leftShift), isDown: false, at: 0.1))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("<leftShiftOn>"))
		XCTAssertTrue(yaml.contains("<leftShiftOff>"))
	}

	// MARK: - Click tokens

	func testClickDownUpProducesClickPointToken() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, pointerAction(x: 512, y: 384, buttonMask: 0x01, at: 0))
		recorder.record(view, pointerAction(x: 512, y: 384, buttonMask: 0x00, at: 0.05))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("<click point=\"512,384\">"), "Expected click token in:\n\(yaml)")
	}

	func testStillHeldClickAtFinishIsStillRecorded() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, pointerAction(x: 10, y: 20, buttonMask: 0x01, at: 0))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("<click point=\"10,20\">"), "Expected click token for still-held button in:\n\(yaml)")
	}

	// MARK: - Wait-gap sizing

	func testLargeGapBetweenActionsInsertsWaitToken() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, keyAction(0, characters: "a", at: 0))
		recorder.record(view, keyAction(1, characters: "b", at: 3.4))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("<wait3s>"), "Expected a rounded <wait3s> token in:\n\(yaml)")
	}

	func testSmallGapBetweenActionsDoesNotInsertWaitToken() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, keyAction(0, characters: "a", at: 0))
		recorder.record(view, keyAction(1, characters: "b", at: 0.2))

		let yaml = recorder.finish()

		XCTAssertFalse(yaml.contains("<wait"), "Did not expect a wait token for a sub-threshold gap in:\n\(yaml)")
	}

	// MARK: - Credential scrubbing

	func testExactUsernameMatchIsScrubbed() {
		let recorder = ActionRecorder(os: .darwin, username: "vmadmin", password: "s3cret")

		for (index, char) in "vmadmin".enumerated() {
			recorder.record(view, keyAction(0, characters: String(char), at: TimeInterval(index) * 0.05))
		}

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("${var.username}"), "Expected username to be scrubbed in:\n\(yaml)")
		XCTAssertFalse(yaml.contains("vmadmin"), "Plaintext username must not appear in:\n\(yaml)")
	}

	func testExactPasswordMatchIsScrubbed() {
		let recorder = ActionRecorder(os: .darwin, username: "vmadmin", password: "s3cret")

		for (index, char) in "s3cret".enumerated() {
			recorder.record(view, keyAction(0, characters: String(char), at: TimeInterval(index) * 0.05))
		}

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("${var.password}"), "Expected password to be scrubbed in:\n\(yaml)")
		XCTAssertFalse(yaml.contains("s3cret"), "Plaintext password must not appear in:\n\(yaml)")
	}

	func testUnrelatedTextIsNotScrubbed() {
		let recorder = ActionRecorder(os: .darwin, username: "vmadmin", password: "s3cret")

		for (index, char) in "helloworld".enumerated() {
			recorder.record(view, keyAction(0, characters: String(char), at: TimeInterval(index) * 0.05))
		}

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("helloworld"))
		XCTAssertFalse(yaml.contains("${var.username}"))
		XCTAssertFalse(yaml.contains("${var.password}"))
	}

	// MARK: - Empty session

	func testEmptySessionProducesEmptyBootCommand() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)
		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("boot_command"))
		XCTAssertEqual(recorder.stepCount, 0)
	}

	// MARK: - pre_boot_command routing (non-Darwin)

	func testDarwinRecordingHasNoPreBootCommand() {
		let recorder = ActionRecorder(os: .darwin, username: nil, password: nil)

		recorder.record(view, keyAction(0, characters: "a", at: 0))
		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .enter), at: 3))

		let yaml = recorder.finish()

		XCTAssertFalse(yaml.contains("pre_boot_command"), "Darwin recordings must not split off a pre_boot_command in:\n\(yaml)")
	}

	func testLinuxRecordingRoutesFirstCommandIntoPreBootCommand() {
		let recorder = ActionRecorder(os: .linux, username: nil, password: nil)

		// First command block: a lone <enter> (e.g. a GRUB boot-menu keystroke).
		recorder.record(view, keyAction(PackerLiteDriver.keysym(for: .enter), at: 0))
		// A large gap starts a new command block for the rest.
		recorder.record(view, keyAction(0, characters: "a", at: 3))

		let yaml = recorder.finish()

		XCTAssertTrue(yaml.contains("pre_boot_command"), "Expected a pre_boot_command block for a Linux recording in:\n\(yaml)")
		XCTAssertTrue(yaml.contains("boot_command"), "Expected the remaining boot_command block in:\n\(yaml)")

		// The <enter> from the first block must appear before pre_boot_command's own text ends —
		// i.e. it was actually moved into pre_boot_command, not merely present somewhere in the YAML.
		let preBootRange = yaml.range(of: "pre_boot_command")!
		let bootRange = yaml.range(of: "boot_command")!
		XCTAssertTrue(preBootRange.lowerBound < bootRange.lowerBound, "Expected pre_boot_command to precede boot_command in:\n\(yaml)")
	}

	// MARK: - Wait-gap folding into <clickText>/<locate> timeout=

	// `.clickText`/`.locate` steps are only ever produced by real Vision OCR against a real
	// rendered view (see `ActionRecorder.recordPointer`'s `currentRecognizedText` lookup), which
	// isn't practical to drive from this unit-test harness. `ActionRecorder.Step` and
	// `ActionRecorder.commands(for:username:password:)` were made internal (rather than the
	// finish()-private shape they'd otherwise have) specifically so these two cases can be
	// constructed directly here and fed through the real wait-vs-timeout branching logic in
	// isolation, without needing a real boot/render/OCR pipeline.

	func testClickTextGapFoldsIntoTimeoutInsteadOfSeparateWait() {
		let steps: [ActionRecorder.Step] = [
			.click(x: 10, y: 20, timestamp: base),
			.clickText(text: "Continue", timestamp: base.addingTimeInterval(3.4)),
		]

		let commands = ActionRecorder.commands(for: steps, username: nil, password: nil)

		XCTAssertEqual(commands.count, 2, "Expected no separate <waitNs> command block before the clickText step")
		XCTAssertEqual(commands[1].commands, ["<click text=\"Continue\" timeout=13>"], "Expected the 3.4s gap (rounded to 3) plus 10s slack folded into timeout=")
	}

	func testLocateGapFoldsIntoTimeoutInsteadOfSeparateWait() {
		let steps: [ActionRecorder.Step] = [
			.click(x: 10, y: 20, timestamp: base),
			.locate(text: "Next", timestamp: base.addingTimeInterval(1.2)),
		]

		let commands = ActionRecorder.commands(for: steps, username: nil, password: nil)

		XCTAssertEqual(commands.count, 2, "Expected no separate <waitNs> command block before the locate step")
		XCTAssertEqual(commands[1].commands, ["<locate text=\"Next\" timeout=11>"], "Expected the 1.2s gap (rounded to 1) plus 10s slack folded into timeout=")
	}

	func testOtherStepTypeStillGetsSeparateWaitForSameGap() {
		// Regression guard: the timeout-folding branch must only fire for .clickText/.locate — every
		// other step type keeps today's separate blind <waitNs> for the exact same gap size.
		let steps: [ActionRecorder.Step] = [
			.click(x: 10, y: 20, timestamp: base),
			.click(x: 30, y: 40, timestamp: base.addingTimeInterval(3.4)),
		]

		let commands = ActionRecorder.commands(for: steps, username: nil, password: nil)

		XCTAssertEqual(commands.count, 3, "Expected a separate <waitNs> command block before the second click step")
		XCTAssertEqual(commands[1].commands, ["<wait3s>"])
		XCTAssertEqual(commands[2].commands, ["<click point=\"30,40\">"], "The click token itself must carry no timeout= attribute")
	}

	func testClickTextBelowWaitThresholdGetsNoTimeoutOverride() {
		// A gap below minimumWaitToRecord wouldn't have produced a <waitNs> today either — it must
		// not force a timeout= override on the clickText/locate step, leaving the parser's own 10s
		// default in place (no timeout= attribute emitted at all).
		let steps: [ActionRecorder.Step] = [
			.click(x: 10, y: 20, timestamp: base),
			.clickText(text: "Continue", timestamp: base.addingTimeInterval(0.2)),
		]

		let commands = ActionRecorder.commands(for: steps, username: nil, password: nil)

		XCTAssertEqual(commands.count, 2)
		XCTAssertEqual(commands[1].commands, ["<click text=\"Continue\">"], "Expected no timeout= attribute for a sub-threshold gap")
	}
}
