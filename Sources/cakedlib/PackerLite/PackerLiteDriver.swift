//
//  PackerLiteDriver.swift
//  CakedLib
//
//  Drives a parsed boot_command against a VM's rendered view by reusing the same
//  CGEvent/NSEvent synthesis VNCInputHandler already uses for real VNC clients —
//  just called in-process instead of over the wire.
//

import AppKit
import CakeAgentLib
import Foundation
import GRPCLib
import Vision

enum PackerLiteDriverError: Error, LocalizedError {
	case stepFailed(index: Int, step: BootCommandStep, underlying: Error)
	case textNotFound(String)

	var errorDescription: String? {
		switch self {
		case .stepFailed(let index, let step, let underlying):
			return "boot_command step \(index) (\(step)) failed: \(underlying.localizedDescription)"
		case .textNotFound(let label):
			return "Could not locate on-screen text '\(label)' to click"
		}
	}
}

final class PackerLiteDriver: @unchecked Sendable {
	private let inputHandler: VNCInputHandler
	private let targetView: VNCVirtualMachineView
	private let logger = Logger("PackerLiteDriver")

	/// Delay between synthesized key events, so the guest OS doesn't drop rapid-fire input.
	private static let keyDelayNanoseconds: UInt64 = 30_000_000
	/// How long clickText retries OCR before giving up, in case the screen is still rendering.
	private static let clickTextTimeout: TimeInterval = 10
	private static let clickTextPollNanoseconds: UInt64 = 500_000_000

	init(targetView: VNCVirtualMachineView) {
		self.targetView = targetView
		self.inputHandler = VNCInputHandler(targetView: targetView)
	}

	func run(steps: [BootCommandStep]) async throws {
		for (index, step) in steps.enumerated() {
			do {
				try await execute(step)
			} catch {
				throw PackerLiteDriverError.stepFailed(index: index, step: step, underlying: error)
			}
		}
	}

	private func execute(_ step: BootCommandStep) async throws {
		switch step {
		case .wait(let seconds):
			logger.debug("wait \(seconds)s")
			try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
		case .type(let text):
			logger.debug("type \(text)")
			try await type(text)
		case .press(let key):
			logger.debug("press \(key)")
			try await press(keysym(for: key))
		case .modifierOn(let modifier):
			logger.debug("modifierOn \(modifier)")
			await self.handleKeyEvent(key: keysym(for: modifier), isDown: true)
			try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
		case .modifierOff(let modifier):
			logger.debug("modifierOff \(modifier)")
			await self.handleKeyEvent(key: keysym(for: modifier), isDown: false)
			try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
		case .click(let x, let y):
			logger.debug("click \(x),\(y)")
			await click(x: x, y: y)
			try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
		case .clickText(let label):
			logger.debug("clickText '\(label)'")
			try await clickText(label)
		}
	}

	// MARK: - Keyboard

	@MainActor private func type(_ text: String) async throws {
		for scalar in text.unicodeScalars {
			try await press(scalar.value)
		}
	}

	@MainActor private func handleKeyEvent(key: UInt32, isDown: Bool) {
		inputHandler.handleKeyEvent(key: key, isDown: isDown)
	}

	@MainActor private func press(_ keysym: UInt32) async throws {
		inputHandler.handleKeyEvent(key: keysym, isDown: true)
		inputHandler.handleKeyEvent(key: keysym, isDown: false)
		try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
	}

	private func keysym(for key: KeyToken) -> UInt32 {
		switch key {
		case .enter: return Keysyms.XK_Return
		case .esc: return Keysyms.XK_Escape
		case .tab: return Keysyms.XK_Tab
		case .spacebar: return Keysyms.XK_space
		case .backspace: return Keysyms.XK_BackSpace
		case .delete: return Keysyms.XK_Delete
		case .insert: return Keysyms.XK_Insert
		case .home: return Keysyms.XK_Home
		case .end: return Keysyms.XK_End
		case .pageUp: return Keysyms.XK_Page_Up
		case .pageDown: return Keysyms.XK_Page_Down
		case .up: return Keysyms.XK_Up
		case .down: return Keysyms.XK_Down
		case .left: return Keysyms.XK_Left
		case .right: return Keysyms.XK_Right
		case .function(let number): return Keysyms.XK_F1 + UInt32(max(1, min(12, number)) - 1)
		}
	}

	private func keysym(for modifier: ModifierToken) -> UInt32 {
		switch modifier {
		case .leftShift: return Keysyms.XK_Shift_L
		case .rightShift: return Keysyms.XK_Shift_R
		case .leftAlt: return Keysyms.XK_Alt_L
		case .rightAlt: return Keysyms.XK_Alt_R
		case .leftCtrl: return Keysyms.XK_Control_L
		case .rightCtrl: return Keysyms.XK_Control_R
		case .leftSuper: return Keysyms.XK_Super_L
		case .rightSuper: return Keysyms.XK_Super_R
		}
	}

	// MARK: - Mouse

	@MainActor private func click(x: Int, y: Int) {
		inputHandler.handlePointerEvent(x: x, y: y, buttonMask: 0x01)
		inputHandler.handlePointerEvent(x: x, y: y, buttonMask: 0x00)
	}

	@MainActor private func clickText(_ label: String) async throws {
		let deadline = Date().addingTimeInterval(Self.clickTextTimeout)

		while true {
			if let point = try locate(text: label) {
				click(x: point.x, y: point.y)
				try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
				return
			}

			if Date() >= deadline {
				throw PackerLiteDriverError.textNotFound(label)
			}

			try await Task.sleep(nanoseconds: Self.clickTextPollNanoseconds)
		}
	}

	/// Locates `label` in the view's current frame via Vision OCR and returns its center,
	/// converted into the top-left-origin pixel space `VNCInputHandler.handlePointerEvent` expects.
	@MainActor private func locate(text label: String) throws -> (x: Int, y: Int)? {
		guard
			let image = targetView.image(),
			let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
		else {
			return nil
		}

		let request = VNRecognizeTextRequest()
		request.recognitionLevel = .accurate

		try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

		let needle = label.lowercased()

		for observation in request.results ?? [] {
			guard let candidate = observation.topCandidates(1).first, candidate.string.lowercased().contains(needle) else {
				continue
			}

			let box = observation.boundingBox
			let width = CGFloat(cgImage.width)
			let height = CGFloat(cgImage.height)

			// Vision's boundingBox is normalized with origin at bottom-left; VNC coordinates
			// (as consumed by handlePointerEvent) have origin at top-left.
			let x = Int(box.midX * width)
			let y = Int((1 - box.midY) * height)

			return (x, y)
		}

		return nil
	}
}
