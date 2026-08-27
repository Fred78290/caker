//
//  ActionRecorder.swift
//  CakedLib
//
//  The reverse of PackerLiteDriver: instead of replaying a parsed boot_command against a VM's
//  rendered view, this accumulates the real pointer/keyboard input a human operator performs
//  through a VNC session — captured via the recording tap on VNCInputHandler (see
//  VNCInputHandler.swift's `actionRecorder`) — and, on `finish()`, serializes it into a
//  ready-to-use `boot_command:` YAML document in the same shape PackerLiteTemplate parses. This
//  is the engine behind `caked record` (Sources/caked/Commands/Record.swift).
//

import AppKit
import Foundation
import GRPCLib
import RoyalVNCKit
import Yams

/// One resolved pointer or keyboard event captured while a recording session is active. Carries
/// exactly the values `VNCInputHandler` already resolves for real input dispatch — recording is a
/// pure observer, it never re-derives or re-translates anything itself.
public enum RecordedAction: Sendable {
	case pointer(x: Int, y: Int, buttonMask: UInt8, timestamp: Date)
	case key(keyCode: CGKeyCode, modifiers: NSEvent.ModifierFlags, characters: String, charactersIgnoringModifiers: String, isDown: Bool, timestamp: Date)
}

/// Called for every resolved action while a recording session is armed. Set on
/// `VNCInputHandler.actionRecorder` — nil (zero overhead) otherwise.
public typealias RecordedActionHandler = (_ sender: NSView, _ action: RecordedAction) -> Void

typealias RecognizedTextes = [ActionRecorder.RecognizedText]

extension RecognizedTextes {
	public func textUnderPoint(of point: CGPoint) -> ActionRecorder.RecognizedText? {
		self.first {
			$0.recognized.box.contains(point)
		}
	}
}

/// Accumulates one `caked record` session's `RecordedAction` log and turns it into a
/// `boot_command:`-shaped YAML document on `finish()`. Thread-safe: VNC input arrives on the
/// connection's own background dispatch queue, not necessarily the main thread.
public final class ActionRecorder: @unchecked Sendable {
	/// One already-classified, chronologically-ordered step ready to become a `boot_command` entry.
	/// `text` carries both ends of its run — `end` (the last coalesced character's own timestamp,
	/// not the run's start) is what the *next* step's gap-to-`<waitNs>` calculation in `finish()`
	/// needs, since a multi-character run can itself span a non-trivial amount of wall-clock time.
	private enum Step {
		case text(String, start: Date, end: Date)
		case press(KeyToken, timestamp: Date)
		case modifierOn(ModifierToken, timestamp: Date)
		case modifierOff(ModifierToken, timestamp: Date)
		case click(x: Int, y: Int, timestamp: Date)
		case clickText(text: String, timestamp: Date)
		case locate(text: String, timestamp: Date)

		var startTimestamp: Date {
			switch self {
			case .text(_, let start, _): return start
			case .press(_, let timestamp), .modifierOn(_, let timestamp), .modifierOff(_, let timestamp), .click(_, _, let timestamp): return timestamp
			case .clickText(_, timestamp: let timestamp):  return timestamp
			case .locate(_, timestamp: let timestamp):  return timestamp
			}
		}

		var endTimestamp: Date {
			switch self {
			case .text(_, _, let end): return end
			case .press(_, let timestamp), .modifierOn(_, let timestamp), .modifierOff(_, let timestamp), .click(_, _, let timestamp): return timestamp
			case .clickText(_, timestamp: let timestamp):  return timestamp
			case .locate(_, timestamp: let timestamp):  return timestamp
			}
		}

		/// Turns this step into its `boot_command` token, scrubbing a literal text run that
		/// exactly matches the VM's own account into `${var.username}`/`${var.password}` first —
		/// see this file's header and CLAUDE.md's PackerLite credential-scrubbing note. This is a
		/// hard requirement, not optional: every bundled template treats the account as
		/// caller-supplied, never hardcoded.
		func command(username: String?, password: String?) -> PackerLiteTemplate.Command {
			switch self {
			case .text(let text, _, _):
				let scrubbed: String
				let title: String

				if let username, username.isEmpty == false, text == username {
					scrubbed = "${var.username}"
					title = String(localized: "Type username")
				} else if let password, password.isEmpty == false, text == password {
					scrubbed = "${var.password}"
					title = String(localized: "Type password")
				} else {
					scrubbed = text
					title = String(localized: "Type text")
				}

				return PackerLiteTemplate.Command(title: title, commands: [scrubbed])

			case .press(let key, _):
				return PackerLiteTemplate.Command(title: String(localized: "Press <\(key.tokenName)>"), commands: ["<\(key.tokenName)>"])

			case .modifierOn(let modifier, _):
				return PackerLiteTemplate.Command(title: String(localized: "Hold \(modifier.tokenName)"), commands: ["<\(modifier.tokenName)On>"])

			case .modifierOff(let modifier, _):
				return PackerLiteTemplate.Command(title: String(localized: "Release \(modifier.tokenName)"), commands: ["<\(modifier.tokenName)Off>"])

			case .click(let x, let y, _):
				return PackerLiteTemplate.Command(title: String(localized: "Click at (\(x), \(y))"), commands: ["<click point=\"\(x),\(y)\">"])
			case .clickText(text: let text, _):
				return PackerLiteTemplate.Command(title: String(localized: "Click on (\(text))"), commands: ["<click text=\"\(text)\">"])
			case .locate(text: let text, _):
				return PackerLiteTemplate.Command(title: String(localized: "Locate (\(text))"), commands: ["<locate text=\"\(text)\">"])
			}
		}
	}

	/// Below this, a gap between two consecutive actions is assumed to be normal human
	/// hesitation/reaction time and isn't worth its own `<waitNs>` step — keeps the generated
	/// template readable instead of a `<wait>` before every single keystroke.
	private static let minimumWaitToRecord: TimeInterval = 1.0

	/// Inverts `PackerLiteDriver.keysym(for:)` — built once from the *existing* forward table
	/// (made `internal static` specifically for this) instead of hand-writing a second
	/// keyCode→token mapping that could silently drift out of sync with it.
	private static let keyTokenForKeyCode: [CGKeyCode: KeyToken] = {
		let simple: [KeyToken] = [.enter, .esc, .tab, .spacebar, .backspace, .delete, .insert, .home, .end, .pageUp, .pageDown, .up, .down, .left, .right]
		var map = Dictionary(uniqueKeysWithValues: simple.map { (PackerLiteDriver.keysym(for: $0), $0) })

		for number in 1...20 {
			map[PackerLiteDriver.keysym(for: .function(number))] = .function(number)
		}

		return map
	}()

	/// Same inversion as `keyTokenForKeyCode`, for modifier keys.
	private static let modifierTokenForKeyCode: [CGKeyCode: ModifierToken] = {
		let modifiers: [ModifierToken] = [.leftShift, .rightShift, .leftAlt, .rightAlt, .leftCtrl, .rightCtrl, .leftSuper, .rightSuper, .function]

		return Dictionary(uniqueKeysWithValues: modifiers.map { (PackerLiteDriver.keysym(for: $0), $0) })
	}()

	private let lock = NSLock()
	private var steps: [Step] = []
	private var pendingText = String.empty
	private var pendingTextStart: Date? = nil
	private var pendingTextLastCharacter: Date? = nil
	private var pendingClickStart: (x: Int, y: Int, timestamp: Date)? = nil
	private var previousButtonMask: UInt8 = 0

	/// The VM's own configured account (`CakeConfig.configuredUser`/`configuredPassword`) — a
	/// recorded literal text run exactly matching either is scrubbed on `finish()`.
	private let username: String?
	private let password: String?
	private let os: VirtualizedOS
	private var currentModifiers: Set<ModifierToken> = []
	private var currentRecognizedText: RecognizedTextes?

	public struct RecognizedText {
		let recognized: NSView.RecognizedText
		let layer: CALayer
	}

	public init(os: VirtualizedOS, username: String?, password: String?) {
		self.username = username
		self.password = password
		self.os = os
	}

	public func reset() {
		self.lock.withLock {
			self.steps.removeAll()
			self.pendingText.removeAll()
			self.pendingTextStart = nil
			self.pendingTextLastCharacter = nil
			self.pendingClickStart = nil
		}
	}

	/// Feeds one resolved action into the recorder. Safe to call from any thread — VNC input
	/// arrives on the connection's own background dispatch queue.
	public func record(_ sender: NSView, _ action: RecordedAction) {
		self.lock.withLock {
			switch action {
			case .pointer(let x, let y, let buttonMask, let timestamp):
				self.recordPointer(x: x, y: y, buttonMask: buttonMask, timestamp: timestamp)
			case .key(let keyCode, _, let characters, _, let isDown, let timestamp):
				self.recordKey(sender, keyCode: keyCode, characters: characters, isDown: isDown, timestamp: timestamp)
			}
		}
	}

	// MARK: - Pointer

	/// Only the left button is turned into `<click point="X,Y">` tokens (v1 scope, per the design
	/// brief) — a down→up transition close together becomes one click recorded at the down
	/// position; movement and other buttons are observed only to track that state, not emitted.
	private func recordPointer(x: Int, y: Int, buttonMask: UInt8, timestamp: Date) {
		let leftBit: UInt8 = 0x01
		let wasDown = (self.previousButtonMask & leftBit) != 0
		let isDown = (buttonMask & leftBit) != 0

		if isDown && wasDown == false {
			self.pendingClickStart = (x, y, timestamp)
		} else if isDown == false && wasDown, let start = self.pendingClickStart {
			self.flushPendingText()

			if let recognizedText = self.currentRecognizedText?.textUnderPoint(of: CGPoint(x: start.x, y: start.y)) {
				if self.currentModifiers.contains(.leftShift) || self.currentModifiers.contains(.rightShift) {
					steps.append(.clickText(text: recognizedText.recognized.text, timestamp: start.timestamp))
				} else {
					steps.append(.locate(text: recognizedText.recognized.text, timestamp: start.timestamp))
				}
			} else {
				self.steps.append(.click(x: start.x, y: start.y, timestamp: start.timestamp))
			}
			self.pendingClickStart = nil
		}

		self.previousButtonMask = buttonMask
	}

	// MARK: - Keyboard
	private func hideRecognizedText(_ sender: NSView) {
		guard let currentRecognizedText = self.currentRecognizedText else {
			return
		}

		currentRecognizedText.forEach {
			$0.layer.removeFromSuperlayer()
		}

		self.currentRecognizedText = nil
	}

	private func showRecognizedText(_ sender: NSView) {
		guard let (imageSize, recognizedText) = sender.recognizeText() else { return }

		hideRecognizedText(sender)

		self.currentRecognizedText = recognizedText.compactMap { text in
			if let layer = sender.layer {
				sender.wantsLayer = true

				let overlay = CAShapeLayer()

				overlay.zPosition = 1000
				layer.addSublayer(overlay)

				// Convert the box from image coordinates (origin bottom-left) to the targetView coordinate space (origin bottom-left).
				// VNImageRectForNormalizedRect yields rect in image coords origin bottom-left.
				// NSView's layer has origin bottom-left if flipped is false, else origin top-left.
				// AppKit views often have flipped coordinate system (origin top-left). Convert accordingly.

				let viewHeight = sender.bounds.height
				let viewWidth = sender.bounds.width

				// The CGImage and view might differ in size, so scale accordingly
				let scaleX = viewWidth / imageSize.width
				let scaleY = viewHeight / imageSize.height

				// Box origin is bottom-left, need to convert to AppKit's coordinate system (which is typically flipped: origin top-left)
				// Because targetView is NSView, flipped usually true, origin top-left
				// So convert y by (viewHeight - box.origin.y - box.height)
				let convertedRect = CGRect(
					x: text.box.origin.x * scaleX,
					y: viewHeight - (text.box.origin.y + text.box.height) * scaleY,
					width: text.box.width * scaleX,
					height: text.box.height * scaleY
				)

				let path = CGPath(rect: convertedRect, transform: nil)

				overlay.path = path
				overlay.strokeColor = NSColor.blue.cgColor
				overlay.fillColor = NSColor.blue.withAlphaComponent(0.2).cgColor
				overlay.lineWidth = 2.0

				return RecognizedText(recognized: text, layer: overlay)
			}

			return nil
		}
	}

	private func checkTextRecognition(_ sender: NSView, for modifierToken: ModifierToken, isDown: Bool) {
		if isDown {
			currentModifiers.insert(modifierToken)
		} else {
			currentModifiers.remove(modifierToken)
		}

		if currentModifiers.contains(.function) {
			showRecognizedText(sender)
		} else {
			hideRecognizedText(sender)
		}
	}

	private func recordKey(_ sender: NSView, keyCode: CGKeyCode, characters: String, isDown: Bool, timestamp: Date) {
		if let modifierToken = Self.modifierTokenForKeyCode[keyCode] {
			self.checkTextRecognition(sender, for: modifierToken, isDown: isDown)
			self.flushPendingText()
			self.steps.append(isDown ? .modifierOn(modifierToken, timestamp: timestamp) : .modifierOff(modifierToken, timestamp: timestamp))
			return
		}

		// Only key-down drives token generation — replay (PackerLiteDriver.type/.press) synthesizes
		// both the down and up half itself for a `.type`/`.press` step, so the up half of a
		// non-modifier key carries nothing new to record.
		guard isDown else {
			return
		}

		if let keyToken = Self.keyTokenForKeyCode[keyCode] {
			self.flushPendingText()
			self.steps.append(.press(keyToken, timestamp: timestamp))
			return
		}

		// Not a key this vocabulary has a named token for. If it produced a printable character,
		// coalesce it into the running literal-text run; otherwise there's nothing sensible to
		// record (an unmapped shortcut, dead key, etc.) — skip it rather than emit garbage.
		guard characters.isEmpty == false, characters.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) == false else {
			return
		}

		// A pause at least as long as minimumWaitToRecord between two otherwise-adjacent
		// keystrokes breaks the text run too, not just non-character events — without this, two
		// characters typed seconds apart with nothing recognizable in between would silently
		// coalesce into one run and the gap between them would never get a <waitNs> (wait-gap
		// insertion in finish() only looks at gaps *between* steps, and one run is one step).
		if let lastCharacter = self.pendingTextLastCharacter, timestamp.timeIntervalSince(lastCharacter) >= Self.minimumWaitToRecord {
			self.flushPendingText()
		}

		if self.pendingText.isEmpty {
			self.pendingTextStart = timestamp
		}

		self.pendingText += characters
		self.pendingTextLastCharacter = timestamp
	}

	private func flushPendingText() {
		guard self.pendingText.isEmpty == false, let start = self.pendingTextStart, let end = self.pendingTextLastCharacter else {
			return
		}

		self.steps.append(.text(self.pendingText, start: start, end: end))
		self.pendingText = String.empty
		self.pendingTextStart = nil
		self.pendingTextLastCharacter = nil
	}

	// MARK: - Serialization

	/// Converts the accumulated log into a `boot_command:`-shaped YAML document string, one titled
	/// block per recorded step, plus a `<waitNs>` block wherever the gap since the previous step
	/// was long enough to be worth recording (`minimumWaitToRecord`).
	///
	/// This is a first draft, not a finished, reliable template: every gap becomes a fixed
	/// `<waitNs>`, and this codebase has deliberately moved *away* from blind waits toward
	/// `<locate>`/`<skipNotFound>` OCR-sync anchors precisely because fixed delays are unreliable
	/// (see CLAUDE.md's PackerLite section). Treat the output as a starting point for a human to
	/// harden with `<locate>` anchors, not as a finished artifact safe to rely on unattended.
	public func finish() -> String {
		self.lock.lock()

		self.flushPendingText()

		if let start = self.pendingClickStart {
			// A button was still held down when recording stopped — record it as a click at its
			// down position rather than silently dropping it.
			self.steps.append(.click(x: start.x, y: start.y, timestamp: start.timestamp))
			self.pendingClickStart = nil
		}

		let steps = self.steps

		self.lock.unlock()

		var commands: [PackerLiteTemplate.Command] = []
		var previousEnd: Date? = nil

		for step in steps {
			if let previousEnd {
				let gap = step.startTimestamp.timeIntervalSince(previousEnd)

				if gap >= Self.minimumWaitToRecord {
					let seconds = max(1, Int(gap.rounded()))

					commands.append(PackerLiteTemplate.Command(title: String(localized: "Wait \(seconds)s"), commands: ["<wait\(seconds)s>"]))
				}
			}

			commands.append(step.command(username: self.username, password: self.password))
			previousEnd = step.endTimestamp
		}

		let preBootCommands: [PackerLiteTemplate.Command]? = self.os == .darwin ? nil : [commands.removeFirst()]
		let document = RecordedTemplateDocument(preBootCommand: preBootCommands, bootCommand: commands)
		let encoder = YAMLEncoder()

		// Preserve field declaration order (title before commands, matching every hand-written
		// bundled template) rather than newYAMLEncoder()'s sortKeys:true used elsewhere.
		encoder.options = .init(indent: 2, width: -1, sortKeys: false)

		return (try? encoder.encode(document)) ?? String.empty
	}

	/// Number of steps accumulated so far — for a caller to sanity-check ("recorded N actions")
	/// without reaching into internals.
	public var stepCount: Int {
		self.lock.lock()
		defer { self.lock.unlock() }

		return self.steps.count
	}
}

/// Minimal encodable mirror of `PackerLiteTemplate`'s `boot_command:` shape. `PackerLiteTemplate`
/// itself is decode-only (see its own header comment) — recording needs to go the other way, so
/// this small sibling type exists purely to drive `YAMLEncoder`.
private struct RecordedTemplateDocument: Encodable {
	var preBootCommand: [PackerLiteTemplate.Command]?
	var bootCommand: [PackerLiteTemplate.Command]

	enum CodingKeys: String, CodingKey {
		case preBootCommand = "pre_boot_command"
		case bootCommand = "boot_command"
	}
}
