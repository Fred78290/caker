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
import QuartzCore
import RoyalVNCKit
import Vision

extension CGKeyCodes {
	public static let functionKeys: [CGKeyCode] = [
		CGKeyCodes.f1,
		CGKeyCodes.f2,
		CGKeyCodes.f3,
		CGKeyCodes.f4,
		CGKeyCodes.f5,
		CGKeyCodes.f6,
		CGKeyCodes.f7,
		CGKeyCodes.f8,
		CGKeyCodes.f9,
		CGKeyCodes.f10,
		CGKeyCodes.f11,
		CGKeyCodes.f12,
		CGKeyCodes.f13,
		CGKeyCodes.f14,
		CGKeyCodes.f15,
		CGKeyCodes.f16,
		CGKeyCodes.f17,
		CGKeyCodes.f18,
		CGKeyCodes.f19,
		CGKeyCodes.f20,
	]
}

public protocol KeyLayoutTranslator: Sendable, Identifiable {
	func translate(char: Character) -> (keyCode: CGKeyCode, modifiers: NSEvent.ModifierFlags, characters: String, charactersIgnoringModifiers: String)?
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
	case stepFailed(step: BootCommandStep, underlying: Error)
	case textNotFound(String)

	var errorDescription: String? {
		switch self {
		case .stepFailed(let command, let underlying):
			return "boot_command step \(command.title) failed: \(underlying.localizedDescription)"
		case .textNotFound(let label):
			return "Could not locate on-screen text '\(label)' to click"
		}
	}
}

final class PackerLiteDriver: @unchecked Sendable {
	private let targetView: NSView
	private let logger = Logger("PackerLiteDriver")
	private var currentKeyTranslator: any KeyLayoutTranslator

	/// Delay between synthesized key events, so the guest OS doesn't drop rapid-fire input.
	private static let keyDelayNanoseconds: UInt64 = 30_000_000
	/// How long clickText retries OCR before giving up, in case the screen is still rendering.
	public static let clickTextTimeout: TimeInterval = 10
	private static let clickTextPollNanoseconds: UInt64 = 500_000_000

	// MARK: Input handler variables
	private var mouseButtonState: UInt8 = 0
	private var isDragging: Bool = false
	private var lastMousePosition = NSPoint.zero
	private var postEvent: Bool = false
	private var modifiers: NSEvent.ModifierFlags = []
	private var characters: String = String.empty
	private var trackingNumber: Int = 0
	private let eventSource = CGEventSource(stateID: .combinedSessionState)

	#if DEBUG
		private var debugOverlayLayer: CAShapeLayer?

		@MainActor
		private func showDebugBox(_ box: CGRect, in imageSize: CGSize) {
			guard let layer = targetView.layer else {
				return
			}

			if let debugOverlayLayer = self.debugOverlayLayer {
				debugOverlayLayer.removeFromSuperlayer()
				self.debugOverlayLayer = nil
			}

			targetView.wantsLayer = true

			let overlay = CAShapeLayer()

			overlay.zPosition = 1000
			layer.addSublayer(overlay)

			self.debugOverlayLayer = overlay

			// Convert the box from image coordinates (origin bottom-left) to the targetView coordinate space (origin bottom-left).
			// VNImageRectForNormalizedRect yields rect in image coords origin bottom-left.
			// NSView's layer has origin bottom-left if flipped is false, else origin top-left.
			// AppKit views often have flipped coordinate system (origin top-left). Convert accordingly.

			let viewHeight = targetView.bounds.height
			let viewWidth = targetView.bounds.width

			// The CGImage and view might differ in size, so scale accordingly
			let scaleX = viewWidth / imageSize.width
			let scaleY = viewHeight / imageSize.height

			// Box origin is bottom-left, need to convert to AppKit's coordinate system (which is typically flipped: origin top-left)
			// Because targetView is NSView, flipped usually true, origin top-left
			// So convert y by (viewHeight - box.origin.y - box.height)
			let convertedRect = CGRect(
				x: box.origin.x * scaleX,
				y: viewHeight - (box.origin.y + box.height) * scaleY,
				width: box.width * scaleX,
				height: box.height * scaleY
			)

			let path = CGPath(rect: convertedRect, transform: nil)

			overlay.path = path
			overlay.strokeColor = NSColor.red.cgColor
			overlay.fillColor = NSColor.red.withAlphaComponent(0.2).cgColor
			overlay.lineWidth = 2.0
		}

		@MainActor
		private func clearDebugBox() {
			if let debugOverlayLayer {
				debugOverlayLayer.removeFromSuperlayer()
				self.debugOverlayLayer = nil
			}
		}
	#endif

	@MainActor
	init(targetView: NSView) {
		self.targetView = targetView
		self.currentKeyTranslator = LayoutTranslator()!
	}

	func run(command: BootCommandStep) async throws {
		for step in command.steps {
			do {
				if try await execute(step, title: command.title) == false {
					logger.info("Skip command: command: \(command.title)")
					break
				}
			} catch {
				throw PackerLiteDriverError.stepFailed(step: command, underlying: error)
			}
		}
		#if DEBUG
			await clearDebugBox()
		#endif
	}

	private func execute(_ step: BootCommandStep.Step, title: String) async throws -> Bool {
		switch step {
		case .wait(let seconds):
			logger.debug("[\(title)]: wait \(seconds)s")
			try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
			return true

		case .type(let text):
			logger.debug("[\(title)]: type \(text) with modifier \(modifiers)")
			try await type(text)

		case .press(let key, let repeated):
			logger.debug("[\(title)]: press \(repeated) \(key) with modifier \(modifiers)")
			try await press(keysym(for: key), repeated: repeated)

		case .modifierOn(let modifier):
			logger.debug("[\(title)]: modifierOn \(modifier) with modifier \(modifiers)")
			await self.handleKeyModifierEvent(keysym(for: modifier), isDown: true)

		case .modifierOff(let modifier):
			logger.debug("[\(title)]: modifierOff \(modifier) with modifier \(modifiers)")
			await self.handleKeyModifierEvent(keysym(for: modifier), isDown: false)

		case .click(let point):
			logger.debug("[\(title)]: click \(point)")
			await click(point)

		case .clickText(let label, let timeout):
			logger.debug("[\(title)]: clickText '\(label)', timeout=\(timeout)")
			try await clickText(label, timeout: timeout)

		case .locate(let label, let timeout):
			logger.debug("[\(title)]: locate '\(label)', timeout=\(timeout)")
			try await locateText(label, timeout: timeout)

		case .skipNotFound(let label, let timeout):
			logger.debug("[\(title)]: skipNotFound '\(label)', timeout=\(timeout)")
			if try await skipNotFound(label, timeout: timeout) == false {
				return false
			}

		case .scroll(let horizontal, let vertical):
			logger.debug("[\(title)]: scroll '\(horizontal), \(vertical)'")
			try await scroll(horizontal, vertical)

		case .keyboard(let layout):
			logger.debug("[\(title)]: keyboard layout \(layout.id)")
			currentKeyTranslator = layout
		}

		try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)

		return true
	}

	// MARK: - Keyboard
	@MainActor private func type(_ text: String) async throws {
		for char in text {
			if let key = currentKeyTranslator.translate(char: char) {
				let modifiers = key.modifiers.keyCodes

				for code in modifiers {
					self.handleKeyModifierEvent(code, isDown: true)
					try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
				}

				self.handleKeyEvent(key.keyCode, characters: key.characters, charactersIgnoringModifiers: key.charactersIgnoringModifiers, isDown: true)

				try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)

				self.handleKeyEvent(key.keyCode, characters: key.characters, charactersIgnoringModifiers: key.charactersIgnoringModifiers, isDown: false)

				for code in modifiers {
					try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
					self.handleKeyModifierEvent(code, isDown: false)
				}
			}
		}
	}

	@MainActor private func press(_ keyCode: CGKeyCode, repeated: Int) async throws {
		for _ in 0..<repeated {
			self.handleKeySpecialEvent(keyCode, isDown: true)
			try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)

			self.handleKeySpecialEvent(keyCode, isDown: false)
			try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
		}
	}

	private func keysym(for key: KeyToken) -> CGKeyCode {
		switch key {
		case .enter: return CGKeyCodes.return
		case .esc: return CGKeyCodes.escape
		case .tab: return CGKeyCodes.tab
		case .spacebar: return CGKeyCodes.space
		case .backspace: return CGKeyCodes.delete
		case .delete: return CGKeyCodes.forwardDelete
		case .insert: return CGKeyCodes.help
		case .home: return CGKeyCodes.home
		case .end: return CGKeyCodes.end
		case .pageUp: return CGKeyCodes.pageUp
		case .pageDown: return CGKeyCodes.pageDown
		case .up: return CGKeyCodes.upArrow
		case .down: return CGKeyCodes.downArrow
		case .left: return CGKeyCodes.leftArrow
		case .right: return CGKeyCodes.rightArrow
		case .function(let number): return CGKeyCodes.functionKeys[number - 1]
		}
	}

	private func keysym(for modifier: ModifierToken) -> CGKeyCode {
		switch modifier {
		case .leftShift: return CGKeyCodes.shift
		case .rightShift: return CGKeyCodes.rightShift
		case .leftAlt: return CGKeyCodes.command
		case .rightAlt: return CGKeyCodes.rightCommand
		case .leftCtrl: return CGKeyCodes.control
		case .rightCtrl: return CGKeyCodes.rightControl
		case .leftSuper: return CGKeyCodes.option
		case .rightSuper: return CGKeyCodes.rightOption
		case .function: return CGKeyCodes.function
		}
	}

	// MARK: - Keyboard layout translation (current layout -> Foreign)
	struct LayoutTranslator: KeyLayoutTranslator {
		let id: String

		private let characterKeys: [Character: CGKeyCode]
		private let keysCharacters: [CGKeyCode: Character]
		private let charactersModifiers: [Character: NSEvent.ModifierFlags]

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
			let array = (unmanagedList.takeRetainedValue() as [AnyObject]).map { unsafeBitCast($0, to: TISInputSource.self) }

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
		init?(_ targetKeyboard: TISInputSource) {
			guard let layoutDataPtr = TISGetInputSourceProperty(targetKeyboard, kTISPropertyUnicodeKeyLayoutData) else {
				return nil
			}

			let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
			if CFDataGetLength(layoutData) == 0 {
				return nil
			}

			var characterKeys: [Character: CGKeyCode] = [:]
			var keysCharacters: [CGKeyCode: Character] = [:]
			var charactersModifiers: [Character: NSEvent.ModifierFlags] = [:]

			CFDataGetBytePtr(layoutData).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { keyboardLayoutPtr in
				for keyCode in (0..<128).map({ CGKeyCode($0) }) {
					var characterIgnoringModifiers: Character? = nil

					if let char = Self.translate(keyCode: keyCode, modifiers: 0, keyboardLayout: keyboardLayoutPtr) {
						characterKeys[char] = keyCode
						charactersModifiers[char] = []
						keysCharacters[keyCode] = char
						characterIgnoringModifiers = char
					}

					if let char = Self.translate(keyCode: keyCode, modifiers: UInt32(shiftKey | optionKey), keyboardLayout: keyboardLayoutPtr) {
						characterKeys[char] = keyCode
						charactersModifiers[char] = .shift.union(.option)

						if let characterIgnoringModifiers {
							keysCharacters[keyCode] = characterIgnoringModifiers
						}
					}

					if let char = Self.translate(keyCode: keyCode, modifiers: UInt32(optionKey), keyboardLayout: keyboardLayoutPtr) {
						characterKeys[char] = keyCode
						charactersModifiers[char] = .option

						if let characterIgnoringModifiers {
							keysCharacters[keyCode] = characterIgnoringModifiers
						}
					}

					if let char = Self.translate(keyCode: keyCode, modifiers: UInt32(shiftKey), keyboardLayout: keyboardLayoutPtr) {
						characterKeys[char] = keyCode
						charactersModifiers[char] = .shift

						if let characterIgnoringModifiers {
							keysCharacters[keyCode] = characterIgnoringModifiers
						}
					}
				}
			}

			self.characterKeys = characterKeys
			self.keysCharacters = keysCharacters
			self.charactersModifiers = charactersModifiers
			self.id = targetKeyboard.getSourceID()!
		}

		@MainActor
		init?() {
			self.init(TISCopyCurrentKeyboardInputSource().takeRetainedValue())
		}

		@MainActor
		init?(_ keyLayout: String = "com.apple.keylayout.US") {
			// Build maps once at init time. If the user changes layouts at runtime, you can re-instantiate this struct.
			guard let targetKeyboard = Self.getNamedInputSource(keyLayout) else {
				return nil
			}

			self.init(targetKeyboard)
		}

		func translate(char: Character) -> (keyCode: CGKeyCode, modifiers: NSEvent.ModifierFlags, characters: String, charactersIgnoringModifiers: String)? {
			guard let keyCode = self.characterKeys[char] else {
				return nil
			}

			var characterIgnoringModifiers: String = String.empty

			if let char = self.keysCharacters[keyCode] {
				characterIgnoringModifiers = String(char)
			}

			return (keyCode, self.charactersModifiers[char] ?? [], String(char), characterIgnoringModifiers)
		}

		private static func translate(keyCode: CGKeyCode, modifiers: UInt32, keyboardLayout: UnsafePointer<UCKeyboardLayout>) -> Character? {
			var deadKeyState: UInt32 = 0
			var chars: [UniChar] = Array(repeating: 0, count: 4)
			var len: Int = 0
			let result = UCKeyTranslate(
				keyboardLayout,
				keyCode,
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

	@MainActor private func click(_ nsPoint: CGPoint) {
		logger.debug("clickText \(nsPoint)")

		self.handlePointerEvent(nsPoint, buttonMask: 0x01)
		self.handlePointerEvent(nsPoint, buttonMask: 0x00)
	}

	@MainActor private func scroll(_ horizontal: Int, _ vertical: Int) async throws {
		// Ensure the view is first responder when pointer interaction begins
		ensureFirstResponder()

		dispatchEvent(targetView.postScrollEvent(eventSource: eventSource, deltaX: Int32(horizontal), deltaY: Int32(vertical), at: lastMousePosition, modifierFlags: self.modifiers), view: targetView)
	}

	@MainActor private func clickText(_ label: String, timeout: TimeInterval) async throws {
		let deadline = Date().addingTimeInterval(timeout)

		while true {
			if let point = try await locate(text: label) {
				click(point)
				try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
				return
			}

			if Date() >= deadline {
				throw PackerLiteDriverError.textNotFound(label)
			}

			try await Task.sleep(nanoseconds: Self.clickTextPollNanoseconds)
		}
	}

	@MainActor private func skipNotFound(_ label: String, timeout: TimeInterval) async throws -> Bool {
		let deadline = Date().addingTimeInterval(timeout)

		while true {
			if let point = try await locate(text: label) {
				self.logger.debug("Text found: \(label) at: \(point)")
				try await Task.sleep(nanoseconds: Self.keyDelayNanoseconds)
				return true
			}

			if Date() >= deadline {
				return false
			}

			try await Task.sleep(nanoseconds: Self.clickTextPollNanoseconds)
		}
	}

	@MainActor private func locateText(_ label: String, timeout: TimeInterval) async throws {
		let deadline = Date().addingTimeInterval(timeout)

		while true {
			if let point = try await locate(text: label) {
				self.logger.debug("Text found: \(label) at: \(point)")
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
	private func locate(text label: String) async throws -> CGPoint? {
		// Capture the current CGImage on the main actor (AppKit view access must be on main).
		guard let cgImage = await self.targetView.imageRepresentation(in: self.targetView.bounds)?.cgImage else {
			return nil
		}

		let logger = self.logger

		// Perform Vision work off the main actor at a lower priority to avoid QoS inversions.
		return try await Task.detached(priority: .utility) { () throws -> CGPoint? in
			let request = VNRecognizeTextRequest()
			request.recognitionLevel = .accurate

			do {
				try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

				guard let results = request.results, !results.isEmpty else {
					return nil
				}

				let needle = label.lowercased()

				for observation in results {
					guard let candidate = observation.topCandidates(1).first, candidate.string.lowercased().contains(needle) else {
						continue
					}

					// Rect in image coordinates. If you need top-left to bottom-left conversion, flip the y-origin.
					let box = VNImageRectForNormalizedRect(observation.boundingBox, Int(cgImage.width), Int(cgImage.height))
					let flippedBox = CGRect(
						x: box.origin.x,
						y: CGFloat(cgImage.height) - box.origin.y - box.height,
						width: box.width,
						height: box.height)

					#if DEBUG
						await self.showDebugBox(flippedBox, in: CGSize(width: cgImage.width, height: cgImage.height))
					#endif

					return CGPoint(x: flippedBox.midX, y: flippedBox.midY)
				}
			} catch {
				logger.error("Vision OCR failed: \(error)")
			}

			return nil
		}.value
	}
}

// MARK: Input handler
extension PackerLiteDriver {
	// MARK: - First Responder
	@discardableResult
	private func ensureFirstResponder() -> Bool {
		guard let window = targetView.window else {
			return false
		}

		// If the view is not already first responder, ask the window to make it so
		if window.firstResponder !== targetView {
			return window.makeFirstResponder(targetView)
		}

		return true
	}

	// MARK: - Mouse Events

	func handlePointerEvent(_ nsPoint: CGPoint, buttonMask: UInt8) {
		// Ensure the view is first responder when pointer interaction begins
		ensureFirstResponder()

		let moved = nsPoint != lastMousePosition

		// Handle mouse buttons with move
		if handleMouseButtons(targetView, buttonMask: buttonMask, at: nsPoint, moved: moved) == false {
			if moved {
				// Handle mouse movement
				handleMouseMovement(to: nsPoint)
			}
		}

		lastMousePosition = nsPoint
	}

	private func dispatchEvent(_ event: NSEvent?, view: NSView) {
		if let event = event {
			switch event.type {
			case .scrollWheel:
				view.scrollWheel(with: event)
			case .mouseEntered:
				isDragging = true
				view.mouseEntered(with: event)
			case .mouseExited:
				isDragging = false
				view.mouseExited(with: event)

			case .leftMouseDragged:
				view.mouseDragged(with: event)
			case .rightMouseDragged:
				view.rightMouseDragged(with: event)
			case .otherMouseDragged:
				view.otherMouseDragged(with: event)

			case .leftMouseDown:
				view.mouseDown(with: event)
			case .rightMouseDown:
				view.rightMouseDown(with: event)
			case .otherMouseDown:
				view.otherMouseDown(with: event)

			case .leftMouseUp:
				view.mouseUp(with: event)
			case .rightMouseUp:
				view.rightMouseUp(with: event)
			case .otherMouseUp:
				view.otherMouseUp(with: event)
			default:
				break
			}
		}
	}

	private func handleMouseButtons(_ view: NSView, buttonMask: UInt8, at viewPoint: NSPoint, moved: Bool) -> Bool {
		let previousState = mouseButtonState
		var buttonEvent = false

		mouseButtonState = buttonMask

		// Left button (bit 0)
		if (buttonMask & 0x01) != (previousState & 0x01) {
			buttonEvent = true

			if moved {
				if (buttonMask & 0x01) != 0 {
					dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				} else {
					dispatchEvent(view.postEnterExitEvent(type: .mouseExited, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				}
			} else {
				if (buttonMask & 0x01) != 0 {
					dispatchEvent(view.postMouseEvent(type: .leftMouseDown, at: viewPoint, modifierFlags: self.modifiers), view: view)
				} else {
					dispatchEvent(view.postMouseEvent(type: .leftMouseUp, at: viewPoint, modifierFlags: self.modifiers), view: view)
				}
			}
		} else if (buttonMask & 0x01) != 0 {
			buttonEvent = true

			if isDragging {
				dispatchEvent(view.postMouseEvent(type: .leftMouseDragged, at: viewPoint, modifierFlags: self.modifiers), view: view)
			} else {
				dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
			}
		}

		// Right button (bit 2)
		if (buttonMask & 0x04) != (previousState & 0x04) {
			buttonEvent = true

			if moved {
				if (buttonMask & 0x04) != 0 {
					dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				} else {
					dispatchEvent(view.postEnterExitEvent(type: .mouseExited, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				}
			} else {
				if (buttonMask & 0x04) != 0 {
					dispatchEvent(view.postMouseEvent(type: .rightMouseDown, at: viewPoint, modifierFlags: self.modifiers), view: view)
				} else {
					dispatchEvent(view.postMouseEvent(type: .rightMouseUp, at: viewPoint, modifierFlags: self.modifiers), view: view)
				}
			}
		} else if (buttonMask & 0x04) != 0 {
			buttonEvent = true

			if isDragging {
				dispatchEvent(view.postMouseEvent(type: .rightMouseDragged, at: viewPoint, modifierFlags: self.modifiers), view: view)
			} else {
				dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
			}
		}

		// Middle button (bit 1)
		if (buttonMask & 0x02) != (previousState & 0x02) {
			buttonEvent = true

			if moved {
				if (buttonMask & 0x02) != 0 {
					dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				} else {
					dispatchEvent(view.postEnterExitEvent(type: .mouseExited, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				}
			} else {
				if (buttonMask & 0x02) != 0 {
					dispatchEvent(view.postMouseEvent(type: .otherMouseDown, at: viewPoint, modifierFlags: self.modifiers), view: view)
				} else {
					dispatchEvent(view.postMouseEvent(type: .otherMouseUp, at: viewPoint, modifierFlags: self.modifiers), view: view)
				}
			}
		} else if (buttonMask & 0x02) != 0 {
			buttonEvent = true

			if isDragging {
				dispatchEvent(view.postMouseEvent(type: .otherMouseDragged, at: viewPoint, modifierFlags: self.modifiers), view: view)
			} else {
				dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
			}
		}

		// Scroll wheel (bits 3 and 4)
		if (buttonMask & 0x08) != 0 {  // Scroll up
			dispatchEvent(view.postScrollEvent(eventSource: eventSource, deltaX: 0, deltaY: 1, at: viewPoint, modifierFlags: self.modifiers), view: view)
		}

		if (buttonMask & 0x10) != 0 {  // Scroll down
			dispatchEvent(view.postScrollEvent(eventSource: eventSource, deltaX: 0, deltaY: -1, at: viewPoint, modifierFlags: self.modifiers), view: view)
		}

		// Scroll wheel (bits 5 and 6)
		if (buttonMask & 0x20) != 0 {  // Scroll up
			dispatchEvent(view.postScrollEvent(eventSource: eventSource, deltaX: 1, deltaY: 0, at: viewPoint, modifierFlags: self.modifiers), view: view)
		}

		if (buttonMask & 0x40) != 0 {  // Scroll down
			dispatchEvent(view.postScrollEvent(eventSource: eventSource, deltaX: -1, deltaY: 0, at: viewPoint, modifierFlags: self.modifiers), view: view)
		}

		return buttonEvent
	}

	private func handleMouseMovement(to viewPoint: NSPoint) {
		if let event = targetView.postMouseEvent(type: .mouseMoved, at: viewPoint, modifierFlags: self.modifiers) {
			targetView.mouseMoved(with: event)
		}
	}

	// MARK: - Keyboard Events
	@MainActor func handleKeySpecialEvent(_ keyCode: CGKeyCode, isDown: Bool) {
		ensureFirstResponder()

		guard let keyboardEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: isDown) else {
			return
		}

		guard
			let event = NSEvent.keyEvent(
				with: keyboardEvent.type == .flagsChanged ? .flagsChanged : (isDown ? .keyDown : .keyUp),
				location: lastMousePosition,
				modifierFlags: self.modifiers,
				timestamp: ProcessInfo.processInfo.systemUptime,
				windowNumber: self.targetView.window?.windowNumber ?? 0,
				context: nil,
				characters: String.empty,
				charactersIgnoringModifiers: String.empty,
				isARepeat: false,
				keyCode: keyCode)
		else {
			return
		}

		if event.type == .flagsChanged {
			self.targetView.flagsChanged(with: event)
		} else if isDown {
			self.targetView.keyDown(with: event)
		} else {
			self.targetView.keyUp(with: event)
		}
	}

	@MainActor func handleKeyModifierEvent(_ keyCode: CGKeyCode, isDown: Bool) {
		ensureFirstResponder()

		guard let keyboardEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: isDown) else {
			return
		}

		switch keyCode {
		case CGKeyCodes.shift:
			if isDown {
				self.modifiers.insert(.leftShift.union(.shift))
			} else {
				self.modifiers.remove(.leftShift.union(.shift))
			}
		case CGKeyCodes.rightShift:
			if isDown {
				self.modifiers.insert(.rightShift.union(.shift))
			} else {
				self.modifiers.remove(.rightShift.union(.shift))
			}

		case CGKeyCodes.control:
			if isDown {
				self.modifiers.insert(.leftControl.union(.control))
			} else {
				self.modifiers.remove(.leftControl.union(.control))
			}
		case CGKeyCodes.rightControl:
			if isDown {
				self.modifiers.insert(.rightControl.union(.control))
			} else {
				self.modifiers.remove(.rightControl.union(.control))
			}

		case CGKeyCodes.option:
			if isDown {
				self.modifiers.insert(.leftOption.union(.option))
			} else {
				self.modifiers.remove(.leftOption.union(.option))
			}
		case CGKeyCodes.rightOption:
			if isDown {
				self.modifiers.insert(.rightOption.union(.option))
			} else {
				self.modifiers.remove(.rightOption.union(.option))
			}

		case CGKeyCodes.command:
			if isDown {
				self.modifiers.insert(.leftCommand.union(.command))
			} else {
				self.modifiers.remove(.leftCommand.union(.command))
			}
		case CGKeyCodes.rightCommand:
			if isDown {
				self.modifiers.insert(.rightCommand.union(.command))
			} else {
				self.modifiers.remove(.rightCommand.union(.command))
			}

		case CGKeyCodes.capsLock:
			if isDown {
				self.modifiers.insert(.capsLock)
			} else {
				self.modifiers.remove(.capsLock)
			}

		case CGKeyCodes.help:
			if isDown {
				self.modifiers.insert(.help)
			} else {
				self.modifiers.remove(.help)
			}

		case CGKeyCodes.function:
			if isDown {
				self.modifiers.insert(.function)
			} else {
				self.modifiers.remove(.function)
			}
		default:
			break
		}

		guard
			let event = NSEvent.keyEvent(
				with: keyboardEvent.type == .flagsChanged ? .flagsChanged : (isDown ? .keyDown : .keyUp),
				location: lastMousePosition,
				modifierFlags: self.modifiers,
				timestamp: ProcessInfo.processInfo.systemUptime,
				windowNumber: self.targetView.window?.windowNumber ?? 0,
				context: nil,
				characters: String.empty,
				charactersIgnoringModifiers: String.empty,
				isARepeat: false,
				keyCode: keyCode)
		else {
			return
		}

		if event.type == .flagsChanged {
			self.targetView.flagsChanged(with: event)
		} else if isDown {
			self.targetView.keyDown(with: event)
		} else {
			self.targetView.keyUp(with: event)
		}
	}

	@MainActor func handleKeyEvent(_ keyCode: CGKeyCode, characters: String, charactersIgnoringModifiers: String, isDown: Bool) {
		// Ensure the view is first responder before delivering key events
		ensureFirstResponder()

		guard let keyboardEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: isDown) else {
			return
		}

		guard
			let event = NSEvent.keyEvent(
				with: keyboardEvent.type == .flagsChanged ? .flagsChanged : (isDown ? .keyDown : .keyUp),
				location: lastMousePosition,
				modifierFlags: self.modifiers,
				timestamp: ProcessInfo.processInfo.systemUptime,
				windowNumber: self.targetView.window?.windowNumber ?? 0,
				context: nil,
				characters: characters,
				charactersIgnoringModifiers: charactersIgnoringModifiers,
				isARepeat: false,
				keyCode: keyCode)
		else {
			return
		}

		if event.type == .flagsChanged {
			self.targetView.flagsChanged(with: event)
		} else if isDown {
			self.targetView.keyDown(with: event)
		} else {
			self.targetView.keyUp(with: event)
		}
	}
}
