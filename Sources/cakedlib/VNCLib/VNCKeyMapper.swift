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
	
	private struct Initializers {
		let specialKeys: [NSEvent.SpecialKey:CGKeyCode]
		let characterKeys: [String:CGKeyCode]
		let modifierFlagKeys: [NSEvent.ModifierFlags:CGKeyCode]

		static let shared = Initializers()
		
		init() {
			var specialKeys = [NSEvent.SpecialKey:CGKeyCode]()
			var characterKeys = [String:CGKeyCode]()
			var modifierFlagKeys = [NSEvent.ModifierFlags:CGKeyCode]()

			for keyCode in (0..<128).map({ CGKeyCode($0) }) {
				let eventSource = CGEventSource(stateID: .privateState);
				guard let cgevent = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(keyCode), keyDown: true) else { continue }
				guard let nsevent = NSEvent(cgEvent: cgevent) else { continue }

				var hasHandledKeyCode = false

				if nsevent.type == .keyDown {
					if let specialKey = nsevent.specialKey {
						hasHandledKeyCode = true
						specialKeys[specialKey] = keyCode
					} else if let characters = nsevent.charactersIgnoringModifiers, !characters.isEmpty && characters != "\u{0010}" {
						hasHandledKeyCode = true
						characterKeys[characters] = keyCode
					}
				} else if nsevent.type == .flagsChanged, let modifierFlag = nsevent.modifierFlags.first(.capsLock, .shift, .control, .option, .command, .help, .function) {
					hasHandledKeyCode = true
					modifierFlagKeys[modifierFlag] = keyCode
				}

				if !hasHandledKeyCode {
					#if DEBUG
					print("Unhandled keycode \(keyCode): \(nsevent)")
					#endif
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

public class VNCKeyMapper {
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

	func characterForVNCKey(_ vncKey: UInt32) -> String {
		// Convert VNC codes to characters
		if vncKey >= 0x20 && vncKey <= 0x7E {
			// ASCII printable characters
			if let scalar = UnicodeScalar(vncKey) {
				return String(Character(scalar))
			}
		}

		// Special characters
		switch vncKey {
		case 0xFF08: return "\u{8}"  // Backspace
		case 0xFF09: return "\t"  // Tab
		case 0xFF0D: return "\r"  // Return
		case 0xFF1B: return "\u{1B}"  // Escape
		case 0x0020: return " "  // Space
		default:
			if let scalar = UnicodeScalar(vncKey) {
				return String(Character(scalar))
			} else {
				return ""
			}
		}
	}

	func vncKeyCodeTo(vncKeyCode: UInt32) -> (keyCode: CGKeyCode, characters: String) {
		if let keyCode = VNCKeyCode.to(vncKeyCode: vncKeyCode) {
			return (keyCode, characterForVNCKey(vncKeyCode))
		}

		// ASCII printable characters
		if let scalar = UnicodeScalar(vncKeyCode) {
			/*var keyMap = Self.charKeyMap

			if isShiftDown {
				keyMap = Self.charShiftKeyMap;
			}

			if (!isShiftDown && isOptionDown) {
				keyMap = Self.charOptionKeyMap
			}

			if (isShiftDown && isOptionDown) {
				keyMap = Self.charShiftOptionKeyMap
			}*/

			let characters = String(Character(scalar))

			guard let keyCode = CGKeyCode(character: characters) else {
				Logger(self).debug("Not found: key=\(vncKeyCode.hexa)")

				return (CGKeyCode(vncKeyCode), String(Character(scalar)))
			}

			return (keyCode, String(Character(scalar)))
		} else {
			Logger(self).debug("Not unicode found: key=\(vncKeyCode.hexa)")
		}

		return (CGKeyCode(vncKeyCode), "¿")
	}

	func mapVNCKey(_ vncKey: UInt32, isDown: Bool) -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String) {
		let result = self.vncKeyCodeTo(vncKeyCode: vncKey)
		var modifierFlags: NSEvent.ModifierFlags = []

		switch result.keyCode {
		case CGKeyCodes.shift, CGKeyCodes.rightShift:
			self.isShiftDown = isDown
		case CGKeyCodes.control, CGKeyCodes.rightControl:
			self.isControlDown = isDown
		case CGKeyCodes.option, CGKeyCodes.rightOption:
			self.isOptionDown = isDown
		case CGKeyCodes.command, CGKeyCodes.rightCommand:
			self.isCommandDown = isDown
		default:
			break
		}

		if isCommandDown {
			modifierFlags.insert(.command)
		}

		if isOptionDown {
			modifierFlags.insert(.option)
		}

		if isShiftDown {
			modifierFlags.insert(.shift)
		}

		if isCommandDown {
			modifierFlags.insert(.control)
		}

		if isNumericPad {
			modifierFlags.insert(.numericPad)
		}

		return (result.keyCode, modifierFlags, result.characters)
	}
}

