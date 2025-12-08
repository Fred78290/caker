import AppKit
import Carbon
import Foundation
import RoyalVNCKit

let kVK_ANSI_Exclam = CGKeyCode(0x0021)
let kVK_ANSI_Number = CGKeyCode(0x0023)
let kVK_ANSI_Dollar = CGKeyCode(0x0024)
let kVK_ANSI_Percent = CGKeyCode(0x0025)
let kVK_ANSI_Ampersand = CGKeyCode(0x0026)
let kVK_ANSI_LeftParen = CGKeyCode(0x0028)
let kVK_ANSI_RightParen = CGKeyCode(0x0029)
let kVK_ANSI_Asterisk = CGKeyCode(0x002A)
let kVK_ANSI_Plus = CGKeyCode(0x002B)
let kVK_ANSI_Caret = CGKeyCode(0x005F)
let kVK_ANSI_Underscore = CGKeyCode(0x005F)

// Source - https://stackoverflow.com/a
// Posted by jjrscott, modified by community. See post 'Timeline' for change history
// Retrieved 2025-12-05, License - CC BY-SA 4.0

//
//  CGKeyCodeInitializers.swift
//
//  Created by John Scott on 09/02/2022.
//

import Foundation
import AppKit

protocol Keymapper {
	func setupKeyMapper() throws
	func mapVNCKey(_ vncKey: UInt32, isDown: Bool, sendKeyEvent: (CGKeyCode, CGEventFlags, String?) -> Void)
}

func newKeyMapper() -> Keymapper {
	VNCKeyMapper()
}

extension CGKeyCode {
	public init?(character: String) {
		if let keyCode = Initializers.shared.characterKeys[character] {
			self = keyCode
		} else {
			return nil
		}
	}

	public init?(modifierFlag: NSEvent.ModifierFlags) {
		if let keyCode = Initializers.shared.modifierFlagKeys[modifierFlag] {
			self = keyCode
		} else {
			return nil
		}
	}
	
	public init?(specialKey: NSEvent.SpecialKey) {
		if let keyCode = Initializers.shared.specialKeys[specialKey] {
			self = keyCode
		} else {
			return nil
		}
	}
	
	struct Initializers {
		let specialKeys: [NSEvent.SpecialKey:CGKeyCode]
		let characterKeys: [String:CGKeyCode]
		let modifierFlagKeys: [NSEvent.ModifierFlags:CGKeyCode]

		static var shared: Initializers! = nil
		
		init() {
			var specialKeys = [NSEvent.SpecialKey:CGKeyCode]()
			var characterKeys = [String:CGKeyCode]()
			var modifierFlagKeys = [NSEvent.ModifierFlags:CGKeyCode]()
			let eventSource = CGEventSource(stateID: .privateState);

			for keyCode in (0..<128).map({ CGKeyCode($0) }) {
				guard let cgevent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) else { fatalError("Unable to create CGEvent for \(keyCode)") }

				if let nsevent = NSEvent(cgEvent: cgevent) {
					var hasHandledKeyCode = false
					
					if nsevent.type == .keyDown {
						if let specialKey = nsevent.specialKey {
							hasHandledKeyCode = true
							specialKeys[specialKey] = keyCode
						} else if let characters = nsevent.charactersIgnoringModifiers, !characters.isEmpty && characters != "\u{0010}" {
							hasHandledKeyCode = true
							characterKeys[characters] = keyCode
						}
					} else if nsevent.type == .flagsChanged {
						hasHandledKeyCode = true
						modifierFlagKeys[nsevent.modifierFlags] = keyCode
					} else {
						Logger("CGKeyCode").debug("Unknown event type for keycode \(keyCode): \(nsevent.type)")
					}
					
#if DEBUG
					if hasHandledKeyCode == false {
						Logger("CGKeyCode").debug("Unhandled keycode \(keyCode): \(nsevent.type)")
					}
#endif
				} else {
					fatalError("unable to create NSEvent")
				}
			}

			self.specialKeys = specialKeys
			self.characterKeys = characterKeys
			self.modifierFlagKeys = modifierFlagKeys
		}
	}

}

extension NSEvent.ModifierFlags: @retroactive Hashable { }

extension OptionSet {
	public func first(_ options: Self.Element ...) -> Self.Element? {
		for option in options {
			if contains(option) {
				return option
			}
		}
		return nil
	}
}

extension VNCKeyCode {
	public static let ansiKeypad0 = VNCKeyCode(Keysyms.XK_KP_0)
	public static let ansiKeypad1 = VNCKeyCode(Keysyms.XK_KP_1)
	public static let ansiKeypad2 = VNCKeyCode(Keysyms.XK_KP_2)
	public static let ansiKeypad3 = VNCKeyCode(Keysyms.XK_KP_3)
	public static let ansiKeypad4 = VNCKeyCode(Keysyms.XK_KP_4)
	public static let ansiKeypad5 = VNCKeyCode(Keysyms.XK_KP_5)
	public static let ansiKeypad6 = VNCKeyCode(Keysyms.XK_KP_6)
	public static let ansiKeypad7 = VNCKeyCode(Keysyms.XK_KP_7)
	public static let ansiKeypad8 = VNCKeyCode(Keysyms.XK_KP_8)
	public static let ansiKeypad9 = VNCKeyCode(Keysyms.XK_KP_9)
}

private struct VNCKeyCodeMaps {
	static let vncKeyCodeToKeyCodeMapping: [UInt32:CGKeyCode] = [
		0x0008: CGKeyCode(kVK_Delete),
		0x0009: CGKeyCode(kVK_Tab),
		0x000D: CGKeyCode(kVK_Return),
		0x001B: CGKeyCode(kVK_Escape),
		0x0020: CGKeyCode(kVK_Space),
		0x0021: CGKeyCode(kVK_ANSI_Exclam),
		0x0022: CGKeyCode(kVK_ANSI_Quote),
		0x0023: CGKeyCode(kVK_ANSI_Number),
		0x0024: CGKeyCode(kVK_ANSI_Dollar),
		0x0025: CGKeyCode(kVK_ANSI_Percent),
		0x0026: CGKeyCode(kVK_ANSI_Ampersand),
		0x0027: CGKeyCode(kVK_ANSI_Quote),
		0x0028: CGKeyCode(kVK_ANSI_LeftParen),
		0x0029: CGKeyCode(kVK_ANSI_RightParen),
		0x002A: CGKeyCode(kVK_ANSI_Asterisk),
		0x002B: CGKeyCode(kVK_ANSI_Plus),
		0x002C: CGKeyCode(kVK_ANSI_Comma),
		0x002D: CGKeyCode(kVK_ANSI_Minus),
		0x002E: CGKeyCode(kVK_ANSI_Period),
		0x002F: CGKeyCode(kVK_ANSI_Slash),

		0x0030: CGKeyCode(kVK_ANSI_0),
		0x0031: CGKeyCode(kVK_ANSI_1),
		0x0032: CGKeyCode(kVK_ANSI_2),
		0x0033: CGKeyCode(kVK_ANSI_3),
		0x0034: CGKeyCode(kVK_ANSI_4),
		0x0035: CGKeyCode(kVK_ANSI_5),
		0x0036: CGKeyCode(kVK_ANSI_6),
		0x0037: CGKeyCode(kVK_ANSI_7),
		0x0038: CGKeyCode(kVK_ANSI_8),
		0x0039: CGKeyCode(kVK_ANSI_9),

		0x0041: CGKeyCode(kVK_ANSI_A),
		0x0042: CGKeyCode(kVK_ANSI_B),
		0x0043: CGKeyCode(kVK_ANSI_C),
		0x0044: CGKeyCode(kVK_ANSI_D),
		0x0045: CGKeyCode(kVK_ANSI_E),
		0x0046: CGKeyCode(kVK_ANSI_F),
		0x0047: CGKeyCode(kVK_ANSI_G),
		0x0048: CGKeyCode(kVK_ANSI_H),
		0x0049: CGKeyCode(kVK_ANSI_I),
		0x004A: CGKeyCode(kVK_ANSI_J),
		0x004B: CGKeyCode(kVK_ANSI_K),
		0x004C: CGKeyCode(kVK_ANSI_L),
		0x004D: CGKeyCode(kVK_ANSI_M),
		0x004E: CGKeyCode(kVK_ANSI_N),
		0x004F: CGKeyCode(kVK_ANSI_O),
		0x0050: CGKeyCode(kVK_ANSI_P),
		0x0051: CGKeyCode(kVK_ANSI_Q),
		0x0052: CGKeyCode(kVK_ANSI_R),
		0x0053: CGKeyCode(kVK_ANSI_S),
		0x0054: CGKeyCode(kVK_ANSI_T),
		0x0055: CGKeyCode(kVK_ANSI_U),
		0x0056: CGKeyCode(kVK_ANSI_V),
		0x0057: CGKeyCode(kVK_ANSI_W),
		0x0058: CGKeyCode(kVK_ANSI_X),
		0x0059: CGKeyCode(kVK_ANSI_Y),
		0x005A: CGKeyCode(kVK_ANSI_Z),

		0x005B: CGKeyCode(kVK_ANSI_LeftBracket),
		0x005C: CGKeyCode(kVK_ANSI_Backslash),
		0x005D: CGKeyCode(kVK_ANSI_RightBracket),
		0x005E: CGKeyCode(kVK_ANSI_Caret),
		0x005F: CGKeyCode(kVK_ANSI_Underscore),
		0x0060: CGKeyCode(kVK_ANSI_Grave),

		0x0061: CGKeyCode(kVK_ANSI_A),
		0x0062: CGKeyCode(kVK_ANSI_B),
		0x0063: CGKeyCode(kVK_ANSI_C),
		0x0064: CGKeyCode(kVK_ANSI_D),
		0x0065: CGKeyCode(kVK_ANSI_E),
		0x0066: CGKeyCode(kVK_ANSI_F),
		0x0067: CGKeyCode(kVK_ANSI_G),
		0x0068: CGKeyCode(kVK_ANSI_H),
		0x0069: CGKeyCode(kVK_ANSI_I),
		0x006A: CGKeyCode(kVK_ANSI_J),
		0x006B: CGKeyCode(kVK_ANSI_K),
		0x006C: CGKeyCode(kVK_ANSI_L),
		0x006D: CGKeyCode(kVK_ANSI_M),
		0x006E: CGKeyCode(kVK_ANSI_N),
		0x006F: CGKeyCode(kVK_ANSI_O),
		0x0070: CGKeyCode(kVK_ANSI_P),
		0x0071: CGKeyCode(kVK_ANSI_Q),
		0x0072: CGKeyCode(kVK_ANSI_R),
		0x0073: CGKeyCode(kVK_ANSI_S),
		0x0074: CGKeyCode(kVK_ANSI_T),
		0x0075: CGKeyCode(kVK_ANSI_U),
		0x0076: CGKeyCode(kVK_ANSI_V),
		0x0077: CGKeyCode(kVK_ANSI_W),
		0x0078: CGKeyCode(kVK_ANSI_X),
		0x0079: CGKeyCode(kVK_ANSI_Y),
		0x007A: CGKeyCode(kVK_ANSI_Z),
		0x007B: CGKeyCode(kVK_ANSI_LeftBracket),
		0x007C: CGKeyCode(kVK_ANSI_Backslash),
		0x007D: CGKeyCode(kVK_ANSI_RightBracket),
		0x007E: CGKeyCode(kVK_ANSI_Grave),
		0x007F: CGKeyCode(kVK_ForwardDelete)
	]

	static let vncSpecialKeyCodeToKeyCodeMapping: [UInt32:CGKeyCode] = [
		0xFFE5: CGKeyCodes.capsLock,
		0xFFE6: CGKeyCodes.capsLock,
		0x1008FF2B: CGKeyCodes.function,

		VNCKeyCode.shift.rawValue: CGKeyCodes.shift,
		VNCKeyCode.rightShift.rawValue: CGKeyCodes.rightShift,

		VNCKeyCode.control.rawValue: CGKeyCodes.control,
		VNCKeyCode.rightControl.rawValue: CGKeyCodes.rightControl,

		VNCKeyCode.option.rawValue: CGKeyCodes.option,
		VNCKeyCode.rightOption.rawValue: CGKeyCodes.rightOption,

		VNCKeyCode.optionForARD.rawValue: CGKeyCodes.option,
		VNCKeyCode.rightOptionForARD.rawValue: CGKeyCodes.rightOption,

		VNCKeyCode.command.rawValue: CGKeyCodes.command,
		VNCKeyCode.rightCommand.rawValue: CGKeyCodes.rightCommand,

		VNCKeyCode.commandForARD.rawValue: CGKeyCodes.command,
		VNCKeyCode.rightCommandForARD.rawValue: CGKeyCodes.rightCommand,

		VNCKeyCode.return.rawValue: CGKeyCodes.return,
		VNCKeyCode.forwardDelete.rawValue: CGKeyCodes.forwardDelete,
		VNCKeyCode.space.rawValue: CGKeyCodes.space,
		VNCKeyCode.delete.rawValue: CGKeyCodes.delete,
		VNCKeyCode.tab.rawValue: CGKeyCodes.tab,
		VNCKeyCode.escape.rawValue: CGKeyCodes.escape,

		VNCKeyCode.leftArrow.rawValue: CGKeyCodes.leftArrow,
		VNCKeyCode.upArrow.rawValue: CGKeyCodes.upArrow,
		VNCKeyCode.rightArrow.rawValue: CGKeyCodes.rightArrow,
		VNCKeyCode.downArrow.rawValue: CGKeyCodes.downArrow,

		VNCKeyCode.pageUp.rawValue: CGKeyCodes.pageUp,
		VNCKeyCode.pageDown.rawValue: CGKeyCodes.pageDown,
		VNCKeyCode.end.rawValue: CGKeyCodes.end,
		VNCKeyCode.home.rawValue: CGKeyCodes.home,
		VNCKeyCode.insert.rawValue: CGKeyCodes.help,

		VNCKeyCode.ansiKeypad0.rawValue: CGKeyCodes.ansiKeypad0,
		VNCKeyCode.ansiKeypad1.rawValue: CGKeyCodes.ansiKeypad1,
		VNCKeyCode.ansiKeypad2.rawValue: CGKeyCodes.ansiKeypad2,
		VNCKeyCode.ansiKeypad3.rawValue: CGKeyCodes.ansiKeypad3,
		VNCKeyCode.ansiKeypad4.rawValue: CGKeyCodes.ansiKeypad4,
		VNCKeyCode.ansiKeypad5.rawValue: CGKeyCodes.ansiKeypad5,
		VNCKeyCode.ansiKeypad6.rawValue: CGKeyCodes.ansiKeypad6,
		VNCKeyCode.ansiKeypad7.rawValue: CGKeyCodes.ansiKeypad7,
		VNCKeyCode.ansiKeypad8.rawValue: CGKeyCodes.ansiKeypad8,
		VNCKeyCode.ansiKeypad9.rawValue: CGKeyCodes.ansiKeypad9,

		VNCKeyCode.ansiKeypadClear.rawValue: CGKeyCodes.ansiKeypadClear,
		VNCKeyCode.ansiKeypadEquals.rawValue: CGKeyCodes.ansiKeypadEquals,
		VNCKeyCode.ansiKeypadDivide.rawValue: CGKeyCodes.ansiKeypadDivide,
		VNCKeyCode.ansiKeypadMultiply.rawValue: CGKeyCodes.ansiKeypadMultiply,
		VNCKeyCode.ansiKeypadMinus.rawValue: CGKeyCodes.ansiKeypadMinus,
		VNCKeyCode.ansiKeypadPlus.rawValue: CGKeyCodes.ansiKeypadPlus,
		VNCKeyCode.ansiKeypadEnter.rawValue: CGKeyCodes.ansiKeypadEnter,
		VNCKeyCode.ansiKeypadDecimal.rawValue: CGKeyCodes.ansiKeypadDecimal,

		VNCKeyCode.f1.rawValue: CGKeyCodes.f1,
		VNCKeyCode.f2.rawValue: CGKeyCodes.f2,
		VNCKeyCode.f3.rawValue: CGKeyCodes.f3,
		VNCKeyCode.f4.rawValue: CGKeyCodes.f4,
		VNCKeyCode.f5.rawValue: CGKeyCodes.f5,
		VNCKeyCode.f6.rawValue: CGKeyCodes.f6,
		VNCKeyCode.f7.rawValue: CGKeyCodes.f7,
		VNCKeyCode.f8.rawValue: CGKeyCodes.f8,
		VNCKeyCode.f9.rawValue: CGKeyCodes.f9,
		VNCKeyCode.f10.rawValue: CGKeyCodes.f10,
		VNCKeyCode.f11.rawValue: CGKeyCodes.f11,
		VNCKeyCode.f12.rawValue: CGKeyCodes.f12,
		VNCKeyCode.f13.rawValue: CGKeyCodes.f13,
		VNCKeyCode.f14.rawValue: CGKeyCodes.f14,
		VNCKeyCode.f15.rawValue: CGKeyCodes.f15,
		VNCKeyCode.f16.rawValue: CGKeyCodes.f16,
		VNCKeyCode.f17.rawValue: CGKeyCodes.f17,
		VNCKeyCode.f18.rawValue: CGKeyCodes.f18,
		VNCKeyCode.f19.rawValue: CGKeyCodes.f19
	]
}

public extension VNCKeyCode {
	static func to(vncKeyCode: UInt32) -> CGKeyCode? {
		return VNCKeyCodeMaps.vncSpecialKeyCodeToKeyCodeMapping[vncKeyCode]
	}
}

public class VNCKeyMapper: Keymapper {
	private var isShiftDown = false
	private var isOptionDown = false
	private var isControlDown = false
	private var isCommandDown = false
	private var isCapsLockDown = false
	private var isNumericPad = false

	static func setupKeyMapper() throws {
		CGKeyCode.Initializers.shared = CGKeyCode.Initializers.init()
	}
	
	func setupKeyMapper() throws {
		try Self.setupKeyMapper()
	}
	
	private func vncKeyCodeTo(vncKeyCode: UInt32) -> (keyCode: CGKeyCode, characters: String?) {
		if let keyCode = VNCKeyCode.to(vncKeyCode: vncKeyCode) {
			return (keyCode, Keysyms.characterForKeysym(vncKeyCode))
		}

		// ASCII printable characters
		if let scalar = UnicodeScalar(vncKeyCode) {
			let characters = String(Character(scalar))

			guard let keyCode = CGKeyCode(character: characters) else {
				Logger(self).debug("Not found: key=\(vncKeyCode.hexa)")

				return (CGKeyCode(vncKeyCode), String(Character(scalar)))
			}

			return (keyCode, String(Character(scalar)))
		} else {
			Logger(self).debug("Not unicode found: key=\(vncKeyCode.hexa)")
		}

		return (CGKeyCode(vncKeyCode), nil)
	}

	func mapVNCKey(_ vncKey: UInt32, isDown: Bool, sendKeyEvent: (CGKeyCode, CGEventFlags, String?) -> Void) {
		let result = self.vncKeyCodeTo(vncKeyCode: vncKey)
		var modifierFlags: CGEventFlags = []

		switch result.keyCode {
		case CGKeyCodes.shift, CGKeyCodes.rightShift:
			self.isShiftDown = isDown
		case CGKeyCodes.control, CGKeyCodes.rightControl:
			self.isControlDown = isDown
		case CGKeyCodes.option, CGKeyCodes.rightOption:
			self.isOptionDown = isDown
		case CGKeyCodes.command, CGKeyCodes.rightCommand:
			self.isCommandDown = isDown
		case CGKeyCodes.capsLock:
			self.isCapsLockDown = isDown
		default:
			break
		}

		if isCommandDown {
			modifierFlags.insert(.maskCommand)
		}

		if isOptionDown {
			modifierFlags.insert(.maskAlternate)
		}

		if isShiftDown {
			modifierFlags.insert(.maskShift)
		}

		if isNumericPad {
			modifierFlags.insert(.maskNumericPad)
		}

		sendKeyEvent(result.keyCode, modifierFlags, result.characters)
	}
}

public class UCVNCKeyMapper: Keymapper {
	// Mapping des touches VNC vers les key codes macOS
	static let vncToMacKeyMap: [UInt32: UInt16] = [
		// Letters
		0x0061: UInt16(kVK_ANSI_A),  // a
		0x0062: UInt16(kVK_ANSI_B),  // b
		0x0063: UInt16(kVK_ANSI_C),  // c
		0x0064: UInt16(kVK_ANSI_D),  // d
		0x0065: UInt16(kVK_ANSI_E),  // e
		0x0066: UInt16(kVK_ANSI_F),  // f
		0x0067: UInt16(kVK_ANSI_G),  // g
		0x0068: UInt16(kVK_ANSI_H),  // h
		0x0069: UInt16(kVK_ANSI_I),  // i
		0x006A: UInt16(kVK_ANSI_J),  // j
		0x006B: UInt16(kVK_ANSI_K),  // k
		0x006C: UInt16(kVK_ANSI_L),  // l
		0x006D: UInt16(kVK_ANSI_M),  // m
		0x006E: UInt16(kVK_ANSI_N),  // n
		0x006F: UInt16(kVK_ANSI_O),  // o
		0x0070: UInt16(kVK_ANSI_P),  // p
		0x0071: UInt16(kVK_ANSI_Q),  // q
		0x0072: UInt16(kVK_ANSI_R),  // r
		0x0073: UInt16(kVK_ANSI_S),  // s
		0x0074: UInt16(kVK_ANSI_T),  // t
		0x0075: UInt16(kVK_ANSI_U),  // u
		0x0076: UInt16(kVK_ANSI_V),  // v
		0x0077: UInt16(kVK_ANSI_W),  // w
		0x0078: UInt16(kVK_ANSI_X),  // x
		0x0079: UInt16(kVK_ANSI_Y),  // y
		0x007A: UInt16(kVK_ANSI_Z),  // z

		// Numbers
		0x0030: UInt16(kVK_ANSI_0),  // 0
		0x0031: UInt16(kVK_ANSI_1),  // 1
		0x0032: UInt16(kVK_ANSI_2),  // 2
		0x0033: UInt16(kVK_ANSI_3),  // 3
		0x0034: UInt16(kVK_ANSI_4),  // 4
		0x0035: UInt16(kVK_ANSI_5),  // 5
		0x0036: UInt16(kVK_ANSI_6),  // 6
		0x0037: UInt16(kVK_ANSI_7),  // 7
		0x0038: UInt16(kVK_ANSI_8),  // 8
		0x0039: UInt16(kVK_ANSI_9),  // 9

		// Special keys
		0xFF08: UInt16(kVK_Delete),  // Backspace
		0xFF09: UInt16(kVK_Tab),  // Tab
		0xFF0D: UInt16(kVK_Return),  // Return
		0xFF1B: UInt16(kVK_Escape),  // Escape
		0x0020: UInt16(kVK_Space),  // Space

		// Function keys
		0xFFBE: UInt16(kVK_F1),  // F1
		0xFFBF: UInt16(kVK_F2),  // F2
		0xFFC0: UInt16(kVK_F3),  // F3
		0xFFC1: UInt16(kVK_F4),  // F4
		0xFFC2: UInt16(kVK_F5),  // F5
		0xFFC3: UInt16(kVK_F6),  // F6
		0xFFC4: UInt16(kVK_F7),  // F7
		0xFFC5: UInt16(kVK_F8),  // F8
		0xFFC6: UInt16(kVK_F9),  // F9
		0xFFC7: UInt16(kVK_F10),  // F10
		0xFFC8: UInt16(kVK_F11),  // F11
		0xFFC9: UInt16(kVK_F12),  // F12
		0xFFCA: UInt16(kVK_F13),  // F13
		0xFFCB: UInt16(kVK_F14),  // F13
		0xFFCC: UInt16(kVK_F15),  // F13

		// Arrows
		0xFF51: UInt16(kVK_LeftArrow),  // Left
		0xFF52: UInt16(kVK_UpArrow),  // Up
		0xFF53: UInt16(kVK_RightArrow),  // Right
		0xFF54: UInt16(kVK_DownArrow),  // Down

		// Navigation keys
		0xFF50: UInt16(kVK_Home),  // Home
		0xFF57: UInt16(kVK_End),  // End
		0xFF55: UInt16(kVK_PageUp),  // Page Up
		0xFF56: UInt16(kVK_PageDown),  // Page Down

		// Numeric keypad
		0xFF9C: UInt16(kVK_ANSI_Keypad0),  // Keypad 0
		0xFF9D: UInt16(kVK_ANSI_Keypad1),  // Keypad 1
		0xFF9E: UInt16(kVK_ANSI_Keypad2),  // Keypad 2
		0xFF9F: UInt16(kVK_ANSI_Keypad3),  // Keypad 3
		0xFFA0: UInt16(kVK_ANSI_Keypad4),  // Keypad 4
		0xFFA1: UInt16(kVK_ANSI_Keypad5),  // Keypad 5
		0xFFA2: UInt16(kVK_ANSI_Keypad6),  // Keypad 6
		0xFFA3: UInt16(kVK_ANSI_Keypad7),  // Keypad 7
		0xFFA4: UInt16(kVK_ANSI_Keypad8),  // Keypad 8
		0xFFA5: UInt16(kVK_ANSI_Keypad9),  // Keypad 9

		// Numeric keypad
		0xFFB0: UInt16(kVK_ANSI_Keypad0),  // Keypad 0
		0xFFB1: UInt16(kVK_ANSI_Keypad1),  // Keypad 1
		0xFFB2: UInt16(kVK_ANSI_Keypad2),  // Keypad 2
		0xFFB3: UInt16(kVK_ANSI_Keypad3),  // Keypad 3
		0xFFB4: UInt16(kVK_ANSI_Keypad4),  // Keypad 4
		0xFFB5: UInt16(kVK_ANSI_Keypad5),  // Keypad 5
		0xFFB6: UInt16(kVK_ANSI_Keypad6),  // Keypad 6
		0xFFB7: UInt16(kVK_ANSI_Keypad7),  // Keypad 7
		0xFFB8: UInt16(kVK_ANSI_Keypad8),  // Keypad 8
		0xFFB9: UInt16(kVK_ANSI_Keypad9),  // Keypad 9

		0xFF8D: UInt16(kVK_ANSI_KeypadEnter),  // Keypad enter
		0xFFAA: UInt16(kVK_ANSI_KeypadMultiply),  // Keypad *
		0xFFAB: UInt16(kVK_ANSI_KeypadPlus),  // Keypad 9
		0xFFAD: UInt16(kVK_ANSI_KeypadPlus),  // Keypad -
		0xFFAE: UInt16(kVK_ANSI_KeypadDecimal),  // Keypad .
		0xFFAF: UInt16(kVK_ANSI_KeypadDivide),  // Keypad /
		0xFFBD: UInt16(kVK_ANSI_KeypadEquals),  // Keypad =

		// Punctuation
		0x002E: UInt16(kVK_ANSI_Period),  // .
		0x002C: UInt16(kVK_ANSI_Comma),  // ,
		0x003B: UInt16(kVK_ANSI_Semicolon),  // ;
		0x0027: UInt16(kVK_ANSI_Quote),  // '
		0x005B: UInt16(kVK_ANSI_LeftBracket),  // [
		0x005D: UInt16(kVK_ANSI_RightBracket),  // ]
		0x005C: UInt16(kVK_ANSI_Backslash),  // \
		0x002F: UInt16(kVK_ANSI_Slash),  // /
		0x002D: UInt16(kVK_ANSI_Minus),  // -
		0x003D: UInt16(kVK_ANSI_Equal),  // =
		0x0060: UInt16(kVK_ANSI_Grave),  // `
	]

	// Mapping des modificateurs VNC vers NSEvent.ModifierFlags
	static let vncModifiers: [UInt32: NSEvent.ModifierFlags] = [
		0xFF0B: .numericPad,
		0xFFE1: .shift,  // Left Shift
		0xFFE2: .shift,  // Right Shift
		0xFFE3: .control,  // Left Control
		0xFFE4: .control,  // Right Control
		0xFFE5: .capsLock,  // Shift lock
		0xFFE6: .capsLock,  // Left Shift
		0xFFE7: .option,  // Left Meta
		0xFFE8: .option,  // Right Meta
		0xFFE9: .option,  // Left Alt
		0xFFEA: .option,  // Right Alt
		0xFFEB: .command,  // Left Command
		0xFFEC: .command,  // Right Command
		0x1008FF2B: .function
	]

	private static var charKeyMap: [UniChar: UniChar] = [:]
	private static var charShiftKeyMap : [UniChar: UniChar] = [:]
	private static var charControlKeyMap : [UniChar: UniChar] = [:]
	private static var charOptionKeyMap : [UniChar: UniChar] = [:]
	private static var charShiftOptionKeyMap: [UniChar: UniChar] = [:]
	private static var keymapInitialized: Bool = false

	private var isShiftDown = false
	private var isOptionDown = false
	private var isControlDown = false
	private var isCommandDown = false
	private var isCapsLockDown = false
	private var isNumericPad = false

	static func setupKeyMapper() throws {
		guard keymapInitialized == false else {
			return
		}

		keymapInitialized = true

		if let currentKeyboardUnmanaged = TISCopyCurrentKeyboardInputSource() {
			let currentKeyboard = currentKeyboardUnmanaged.retain()
			let inputSource = currentKeyboard.takeUnretainedValue()

			if let keyboardLayoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) {
				let layoutData = Unmanaged<CFData>.fromOpaque(keyboardLayoutData).takeUnretainedValue() as Data

				layoutData.withUnsafeBytes { rawBuffer in
					guard let baseAddress = rawBuffer.baseAddress else { return }
					let keyboardLayout = baseAddress.assumingMemoryBound(to: UCKeyboardLayout.self)

					let modifiers: [UInt64] = [
						0,
						CGEventFlags.maskShift.rawValue,
						CGEventFlags.maskAlternate.rawValue,
						CGEventFlags.maskShift.rawValue | CGEventFlags.maskAlternate.rawValue
					]

					for i: UInt16 in 0..<128 {
						var deadKeyState: UInt32 = 0

						for m in 0..<modifiers.count {
							var chars: [UniChar] = [0, 0, 0, 0]
							var realLength: Int = 0
							let currentModifier = modifiers[m]

							UCKeyTranslate(keyboardLayout,
										   i,
										   UInt16(kUCKeyActionDisplay),
										   UInt32(currentModifier) & 0x00FF,
										   UInt32(LMGetKbdType()),
										   UInt32(kUCKeyTranslateNoDeadKeysBit),
										   &deadKeyState,
										   chars.count,
										   &realLength,
										   &chars)

							switch currentModifier {
							case 0:
								charKeyMap[chars[0]] = i
							case CGEventFlags.maskShift.rawValue:
								charShiftKeyMap[chars[0]] = i
							case CGEventFlags.maskAlternate.rawValue:
								charOptionKeyMap[chars[0]] = i
							case CGEventFlags.maskShift.rawValue | CGEventFlags.maskAlternate.rawValue:
								charShiftOptionKeyMap[chars[0]] = i
							default:
								break
							}
						}
					}
				}
			} else {
				throw ServiceError("Unable to init VNKeyMapper: no keyboard layout data")
			}

		} else {
			throw ServiceError("Unable to init VNKeyMapper: no keyboard")
		}
	}

	func setupKeyMapper() throws {
		try Self.setupKeyMapper()
	}
	
	var modifierFlags: CGEventFlags {
		var modifierFlags: CGEventFlags = []

		if isCommandDown {
			modifierFlags.insert(.maskCommand)
		}

		if isOptionDown {
			modifierFlags.insert(.maskAlternate)
		}

		if isShiftDown {
			modifierFlags.insert(.maskShift)
		}

		if isControlDown {
			modifierFlags.insert(.maskControl)
		}

		if isNumericPad {
			modifierFlags.insert(.maskNumericPad)
		}

		return modifierFlags
	}

	func mapVNCKey(_ vncKey: UInt32, isDown: Bool, sendKeyEvent: (CGKeyCode, CGEventFlags, String?) -> Void) {
		// Check if it's a modifier
		if let modifier = Self.vncModifiers[vncKey] {
			let keyCode = Self.vncToMacKeyMap[vncKey] ?? 0

			if modifier == .shift {
				self.isShiftDown = isDown
			}
			if modifier == .control {
				self.isControlDown = isDown
			}

			if modifier == .option {
				self.isOptionDown = isDown
			}

			if modifier == .command {
				self.isCommandDown = isDown
			}

			if modifier == .numericPad && isDown == false {
				isNumericPad.toggle()
			}

			sendKeyEvent(keyCode, self.modifierFlags, nil)
		} else {
			var keyMap = Self.charKeyMap
			
			if isShiftDown {
				keyMap = Self.charShiftKeyMap;
			}
			
			if (!isShiftDown && isOptionDown) {
				keyMap = Self.charOptionKeyMap
			}
			
			if (isShiftDown && isOptionDown) {
				keyMap = Self.charShiftOptionKeyMap
			}
			
			if let keyCode = keyMap[UInt16(vncKey)] {
				sendKeyEvent(keyCode, self.modifierFlags, Keysyms.characterForKeysym(vncKey))
			} else {
				let keyCode = Self.vncToMacKeyMap[vncKey] ?? 0
				
				Logger(self).debug("Not found: key=\(vncKey.hexa), keyCode=\(keyCode)")
				
				sendKeyEvent(keyCode, self.modifierFlags, Keysyms.characterForKeysym(vncKey))
			}
		}
	}
}

class OSXVNCKeyMapper: Keymapper {
	static let keyTableSize = 65536
	static let USKeyCodes = [
		/* The alphabet */
		Keysyms.XK_A,                  0,      /* A */
		Keysyms.XK_B,                 11,      /* B */
		Keysyms.XK_C,                  8,      /* C */
		Keysyms.XK_D,                  2,      /* D */
		Keysyms.XK_E,                 14,      /* E */
		Keysyms.XK_F,                  3,      /* F */
		Keysyms.XK_G,                  5,      /* G */
		Keysyms.XK_H,                  4,      /* H */
		Keysyms.XK_I,                 34,      /* I */
		Keysyms.XK_J,                 38,      /* J */
		Keysyms.XK_K,                 40,      /* K */
		Keysyms.XK_L,                 37,      /* L */
		Keysyms.XK_M,                 46,      /* M */
		Keysyms.XK_N,                 45,      /* N */
		Keysyms.XK_O,                 31,      /* O */
		Keysyms.XK_P,                 35,      /* P */
		Keysyms.XK_Q,                 12,      /* Q */
		Keysyms.XK_R,                 15,      /* R */
		Keysyms.XK_S,                  1,      /* S */
		Keysyms.XK_T,                 17,      /* T */
		Keysyms.XK_U,                 32,      /* U */
		Keysyms.XK_V,                  9,      /* V */
		Keysyms.XK_W,                 13,      /* W */
		Keysyms.XK_X,                  7,      /* X */
		Keysyms.XK_Y,                 16,      /* Y */
		Keysyms.XK_Z,                  6,      /* Z */
		Keysyms.XK_a,                  0,      /* a */
		Keysyms.XK_b,                 11,      /* b */
		Keysyms.XK_c,                  8,      /* c */
		Keysyms.XK_d,                  2,      /* d */
		Keysyms.XK_e,                 14,      /* e */
		Keysyms.XK_f,                  3,      /* f */
		Keysyms.XK_g,                  5,      /* g */
		Keysyms.XK_h,                  4,      /* h */
		Keysyms.XK_i,                 34,      /* i */
		Keysyms.XK_j,                 38,      /* j */
		Keysyms.XK_k,                 40,      /* k */
		Keysyms.XK_l,                 37,      /* l */
		Keysyms.XK_m,                 46,      /* m */
		Keysyms.XK_n,                 45,      /* n */
		Keysyms.XK_o,                 31,      /* o */
		Keysyms.XK_p,                 35,      /* p */
		Keysyms.XK_q,                 12,      /* q */
		Keysyms.XK_r,                 15,      /* r */
		Keysyms.XK_s,                  1,      /* s */
		Keysyms.XK_t,                 17,      /* t */
		Keysyms.XK_u,                 32,      /* u */
		Keysyms.XK_v,                  9,      /* v */
		Keysyms.XK_w,                 13,      /* w */
		Keysyms.XK_x,                  7,      /* x */
		Keysyms.XK_y,                 16,      /* y */
		Keysyms.XK_z,                  6,      /* z */

		/* Numbers */
		Keysyms.XK_0,                 29,      /* 0 */
		Keysyms.XK_1,                 18,      /* 1 */
		Keysyms.XK_2,                 19,      /* 2 */
		Keysyms.XK_3,                 20,      /* 3 */
		Keysyms.XK_4,                 21,      /* 4 */
		Keysyms.XK_5,                 23,      /* 5 */
		Keysyms.XK_6,                 22,      /* 6 */
		Keysyms.XK_7,                 26,      /* 7 */
		Keysyms.XK_8,                 28,      /* 8 */
		Keysyms.XK_9,                 25,      /* 9 */

		/* Symbols */
		Keysyms.XK_exclam,            18,      /* ! */
		Keysyms.XK_at,                19,      /* @ */
		Keysyms.XK_numbersign,        20,      /* # */
		Keysyms.XK_dollar,            21,      /* $ */
		Keysyms.XK_percent,           23,      /* % */
		Keysyms.XK_asciicircum,       22,      /* ^ */
		Keysyms.XK_ampersand,         26,      /* & */
		Keysyms.XK_asterisk,          28,      /* * */
		Keysyms.XK_parenleft,         25,      /* ( */
		Keysyms.XK_parenright,        29,      /* ) */
		Keysyms.XK_minus,             27,      /* - */
		Keysyms.XK_underscore,        27,      /* _ */
		Keysyms.XK_equal,             24,      /* = */
		Keysyms.XK_plus,              24,      /* + */
		Keysyms.XK_grave,             50,      /* ` */  /* XXX ? */
		Keysyms.XK_asciitilde,        50,      /* ~ */
		Keysyms.XK_bracketleft,       33,      /* [ */
		Keysyms.XK_braceleft,         33,      /* { */
		Keysyms.XK_bracketright,      30,      /* ] */
		Keysyms.XK_braceright,        30,      /* } */
		Keysyms.XK_semicolon,         41,      /* ; */
		Keysyms.XK_colon,             41,      /* : */
		Keysyms.XK_apostrophe,        39,      /* ' */
		Keysyms.XK_quotedbl,          39,      /* " */
		Keysyms.XK_comma,             43,      /* , */
		Keysyms.XK_less,              43,      /* < */
		Keysyms.XK_period,            47,      /* . */
		Keysyms.XK_greater,           47,      /* > */
		Keysyms.XK_slash,             44,      /* / */
		Keysyms.XK_question,          44,      /* ? */
		Keysyms.XK_backslash,         42,      /* \ */
		Keysyms.XK_bar,               42,      /* | */
		// OS X Sends this (END OF MEDIUM) for Shift-Tab (with US Keyboard)
		0x0019,                       48,      /* Tab */
		Keysyms.XK_space,             49,      /* Space */
	]

	static let SpecialKeyCodes = [
		/* "Special" keys */
		Keysyms.XK_Return,            36,      /* Return */
		Keysyms.XK_Delete,           117,      /* Delete */
		Keysyms.XK_Tab,               48,      /* Tab */
		Keysyms.XK_Escape,            53,      /* Esc */
		Keysyms.XK_Caps_Lock,         57,      /* Caps Lock */
		Keysyms.XK_Num_Lock,          71,      /* Num Lock */
		Keysyms.XK_Scroll_Lock,      107,      /* Scroll Lock */
		Keysyms.XK_Pause,            113,      /* Pause */
		Keysyms.XK_BackSpace,         51,      /* Backspace */
		Keysyms.XK_Insert,           114,      /* Insert */

		/* Cursor movement */
		Keysyms.XK_Up,               126,      /* Cursor Up */
		Keysyms.XK_Down,             125,      /* Cursor Down */
		Keysyms.XK_Left,             123,      /* Cursor Left */
		Keysyms.XK_Right,            124,      /* Cursor Right */
		Keysyms.XK_Page_Up,          116,      /* Page Up */
		Keysyms.XK_Page_Down,        121,      /* Page Down */
		Keysyms.XK_Home,             115,      /* Home */
		Keysyms.XK_End,              119,      /* End */

		/* Numeric keypad */
		Keysyms.XK_KP_0,              82,      /* KP 0 */
		Keysyms.XK_KP_1,              83,      /* KP 1 */
		Keysyms.XK_KP_2,              84,      /* KP 2 */
		Keysyms.XK_KP_3,              85,      /* KP 3 */
		Keysyms.XK_KP_4,              86,      /* KP 4 */
		Keysyms.XK_KP_5,              87,      /* KP 5 */
		Keysyms.XK_KP_6,              88,      /* KP 6 */
		Keysyms.XK_KP_7,              89,      /* KP 7 */
		Keysyms.XK_KP_8,              91,      /* KP 8 */
		Keysyms.XK_KP_9,              92,      /* KP 9 */
		Keysyms.XK_KP_Enter,          76,      /* KP Enter */
		Keysyms.XK_KP_Decimal,        65,      /* KP . */
		Keysyms.XK_KP_Add,            69,      /* KP + */
		Keysyms.XK_KP_Subtract,       78,      /* KP - */
		Keysyms.XK_KP_Multiply,       67,      /* KP * */
		Keysyms.XK_KP_Divide,         75,      /* KP / */
		Keysyms.XK_KP_Equal,		  81,      /* KP = */

		/* Function keys */
		Keysyms.XK_F1,               122,      /* F1 */
		Keysyms.XK_F2,               120,      /* F2 */
		Keysyms.XK_F3,                99,      /* F3 */
		Keysyms.XK_F4,               118,      /* F4 */
		Keysyms.XK_F5,                96,      /* F5 */
		Keysyms.XK_F6,                97,      /* F6 */
		Keysyms.XK_F7,                98,      /* F7 */
		Keysyms.XK_F8,               100,      /* F8 */
		Keysyms.XK_F9,               101,      /* F9 */
		Keysyms.XK_F10,              109,      /* F10 */
		Keysyms.XK_F11,              103,      /* F11 */
		Keysyms.XK_F12,              111,      /* F12 */
		Keysyms.XK_F13,              105,      /* F12 */
		Keysyms.XK_F14,              107,      /* F12 */
		Keysyms.XK_F15,              113,      /* F12 */
		Keysyms.XK_F16,              106,      /* F12 */
		Keysyms.XK_F17,              64,      /* F12 */
		Keysyms.XK_F18,              79,      /* F12 */
		Keysyms.XK_F19,              80,      /* F12 */
		Keysyms.XK_F20,              90,      /* F12 */

		/* Modifier keys */
		Keysyms.XK_Alt_L,             55,      /* Alt Left (-> Command) */
		Keysyms.XK_Alt_R,             55,      /* Alt Right (-> Command) */
		Keysyms.XK_Shift_L,           56,      /* Shift Left */
		Keysyms.XK_Shift_R,           56,      /* Shift Right */
		Keysyms.XK_Meta_L,            58,      /* Option Left (-> Option) */
		Keysyms.XK_Meta_R,            58,      /* Option Right (-> Option) */
		Keysyms.XK_Super_L,           58,      /* Option Left (-> Option) */
		Keysyms.XK_Super_R,           58,      /* Option Right (-> Option) */
		Keysyms.XK_Control_L,         59,      /* Ctrl Left */
		Keysyms.XK_Control_R,         59,      /* Ctrl Right */
	]

	static var keyTable: [CGKeyCode] = Array<CGKeyCode>(repeating: 0, count: keyTableSize)
	static var keyTableMods: [UInt8] = Array<UInt8>(repeating: 0, count: keyTableSize)
	static var keymapInitialized: Bool = false

	static var keyCodeShift: CGKeyCode = 0
	static var keyCodeOption: CGKeyCode = 0
	static var keyCodeControl: CGKeyCode = 0
	static var keyCodeCommand: CGKeyCode = 0
	static var keyNumericPadCommand: CGKeyCode = 0
	static var keyFunctionCommand: CGKeyCode = 0

	var currentModifiers: CGEventFlags = []
	var unicodeInputSource: Unmanaged<TISInputSource>! = nil
	var currentInputSource: Unmanaged<TISInputSource>! = TISCopyCurrentKeyboardInputSource()
	var modiferKeys = Array<Bool>(repeating: false, count: 256)
	var modifierDelay: Int = 5000
	var pressModsForKeys = false

	static func setupKeyMapper() {
		var i = 0
		guard keymapInitialized == false else {
			return
		}
		
		keymapInitialized = true

		while i < Self.USKeyCodes.count {
			keyTable[Int(Self.USKeyCodes[i])] = CGKeyCode(Self.USKeyCodes[i + 1])
			i += 2
		}
		
		i = 0

		while i < Self.SpecialKeyCodes.count {
			keyTable[Int(Self.SpecialKeyCodes[i])] = CGKeyCode(Self.SpecialKeyCodes[i + 1])
			i += 2
		}

		self.keyCodeShift = keyTable[Int(Keysyms.XK_Shift_L)]
		self.keyCodeOption = keyTable[Int(Keysyms.XK_Meta_L)]
		self.keyCodeControl = keyTable[Int(Keysyms.XK_Control_L)]
		self.keyCodeCommand = keyTable[Int(Keysyms.XK_Alt_L)]
	}

	func setupKeyMapper() throws {
		Self.setupKeyMapper()
	}

	func mapVNCKey(_ vncKey: UInt32, isDown: Bool, sendKeyEvent: (CGKeyCode, CGEventFlags, String?) -> Void) {
		let keyCode = UInt16(Self.keyTable[Int(vncKey)])
		let characters = Keysyms.characterForKeysym(vncKey)

		if keyCode == 0xFFFF {
			Logger(self).debug("keyCode not found: \(vncKey)")
		} else {
			let isModifierKey = (Keysyms.XK_Shift_L <= vncKey && vncKey <= Keysyms.XK_Hyper_R)

			self.modiferKeys[Int(keyCode)] = isDown;

			if isModifierKey {
				// Record them in our "currentModifiers"
				switch (vncKey) {
				case Keysyms.XK_Shift_L, Keysyms.XK_Shift_R:
					if (isDown) {
						currentModifiers.insert(.maskShift)
					} else {
						currentModifiers.remove(.maskShift)
					}
				case Keysyms.XK_Control_L, Keysyms.XK_Control_R:
					if (isDown) {
						currentModifiers.insert(.maskControl)
					} else {
						currentModifiers.remove(.maskControl)
					}
				case Keysyms.XK_Meta_L, Keysyms.XK_Meta_R:
					if (isDown) {
						currentModifiers.insert(.maskAlternate)
					} else {
						currentModifiers.remove(.maskAlternate)
					}
				case Keysyms.XK_Alt_L, Keysyms.XK_Alt_R:
					if (isDown) {
						currentModifiers.insert(.maskCommand)
					} else {
						currentModifiers.remove(.maskCommand)
					}
				default:
					break
				}

				sendKeyEvent(keyCode, currentModifiers, nil)
			} else {
				var modifiersToSend: CGEventFlags = [.maskNonCoalesced]
				
				if self.modiferKeys[Int(Self.keyCodeShift)] {
					modifiersToSend.insert(.maskShift)
				}

				if self.modiferKeys[Int(Self.keyCodeControl)] {
					modifiersToSend.insert(.maskControl)
				}

				if self.modiferKeys[Int(Self.keyCodeOption)] {
					modifiersToSend.insert(.maskAlternate)
				}

				if self.modiferKeys[Int(Self.keyCodeCommand)] {
					modifiersToSend.insert(.maskCommand)
				}

				if self.modiferKeys[Int(Self.keyNumericPadCommand)] {
					modifiersToSend.insert(.maskNumericPad)
				}

				if self.modiferKeys[Int(Self.keyFunctionCommand)] {
					modifiersToSend.insert(.maskSecondaryFn)
				}

				sendKeyEvent(keyCode, modifiersToSend, characters)
			}
		}
	}
}
