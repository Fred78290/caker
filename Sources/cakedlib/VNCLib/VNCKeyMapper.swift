import AppKit
import Carbon
import Foundation
import RoyalVNCKit

let kVK_ANSI_Exclam = kVK_ANSI_1
let kVK_ANSI_Number = kVK_ANSI_3
let kVK_ANSI_Dollar = kVK_ANSI_4
let kVK_ANSI_Percent = kVK_ANSI_5
let kVK_ANSI_Ampersand = kVK_ANSI_7
let kVK_ANSI_LeftParen = kVK_ANSI_9
let kVK_ANSI_RightParen = kVK_ANSI_0
let kVK_ANSI_Asterisk = kVK_ANSI_8
let kVK_ANSI_Plus = kVK_ANSI_Equal
let kVK_ANSI_Caret = kVK_ANSI_6
let kVK_ANSI_Underscore = kVK_ANSI_Minus

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

typealias HandleKeyMapping = (_ keyCode: CGKeyCode, _ event: NSEvent.ModifierFlags, _ characters: String?, _ charactersIgnoringModifiers: String?) -> Void

protocol Keymapper {
	func setupKeyMapper() throws
	func mapVNCKey(_ vncKey: UInt32, isDown: Bool, sendKeyEvent: HandleKeyMapping)
}

func newKeyMapper() -> Keymapper {
	VNCKeyMapper()
}

extension CGEventFlags {
	var appKitFlags: NSEvent.ModifierFlags {
		var flags: NSEvent.ModifierFlags = []

		if contains(.maskControl) { flags.insert(.control) }
		if contains(.maskShift) { flags.insert(.shift) }
		if contains(.maskAlternate) { flags.insert(.option) }
		if contains(.maskControl) { flags.insert(.control) }
		if contains(.maskNumericPad) { flags.insert(.numericPad) }
		if contains(.maskSecondaryFn) { flags.insert(.function) }
		if contains(.maskHelp) { flags.insert(.help) }

		return flags
	}
}

extension NSEvent.ModifierFlags {
	var cgEventFlag: CGEventFlags {
		var flags: CGEventFlags = []
		
		if self.contains(.command) || self.contains(.leftCommand) || self.contains(.rightCommand) {
			flags.insert(.maskCommand)
		}

		if self.contains(.control) || self.contains(.leftControl) || self.contains(.rightControl) {
			flags.insert(.maskControl)
		}

		if self.contains(.option) || self.contains(.leftOption) || self.contains(.rightOption) {
			flags.insert(.maskAlternate)
		}

		if self.contains(.numericPad) {
			flags.insert(.maskNumericPad)
		}

		if self.contains(.function) {
			flags.insert(.maskSecondaryFn)
		}

		if self.contains(.help) {
			flags.insert(.maskHelp)
		}

		return flags
	}

	var keysym: UInt32? {
		if self.contains(.rightCommand) {
			return Keysyms.XK_Alt_R
		}
		
		if self.contains(.rightOption) {
			return Keysyms.XK_Meta_R
		}

		if self.contains(.leftCommand) {
			return Keysyms.XK_Alt_L
		}
		
		if self.contains(.rightControl) {
			return Keysyms.XK_Control_R
		}

		if self.contains(.rightShift) {
			return Keysyms.XK_Shift_R
		}

		if self.contains(.leftOption) {
			return Keysyms.XK_Meta_L
		}
		
		if self.contains(.leftControl) {
			return Keysyms.XK_Control_L
		}
		
		if self.contains(.leftShift) {
			return Keysyms.XK_Shift_L
		}

		if self.contains(.capsLock) {
			return Keysyms.XK_Caps_Lock
		}

		if self.contains(.function) {
			return Keysyms.XK_function
		}

		return nil
	}
}

extension NSEvent.SpecialKey {
	var keysym: UInt32? {
		switch self {
		case .backTab: return Keysyms.XK_3270_BackTab
		case .backspace: return Keysyms.XK_BackSpace
		case .begin: return Keysyms.XK_Begin
		case .break: return Keysyms.XK_Break
		case .carriageReturn: return Keysyms.XK_Return
		case .clearDisplay: return Keysyms.XK_Clear
		//case .clearLine: return Keysyms.XK_Clear
		case .delete: return Keysyms.XK_BackSpace
		//case .deleteCharacter: return Keysyms.XK_Delete
		case .deleteForward: return Keysyms.XK_Delete
		//case .deleteLine: return Keysyms.XK_Delete
		case .downArrow: return Keysyms.XK_Down
		case .end: return Keysyms.XK_End
		case .enter: return Keysyms.XK_KP_Enter
		case .execute: return Keysyms.XK_Execute
		case .f1: return Keysyms.XK_F1
		case .f2: return Keysyms.XK_F2
		case .f3: return Keysyms.XK_F3
		case .f4: return Keysyms.XK_F4
		case .f5: return Keysyms.XK_F5
		case .f6: return Keysyms.XK_F6
		case .f7: return Keysyms.XK_F7
		case .f8: return Keysyms.XK_F8
		case .f9: return Keysyms.XK_F9
		case .f10: return Keysyms.XK_F10
		case .f11: return Keysyms.XK_F11
		case .f12: return Keysyms.XK_F12
		case .f13: return Keysyms.XK_F13
		case .f14: return Keysyms.XK_F14
		case .f15: return Keysyms.XK_F15
		case .f16: return Keysyms.XK_F16
		case .f17: return Keysyms.XK_F17
		case .f18: return Keysyms.XK_F18
		case .f19: return Keysyms.XK_F19
		case .f20: return Keysyms.XK_F20
		case .f21: return Keysyms.XK_F21
		case .f22: return Keysyms.XK_F22
		case .f23: return Keysyms.XK_F23
		case .f24: return Keysyms.XK_F24
		case .f25: return Keysyms.XK_F25
		case .f26: return Keysyms.XK_F26
		case .f27: return Keysyms.XK_F27
		case .f28: return Keysyms.XK_F28
		case .f29: return Keysyms.XK_F29
		case .f30: return Keysyms.XK_F30
		case .f31: return Keysyms.XK_F31
		case .f32: return Keysyms.XK_F32
		case .f33: return Keysyms.XK_F33
		case .f34: return Keysyms.XK_F34
		case .f35: return Keysyms.XK_F35
		case .find: return Keysyms.XK_Find
		//case .formFeed: return Keysyms.XK_Return
		case .help: return Keysyms.XK_Help
		case .home: return Keysyms.XK_Home
		case .insert:	return Keysyms.XK_Insert
		//case .insertLine: return Keysyms.XK_Insert
		//case .insertCharacter: :KeysymsXK_Insert
		case .leftArrow: return Keysyms.XK_Left
		case .lineSeparator: return Keysyms.XK_Linefeed
		case .menu: return Keysyms.XK_Return
		case .modeSwitch: return Keysyms.XK_Mode_switch
		case .newline: return Keysyms.XK_Return
		case .next: return Keysyms.XK_Next
		case .pageDown: return Keysyms.XK_Page_Down
		case .pageUp: return Keysyms.XK_Page_Up
		case .pause: return Keysyms.XK_Pause
		case .prev: return Keysyms.XK_PreviousCandidate
		case .print: return Keysyms.XK_Print
		case .printScreen: return Keysyms.XK_3270_PrintScreen
		case .paragraphSeparator: return Keysyms.XK_paragraph
		case .redo: return Keysyms.XK_Redo
		case .reset: return Keysyms.XK_3270_Reset
		case .rightArrow: return Keysyms.XK_Right
		case .scrollLock: return Keysyms.XK_Scroll_Lock
		case .stop: return Keysyms.XK_Cancel
		case .select: return Keysyms.XK_Select
		case .sysReq: return Keysyms.XK_Sys_Req
		//case .system: :KeysymsXK_Sys_Req
		case .tab: return Keysyms.XK_Tab
		case .undo: return Keysyms.XK_Undo
		case .upArrow: return Keysyms.XK_Up
		default:
			return nil
		}
	}
}

extension CGKeyCode {
	public init?(character: String) {
		if let keyCode = Initializers.shared.characterKeys[character] {
			self = keyCode
		} else {
			return nil
		}
	}
	
	public init?(specialKey: UInt32) {
		if let keyCode = Initializers.shared.specialKeys[specialKey] {
			self = keyCode
		} else {
			return nil
		}
	}

	public init?(modifierKey: UInt32) {
		if let keyCode = Initializers.shared.modifierFlagKeys[modifierKey] {
			self = keyCode
		} else {
			return nil
		}
	}

	static func charactersIgnoringModifiers(_ keyCode: CGKeyCode, shift: Bool) -> String? {
		guard var result = Initializers.shared.keysCharacters[keyCode] else {
			return nil
		}

		if shift {
			result = result.uppercased()
		}

		return result
	}

	static func characterForKeysym(_ vncKey: UInt32) -> String? {
		// Convert VNC codes to characters
		if vncKey >= 0x20 && vncKey <= 0x7E {
			// ASCII printable characters
			if let scalar = UnicodeScalar(vncKey) {
				return String(Character(scalar))
			}

			return nil
		}

		// Special characters
		switch vncKey {
		case 0x08, 0xFF08: return "\u{8}"  // Backspace
		case 0x09, 0xFF09: return "\t"  // Tab
		case 0x0D, 0xFF0D: return "\r"  // Return
		case 0x1B, 0xFF1B: return "\u{1B}"  // Escape
		case 0x0020: return " "  // Space
		default:
			return nil
		}
	}

	struct Initializers {
		let specialKeys: [UInt32:CGKeyCode]
		let characterKeys: [String:CGKeyCode]
		let modifierFlagKeys: [UInt32:CGKeyCode]
		let keysCharacters: [CGKeyCode:String]

		static var shared: Initializers! = nil
		
		init() throws {
			var specialKeys: [UInt32:CGKeyCode] = [:]
			var characterKeys: [String:CGKeyCode] = [:]
			var keysCharacters: [CGKeyCode:String] = [:]
			var modifierFlagKeys: [UInt32:CGKeyCode] = [:]
			let eventSource = CGEventSource(stateID: .privateState);
			let modifiers: [NSEvent.ModifierFlags] = [
				[],
				.init(rawValue: 0x100),
				.shift,
				.option,
				.shift.union(.option)
			]

			for keyCode in (0..<128).map({ CGKeyCode($0) }) {
				guard let cgevent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) else {
					throw ServiceError("Unable to create CGEvent for \(keyCode)")
				}
				
				if let nsevent = NSEvent(cgEvent: cgevent) {
					var hasHandledKeyCode = false
					
					if nsevent.type == .keyDown {
						if let specialKey = nsevent.specialKey {
							if let keysym = specialKey.keysym {
								hasHandledKeyCode = true
								specialKeys[keysym] = keyCode
							}
						} else {
							modifiers.forEach { modifier in
								if let characters = nsevent.characters(byApplyingModifiers: modifier) {
									hasHandledKeyCode = true

									if characterKeys[characters] == nil {
										characterKeys[characters] = keyCode

										if let charactersIgnoringModifiers = nsevent.charactersIgnoringModifiers {
											keysCharacters[keyCode] = charactersIgnoringModifiers
										}
									}
								}
							}
						}
					} else if nsevent.type == .flagsChanged {
						if let keysym = nsevent.modifierFlags.keysym {
							hasHandledKeyCode = true
							modifierFlagKeys[keysym] = keyCode
						}
					} else {
						Logger("CGKeyCode").debug("Unknown event type for keycode \(keyCode): \(nsevent.type)")
					}
					
					if hasHandledKeyCode == false {
						Logger("CGKeyCode").debug("Unhandled keycode: \(keyCode): \(nsevent.type)")
					}
				} else {
					throw ServiceError("unable to create NSEvent")
				}
			}

			self.specialKeys = specialKeys
			self.characterKeys = characterKeys
			self.modifierFlagKeys = modifierFlagKeys
			self.keysCharacters = keysCharacters
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

public extension VNCKeyCode {
	static let vncSpecialKeyCodeToKeyCodeMapping: [UInt32:CGKeyCode] = [
		0xFFE5: CGKeyCodes.capsLock,
		0xFFE6: CGKeyCodes.capsLock,
		0x1008FF2B: CGKeyCodes.function,

		VNCKeyCode.optionForARD.rawValue: CGKeyCodes.option,
		VNCKeyCode.rightOptionForARD.rawValue: CGKeyCodes.rightOption,
		VNCKeyCode.commandForARD.rawValue: CGKeyCodes.command,
		VNCKeyCode.rightCommandForARD.rawValue: CGKeyCodes.rightCommand,

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
	]

	static func to(vncKeyCode: UInt32) -> CGKeyCode? {
		return Self.vncSpecialKeyCodeToKeyCodeMapping[vncKeyCode]
	}
}

public class VNCKeyMapper: Keymapper {
	private var currentModifiers: NSEvent.ModifierFlags = NSEvent.ModifierFlags(rawValue: 0x100)

	static func setupKeyMapper() throws {
		CGKeyCode.Initializers.shared = try CGKeyCode.Initializers.init()
	}
	
	func setupKeyMapper() throws {
		try Self.setupKeyMapper()
	}
	
	private func vncKeyCodeTo(vncKeyCode: UInt32) -> (keyCode: CGKeyCode, modifier: Bool, characters: String?) {
		if let keyCode = CGKeyCode(modifierKey: vncKeyCode) {
			return (keyCode, true, CGKeyCode.characterForKeysym(vncKeyCode))
		}

		if let keyCode = CGKeyCode(specialKey: vncKeyCode) {
			return (keyCode, false, CGKeyCode.characterForKeysym(vncKeyCode))
		}

		if let keyCode = VNCKeyCode.to(vncKeyCode: vncKeyCode) {
			return (keyCode, false, CGKeyCode.characterForKeysym(vncKeyCode))
		}

		// ASCII printable characters
		if let scalar = UnicodeScalar(vncKeyCode) {
			let characters = String(scalar)

			guard let keyCode = CGKeyCode(character: characters) else {
				Logger(self).debug("Not found: key=\(vncKeyCode.hexa)")

				return (CGKeyCode(vncKeyCode), false, String(scalar))
			}

			return (keyCode, false, String(scalar))
		} else {
			Logger(self).debug("Not unicode found: key=\(vncKeyCode.hexa)")
		}

		return (CGKeyCode(vncKeyCode), false, CGKeyCode.characterForKeysym(vncKeyCode))
	}

	func mapVNCKey(_ vncKey: UInt32, isDown: Bool, sendKeyEvent: HandleKeyMapping) {
		let result = self.vncKeyCodeTo(vncKeyCode: vncKey)

		if result.modifier {
			switch result.keyCode {
			case CGKeyCodes.shift:
				if isDown {
					self.currentModifiers.insert(.leftShift.union(.shift))
				} else {
					self.currentModifiers.remove(.leftShift.union(.shift))
				}
			case CGKeyCodes.rightShift:
				if isDown {
					self.currentModifiers.insert(.rightShift.union(.shift))
				} else {
					self.currentModifiers.remove(.rightShift.union(.shift))
				}

			case CGKeyCodes.control:
				if isDown {
					self.currentModifiers.insert(.leftControl.union(.control))
				} else {
					self.currentModifiers.remove(.leftControl.union(.control))
				}
			case CGKeyCodes.rightControl:
				if isDown {
					self.currentModifiers.insert(.rightControl.union(.control))
				} else {
					self.currentModifiers.remove(.rightControl.union(.control))
				}

			case CGKeyCodes.option:
				if isDown {
					self.currentModifiers.insert(.leftOption.union(.option))
				} else {
					self.currentModifiers.remove(.leftOption.union(.option))
				}
			case CGKeyCodes.rightOption:
				if isDown {
					self.currentModifiers.insert(.rightOption.union(.option))
				} else {
					self.currentModifiers.remove(.rightOption.union(.option))
				}

			case CGKeyCodes.command:
				if isDown {
					self.currentModifiers.insert(.leftCommand.union(.command))
				} else {
					self.currentModifiers.remove(.leftCommand.union(.command))
				}
			case CGKeyCodes.rightCommand:
				if isDown {
					self.currentModifiers.insert(.rightCommand.union(.command))
				} else {
					self.currentModifiers.remove(.rightCommand.union(.command))
				}

			case CGKeyCodes.capsLock:
				if isDown {
					self.currentModifiers.insert(.capsLock)
				} else {
					self.currentModifiers.remove(.capsLock)
				}

			case CGKeyCodes.help:
				if isDown {
					self.currentModifiers.insert(.help)
				} else {
					self.currentModifiers.remove(.help)
				}

			case CGKeyCodes.function:
				if isDown {
					self.currentModifiers.insert(.function)
				} else {
					self.currentModifiers.remove(.function)
				}
			default:
				break
			}
		}

		let charactersIgnoringModifiers = CGKeyCode.charactersIgnoringModifiers(result.keyCode, shift: self.currentModifiers.contains(.shift))

		sendKeyEvent(result.keyCode, self.currentModifiers, result.characters, charactersIgnoringModifiers)
	}
}

