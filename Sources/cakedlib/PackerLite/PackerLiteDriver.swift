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
import Carbon.HIToolbox
import Foundation
import GRPCLib
import Vision

public protocol KeyLayoutTranslator: Sendable, Identifiable {
	func translate(char: Character) -> Character?
}

extension TISInputSource {
	func getLocalizedName() -> String? {
		if let namePtr = TISGetInputSourceProperty(self, kTISPropertyLocalizedName) {
			let cfName = unsafeBitCast(namePtr, to: CFString.self)
			return cfName as String
		}
		return nil
	}

	func getSourceID() -> String? {
		if let sourceIDPtr = TISGetInputSourceProperty(self, kTISPropertyInputSourceID) {
			let cfSourceID = unsafeBitCast(sourceIDPtr, to: CFString.self)
			return cfSourceID as String
		}

		return nil
	}
}

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
	private var currentKeyTranslator: any KeyLayoutTranslator = NullLayoutTranslator()

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
		case .keyboard(let layout):
			logger.debug("keyboard layout \(layout.id)")
			currentKeyTranslator = layout
		}
	}

	// MARK: - Keyboard

	@MainActor private func type(_ text: String) async throws {
		#if DEBUG
		let translated = String(String.UnicodeScalarView(text.unicodeScalars.compactMap {
			Unicode.Scalar(translate($0.value))
		}))
		logger.debug("type '\(text)' -> '\(translated)'")
		#endif

		for scalar in text.unicodeScalars {
			let keysym = translate(scalar.value)

			inputHandler.handleKeyEvent(key: keysym, isDown: true)
			inputHandler.handleKeyEvent(key: keysym, isDown: false)

			try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
		}
	}

	@MainActor private func handleKeyEvent(key: UInt32, isDown: Bool) {
		inputHandler.handleKeyEvent(key: key, isDown: isDown)
	}

	@MainActor private func press(_ keysym: UInt32) async throws {
		let usKeysym = translate(keysym)

		inputHandler.handleKeyEvent(key: usKeysym, isDown: true)
		inputHandler.handleKeyEvent(key: usKeysym, isDown: false)

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

	private func translate(_ keysym: UInt32) -> UInt32 {
		// Use a layout-aware translator based on TIS/UCKeyTranslate to map a character
		// produced by the current layout to the character produced by the same physical
		// key (and shift state) on a US layout. For non-Unicode keysyms, return as-is.
		if keysym <= 0x10FFFF, let scalar = UnicodeScalar(keysym) {
			if let translated = currentKeyTranslator.translate(char: Character(scalar)), let value = translated.unicodeScalars.first {
				return UInt32(value)
			}

			// Fallback: if we cannot translate, return original
			return keysym
		}

		return keysym
	}

	struct NullLayoutTranslator: KeyLayoutTranslator {
		let id: String = "null"

		func translate(char: Character) -> Character? {
			return char
		}
	}

	// MARK: - Keyboard layout translation (current layout -> Foreign)
	struct LayoutTranslator: KeyLayoutTranslator {
		let id: String

		private let currentCharToKey: [Character: (keyCode: UInt16, shifted: Bool)]
		private let currentKeyToChar: [UInt16: (unshifted: Character?, shifted: Character?)]
		private let targetCharToKey: [Character: (keyCode: UInt16, shifted: Bool)]
		private let targetKeyToChar: [UInt16: (unshifted: Character?, shifted: Character?)]

		/// Available keyboard and sourceID
		/// ABC - com.apple.keylayout.ABC
		/// ABC – AZERTY - com.apple.keylayout.ABC-AZERTY
		/// ABC – QWERTZ - com.apple.keylayout.ABC-QWERTZ
		/// Allemand - com.apple.keylayout.German
		/// Américain - com.apple.keylayout.US
		/// Australien - com.apple.keylayout.Australian
		/// Autrichien - com.apple.keylayout.Austrian
		/// Belge - com.apple.keylayout.Belgian
		/// Biélorusse - com.apple.keylayout.Byelorussian
		/// Brésilien - com.apple.keylayout.Brazilian-Pro
		/// Brésilien – ABNT2 - com.apple.keylayout.Brazilian-ABNT2
		/// Brésilien – Ancien clavier - com.apple.keylayout.Brazilian
		/// Britannique - com.apple.keylayout.British
		/// Britannique – PC - com.apple.keylayout.British-PC
		/// Bulgare – QWERTY - com.apple.keylayout.Bulgarian-Phonetic
		/// Bulgare – Standard - com.apple.keylayout.Bulgarian
		/// Canadien - com.apple.keylayout.Canadian
		/// Canadien – CSA - com.apple.keylayout.Canadian-CSA
		/// Canadien – PC - com.apple.keylayout.CanadianFrench-PC
		/// Colemak - com.apple.keylayout.Colemak
		/// com.apple.PressAndHold - com.apple.PressAndHold
		/// Danois - com.apple.keylayout.Danish
		/// Dvorak - com.apple.keylayout.Dvorak
		/// Dvorak – Droitier - com.apple.keylayout.Dvorak-Right
		/// Dvorak – Gaucher - com.apple.keylayout.Dvorak-Left
		/// Dvorak – QWERTY ⌘ - com.apple.keylayout.DVORAK-QWERTYCMD
		/// Emoji et symboles - com.apple.CharacterPaletteIM
		/// Espagnol - com.apple.keylayout.Spanish-ISO
		/// Espagnol – Ancien clavier - com.apple.keylayout.Spanish
		/// Estonien - com.apple.keylayout.Estonian
		/// Finnois - com.apple.keylayout.Finnish
		/// Français - com.apple.keylayout.French
		/// Français – Numérique - com.apple.keylayout.French-numerical
		/// Français – PC - com.apple.keylayout.French-PC
		/// Hongrois - com.apple.keylayout.Hungarian
		/// Hongrois – QWERTY - com.apple.keylayout.Hungarian-QWERTY
		/// Irlandais - com.apple.keylayout.Irish
		/// Italien - com.apple.keylayout.Italian-Pro
		/// Italien – QZERTY - com.apple.keylayout.Italian
		/// Kana - com.apple.keylayout.KANA
		/// Letton - com.apple.keylayout.Latvian
		/// Lituanien – ĄŽERTY - com.apple.keylayout.Lithuanian-LST1582
		/// Lituanien – QWERTY - com.apple.keylayout.Lithuanian
		/// Macédonien - com.apple.keylayout.Macedonian
		/// Néerlandais - com.apple.keylayout.Dutch
		/// Norvégien - com.apple.keylayout.Norwegian
		/// Polonais - com.apple.keylayout.PolishPro
		/// Polonais – QWERTZ - com.apple.keylayout.Polish
		/// Portugais - com.apple.keylayout.Portuguese
		/// Russe - com.apple.keylayout.Russian
		/// Russe – PC - com.apple.keylayout.RussianWin
		/// Russe – QWERTY - com.apple.keylayout.Russian-Phonetic
		/// Serbe - com.apple.keylayout.Serbian
		/// Slovaque - com.apple.keylayout.Slovak
		/// Slovaque – QWERTY - com.apple.keylayout.Slovak-QWERTY
		/// Suédois - com.apple.keylayout.Swedish-Pro
		/// Suédois – Ancien clavier - com.apple.keylayout.Swedish
		/// Suisse allemand - com.apple.keylayout.SwissGerman
		/// Suisse romand - com.apple.keylayout.SwissFrench
		/// Tchèque - com.apple.keylayout.Czech
		/// Tchèque – QWERTY - com.apple.keylayout.Czech-QWERTY
		/// Tongan - com.apple.keylayout.Tongan
		/// Ukrainien - com.apple.keylayout.Ukrainian-PC
		/// Ukrainien – Ancien clavier - com.apple.keylayout.Ukrainian
		/// US International – PC - com.apple.keylayout.USInternational-PC

		private static func getNamedInputSource(_ nameOrSourceID: String) -> TISInputSource? {
			guard let unmanagedList = TISCreateInputSourceList(nil, true) else {
				return nil
			}
			let array = (unmanagedList.takeRetainedValue() as [AnyObject]).map { unsafeBitCast($00, to: TISInputSource.self) }

			for source in array {
				let name = source.getLocalizedName()
				let sourceID = source.getSourceID()

				#if TRACE
					print("\(name ?? "<no name>") - \(sourceID ?? "<no id>")")
				#endif

				if name == nameOrSourceID || source.getSourceID() == nameOrSourceID {
					return source
				}
			}

			return nil
		}

		@MainActor
		init?(_ keyLayout: String = "com.apple.keylayout.US") {
			// Build maps once at init time. If the user changes layouts at runtime, you can re-instantiate this struct.
			guard let targetKeyboard = Self.getNamedInputSource(keyLayout) else {
				return nil
			}

			let currentKeyboard = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()

			self.currentCharToKey = LayoutTranslator.buildCharToKeyMap(inputSource: currentKeyboard)
			self.currentKeyToChar = LayoutTranslator.buildKeyToCharMap(keyLayout: currentKeyboard)

			self.targetCharToKey = LayoutTranslator.buildCharToKeyMap(inputSource: targetKeyboard)
			self.targetKeyToChar = LayoutTranslator.buildKeyToCharMap(keyLayout: targetKeyboard)
			self.id = keyLayout
		}

		func translate(char: Character) -> Character? {
			guard let (keyCode, shifted) = currentCharToKey[char] else {
				return nil
			}

			guard let entry = targetKeyToChar[keyCode] else {
				return nil
			}

			return shifted ? entry.shifted ?? entry.unshifted : entry.unshifted ?? entry.shifted
		}

		// MARK: Mapping builders
		private static func buildKeyToCharMap(keyLayout: TISInputSource) -> [UInt16: (unshifted: Character?, shifted: Character?)] {
			var map: [UInt16: (unshifted: Character?, shifted: Character?)] = [:]

			// Build the key-to-char map for the chosen source.
			map = buildKeyToCharMap(inputSource: keyLayout)

			// Keep the Unicode layout data (if any) referenced for the duration of this scope.
			if let layoutData = TISGetInputSourceProperty(keyLayout, kTISPropertyUnicodeKeyLayoutData) {
				_ = unsafeBitCast(layoutData, to: CFData.self)
			}

			return map
		}

		private static func buildCharToKeyMap(inputSource: TISInputSource) -> [Character: (keyCode: UInt16, shifted: Bool)] {
			var result: [Character: (UInt16, Bool)] = [:]
			let keyToChar = buildKeyToCharMap(inputSource: inputSource)

			for (keyCode, pair) in keyToChar {
				if let c = pair.unshifted {
					result[c] = (keyCode: keyCode, shifted: false)
				}

				if let c = pair.shifted {
					result[c] = (keyCode: keyCode, shifted: true)
				}
			}

			return result
		}

		private static func buildKeyToCharMap(inputSource: TISInputSource) -> [UInt16: (unshifted: Character?, shifted: Character?)] {
			guard let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
				return [:]
			}
			let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
			let length = CFDataGetLength(layoutData)
			if length == 0 { return [:] }
			return CFDataGetBytePtr(layoutData).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { keyboardLayoutPtr in
				var localMap: [UInt16: (Character?, Character?)] = [:]
				for keyCode in 0...127 {
					let unshifted = translate(keyCode: UInt16(keyCode), shift: false, keyboardLayout: keyboardLayoutPtr)
					let shifted = translate(keyCode: UInt16(keyCode), shift: true, keyboardLayout: keyboardLayoutPtr)
					if unshifted != nil || shifted != nil {
						localMap[UInt16(keyCode)] = (unshifted, shifted)
					}
				}
				return localMap
			}
		}

		private static func translate(keyCode: UInt16, shift: Bool, keyboardLayout: UnsafePointer<UCKeyboardLayout>) -> Character? {
			var deadKeyState: UInt32 = 0
			var chars: [UniChar] = Array(repeating: 0, count: 4)
			var len: Int = 0
			let modifiers: UInt32 = shift ? UInt32(shiftKey) : 0
			let result = UCKeyTranslate(
				keyboardLayout,
				UInt16(keyCode),
				UInt16(kUCKeyActionDown),
				modifiers >> 8,
				UInt32(LMGetKbdType()),
				OptionBits(kUCKeyTranslateNoDeadKeysBit),
				&deadKeyState,
				chars.count,
				&len,
				&chars
			)

			if result != noErr || len == 0 {
				return nil
			}

			let s = String(utf16CodeUnits: chars, count: len)

			return s.first
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
			if let point = try await locate(text: label) {
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
	private func locate(text label: String) async throws -> (x: Int, y: Int)? {
		// Capture the current CGImage on the main actor (AppKit view access must be on main).
		let cgImage: CGImage? = await MainActor.run { [weak targetView] in
			guard let image = targetView?.image(),
				let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
			else {
				return nil
			}
			return cg
		}

		guard let cgImage else { return nil }

		// Perform Vision work off the main actor at a lower priority to avoid QoS inversions.
		let result = try await Task.detached(priority: .utility) { () throws -> (x: Int, y: Int)? in
			let request = VNRecognizeTextRequest()
			request.recognitionLevel = .accurate

			try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

			let needle = label.lowercased()

			for observation in request.results ?? [] {
				guard let candidate = observation.topCandidates(1).first,
					candidate.string.lowercased().contains(needle)
				else {
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
		}.value

		return result
	}
}
