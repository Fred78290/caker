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
}
