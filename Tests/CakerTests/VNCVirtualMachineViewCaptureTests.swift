//
//  VNCVirtualMachineViewCaptureTests.swift
//  CakerTests
//
//  Unit tests for the one piece of `VNCVirtualMachineView`'s native-NSEvent capture path (see
//  CLAUDE.md's PackerLite section, "Direct local-window capture, not a VNC-server tap") that's
//  isolable without a real NSView/window/VM: the `flagsChanged` isDown-toggle state machine.
//  Everything else in the capture path (the mouse/keyboard overrides themselves) needs a live
//  view hierarchy to exercise meaningfully and isn't covered here — same testing-scope philosophy
//  as the rest of PackerLite (see CLAUDE.md's "No real end-to-end hardware test yet" note).
//

import Foundation
import XCTest

@testable import CakedLib

final class VNCVirtualMachineViewCaptureTests: XCTestCase {
	private let leftShift: CGKeyCode = 56
	private let rightShift: CGKeyCode = 60

	// MARK: - Single key down/up

	func testFirstOccurrenceOfAKeyCodeIsDown() {
		let (isDown, held) = VNCVirtualMachineView.toggledModifierState(heldKeyCodes: [], keyCode: leftShift)

		XCTAssertTrue(isDown)
		XCTAssertEqual(held, [leftShift])
	}

	func testSecondOccurrenceOfTheSameKeyCodeIsUp() {
		let (firstIsDown, heldAfterDown) = VNCVirtualMachineView.toggledModifierState(heldKeyCodes: [], keyCode: leftShift)
		XCTAssertTrue(firstIsDown)

		let (secondIsDown, heldAfterUp) = VNCVirtualMachineView.toggledModifierState(heldKeyCodes: heldAfterDown, keyCode: leftShift)

		XCTAssertFalse(secondIsDown)
		XCTAssertTrue(heldAfterUp.isEmpty)
	}

	// MARK: - Two physical keys sharing one NSEvent.ModifierFlags bit

	/// The whole reason this state machine exists instead of reading `NSEvent.modifierFlags`
	/// directly: left and right shift both map to `.shift`, so releasing one while the other is
	/// still held must not be mistaken for "shift fully released" — this only works if each
	/// keyCode's held/released state is tracked independently.
	func testDistinctModifierKeyCodesAreTrackedIndependently() {
		var held: Set<CGKeyCode> = []
		var isDown: Bool

		(isDown, held) = VNCVirtualMachineView.toggledModifierState(heldKeyCodes: held, keyCode: leftShift)
		XCTAssertTrue(isDown)

		(isDown, held) = VNCVirtualMachineView.toggledModifierState(heldKeyCodes: held, keyCode: rightShift)
		XCTAssertTrue(isDown)

		XCTAssertEqual(held, [leftShift, rightShift])

		// Release left shift only — right shift must still register as held.
		(isDown, held) = VNCVirtualMachineView.toggledModifierState(heldKeyCodes: held, keyCode: leftShift)

		XCTAssertFalse(isDown)
		XCTAssertEqual(held, [rightShift])
	}

	func testRepeatedDownUpCyclesAlternateCorrectly() {
		var held: Set<CGKeyCode> = []
		var results: [Bool] = []

		for _ in 0..<4 {
			let (isDown, newHeld) = VNCVirtualMachineView.toggledModifierState(heldKeyCodes: held, keyCode: leftShift)

			held = newHeld
			results.append(isDown)
		}

		XCTAssertEqual(results, [true, false, true, false])
		XCTAssertTrue(held.isEmpty)
	}
}
