//
//  OSXKeyMapper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/12/2025.
//

import Carbon
import Foundation
import AppKit

class OSXKeyMapper: Keymapper {
	static let keyTableSize = 65536
	static let USKeyCodes = [
		/* The alphabet */
		Keysyms.XK_A: kVK_ANSI_A, /* A */
		Keysyms.XK_B: kVK_ANSI_B, /* B */
		Keysyms.XK_C: kVK_ANSI_C, /* C */
		Keysyms.XK_D: kVK_ANSI_D, /* D */
		Keysyms.XK_E: kVK_ANSI_E, /* E */
		Keysyms.XK_F: kVK_ANSI_F, /* F */
		Keysyms.XK_G: kVK_ANSI_G, /* G */
		Keysyms.XK_H: kVK_ANSI_H, /* H */
		Keysyms.XK_I: kVK_ANSI_I, /* I */
		Keysyms.XK_J: kVK_ANSI_J, /* J */
		Keysyms.XK_K: kVK_ANSI_K, /* K */
		Keysyms.XK_L: kVK_ANSI_L, /* L */
		Keysyms.XK_M: kVK_ANSI_M, /* M */
		Keysyms.XK_N: kVK_ANSI_N, /* N */
		Keysyms.XK_O: kVK_ANSI_O, /* O */
		Keysyms.XK_P: kVK_ANSI_P, /* P */
		Keysyms.XK_Q: kVK_ANSI_Q, /* Q */
		Keysyms.XK_R: kVK_ANSI_R, /* R */
		Keysyms.XK_S: kVK_ANSI_S, /* S */
		Keysyms.XK_T: kVK_ANSI_T, /* T */
		Keysyms.XK_U: kVK_ANSI_U, /* U */
		Keysyms.XK_V: kVK_ANSI_V, /* V */
		Keysyms.XK_W: kVK_ANSI_W, /* W */
		Keysyms.XK_X: kVK_ANSI_X, /* X */
		Keysyms.XK_Y: kVK_ANSI_Y, /* Y */
		Keysyms.XK_Z: kVK_ANSI_Z, /* Z */
		Keysyms.XK_a: kVK_ANSI_A, /* a */
		Keysyms.XK_b: kVK_ANSI_B, /* b */
		Keysyms.XK_c: kVK_ANSI_C, /* c */
		Keysyms.XK_d: kVK_ANSI_D, /* d */
		Keysyms.XK_e: kVK_ANSI_E, /* e */
		Keysyms.XK_f: kVK_ANSI_F, /* f */
		Keysyms.XK_g: kVK_ANSI_G, /* g */
		Keysyms.XK_h: kVK_ANSI_H, /* h */
		Keysyms.XK_i: kVK_ANSI_I, /* i */
		Keysyms.XK_j: kVK_ANSI_J, /* j */
		Keysyms.XK_k: kVK_ANSI_K, /* k */
		Keysyms.XK_l: kVK_ANSI_L, /* l */
		Keysyms.XK_m: kVK_ANSI_M, /* m */
		Keysyms.XK_n: kVK_ANSI_N, /* n */
		Keysyms.XK_o: kVK_ANSI_O, /* o */
		Keysyms.XK_p: kVK_ANSI_P, /* p */
		Keysyms.XK_q: kVK_ANSI_Q, /* q */
		Keysyms.XK_r: kVK_ANSI_R, /* r */
		Keysyms.XK_s: kVK_ANSI_S, /* s */
		Keysyms.XK_t: kVK_ANSI_T, /* t */
		Keysyms.XK_u: kVK_ANSI_U, /* u */
		Keysyms.XK_v: kVK_ANSI_V, /* v */
		Keysyms.XK_w: kVK_ANSI_W, /* w */
		Keysyms.XK_x: kVK_ANSI_X, /* x */
		Keysyms.XK_y: kVK_ANSI_Y, /* y */
		Keysyms.XK_z: kVK_ANSI_Z, /* z */

		/* Numbers */
		Keysyms.XK_0: kVK_ANSI_0, /* 0 */
		Keysyms.XK_1: kVK_ANSI_1, /* 1 */
		Keysyms.XK_2: kVK_ANSI_2, /* 2 */
		Keysyms.XK_3: kVK_ANSI_3, /* 3 */
		Keysyms.XK_4: kVK_ANSI_4, /* 4 */
		Keysyms.XK_5: kVK_ANSI_5, /* 5 */
		Keysyms.XK_6: kVK_ANSI_6, /* 6 */
		Keysyms.XK_7: kVK_ANSI_7, /* 7 */
		Keysyms.XK_8: kVK_ANSI_8, /* 8 */
		Keysyms.XK_9: kVK_ANSI_9, /* 9 */

		/* Symbols */
		Keysyms.XK_exclam: 18, /* ! */
		Keysyms.XK_at: 19, /* @ */
		Keysyms.XK_numbersign: 20, /* # */
		Keysyms.XK_dollar: 21, /* $ */
		Keysyms.XK_percent: 23, /* % */
		Keysyms.XK_asciicircum: 22, /* ^ */
		Keysyms.XK_ampersand: 26, /* & */
		Keysyms.XK_asterisk: 28, /* * */
		Keysyms.XK_parenleft: 25, /* ( */
		Keysyms.XK_parenright: 29, /* ) */
		Keysyms.XK_minus: kVK_ANSI_Minus, /* - */
		Keysyms.XK_underscore: 27, /* _ */
		Keysyms.XK_equal: kVK_ANSI_Equal, /* = */
		Keysyms.XK_plus: 24, /* + */
		Keysyms.XK_grave: kVK_ANSI_Grave, /* ` */
		/* XXX ? */
		Keysyms.XK_asciitilde: 50, /* ~ */
		Keysyms.XK_bracketleft: kVK_ANSI_LeftBracket, /* [ */
		Keysyms.XK_braceleft: 33, /* { */
		Keysyms.XK_bracketright: kVK_ANSI_RightBracket, /* ] */
		Keysyms.XK_braceright: 30, /* } */
		Keysyms.XK_semicolon: kVK_ANSI_Semicolon, /* ; */
		Keysyms.XK_colon: 41, /* : */
		Keysyms.XK_apostrophe: kVK_ANSI_Quote, /* ' */
		Keysyms.XK_quotedbl: 39, /* " */
		Keysyms.XK_comma: kVK_ANSI_Comma, /* , */
		Keysyms.XK_less: 43, /* < */
		Keysyms.XK_period: kVK_ANSI_Period, /* . */
		Keysyms.XK_greater: 47, /* > */
		Keysyms.XK_slash: kVK_ANSI_Slash, /* / */
		Keysyms.XK_question: 44, /* ? */
		Keysyms.XK_backslash: kVK_ANSI_Backslash, /* \ */
		Keysyms.XK_bar: 42, /* | */
		// OS X Sends this (END OF MEDIUM) for Shift-Tab (with US Keyboard)
		0x0019: kVK_Tab, /* Tab */
		Keysyms.XK_space: kVK_Space /* Space */,
	]

	static let SpecialKeyCodes = [
		/* "Special" keys */
		Keysyms.XK_Return: kVK_Return, /* Return */
		Keysyms.XK_Delete: kVK_ForwardDelete, /* Delete */
		Keysyms.XK_Tab: kVK_Tab, /* Tab */
		Keysyms.XK_Escape: kVK_Escape, /* Esc */
		Keysyms.XK_Caps_Lock: kVK_CapsLock, /* Caps Lock */
		Keysyms.XK_Num_Lock: kVK_ANSI_KeypadClear, /* Num Lock */
		Keysyms.XK_Scroll_Lock: kVK_F14, /* Scroll Lock */
		Keysyms.XK_Pause: kVK_F15, /* Pause */
		Keysyms.XK_BackSpace: kVK_Delete, /* Backspace */
		Keysyms.XK_Insert: kVK_Help, /* Insert */
		Keysyms.XK_Help: kVK_Help, /* Insert */

		/* Cursor movement */
		Keysyms.XK_Up: kVK_UpArrow, /* Cursor Up */
		Keysyms.XK_Down: kVK_DownArrow, /* Cursor Down */
		Keysyms.XK_Left: kVK_LeftArrow, /* Cursor Left */
		Keysyms.XK_Right: kVK_RightArrow, /* Cursor Right */
		Keysyms.XK_Page_Up: kVK_PageUp, /* Page Up */
		Keysyms.XK_Page_Down: kVK_PageDown, /* Page Down */
		Keysyms.XK_Home: kVK_Home, /* Home */
		Keysyms.XK_End: kVK_End, /* End */

		/* Numeric keypad */
		Keysyms.XK_KP_0: kVK_ANSI_Keypad0, /* KP 0 */
		Keysyms.XK_KP_1: kVK_ANSI_Keypad1, /* KP 1 */
		Keysyms.XK_KP_2: kVK_ANSI_Keypad2, /* KP 2 */
		Keysyms.XK_KP_3: kVK_ANSI_Keypad3, /* KP 3 */
		Keysyms.XK_KP_4: kVK_ANSI_Keypad4, /* KP 4 */
		Keysyms.XK_KP_5: kVK_ANSI_Keypad5, /* KP 5 */
		Keysyms.XK_KP_6: kVK_ANSI_Keypad6, /* KP 6 */
		Keysyms.XK_KP_7: kVK_ANSI_Keypad7, /* KP 7 */
		Keysyms.XK_KP_8: kVK_ANSI_Keypad8, /* KP 8 */
		Keysyms.XK_KP_9: kVK_ANSI_Keypad9, /* KP 9 */
		Keysyms.XK_KP_Enter: kVK_ANSI_KeypadEnter, /* KP Enter */
		Keysyms.XK_KP_Decimal: kVK_ANSI_KeypadDecimal, /* KP . */
		Keysyms.XK_KP_Add: kVK_ANSI_KeypadPlus, /* KP + */
		Keysyms.XK_KP_Subtract: kVK_ANSI_KeypadMinus, /* KP - */
		Keysyms.XK_KP_Multiply: kVK_ANSI_KeypadMultiply, /* KP * */
		Keysyms.XK_KP_Divide: kVK_ANSI_KeypadDivide, /* KP / */
		Keysyms.XK_KP_Equal: kVK_ANSI_KeypadEquals, /* KP = */

		/* Function keys */
		Keysyms.XK_F1: kVK_F1, /* F1 */
		Keysyms.XK_F2: kVK_F2, /* F2 */
		Keysyms.XK_F3: kVK_F3, /* F3 */
		Keysyms.XK_F4: kVK_F4, /* F4 */
		Keysyms.XK_F5: kVK_F5, /* F5 */
		Keysyms.XK_F6: kVK_F6, /* F6 */
		Keysyms.XK_F7: kVK_F7, /* F7 */
		Keysyms.XK_F8: kVK_F8, /* F8 */
		Keysyms.XK_F9: kVK_F9, /* F9 */
		Keysyms.XK_F10: kVK_F10, /* F10 */
		Keysyms.XK_F11: kVK_F11, /* F11 */
		Keysyms.XK_F12: kVK_F12, /* F12 */
		Keysyms.XK_F13: kVK_F13, /* F12 */
		Keysyms.XK_F14: kVK_F14, /* F12 */
		Keysyms.XK_F15: kVK_F15, /* F12 */
		Keysyms.XK_F16: kVK_F16, /* F12 */
		Keysyms.XK_F17: kVK_F17, /* F12 */
		Keysyms.XK_F18: kVK_F18, /* F12 */
		Keysyms.XK_F19: kVK_F19, /* F12 */
		Keysyms.XK_F20: kVK_F20, /* F12 */

		/* Modifier keys */
		Keysyms.XK_Alt_L: kVK_Command, /* Alt Left (-> Command) */
		Keysyms.XK_Alt_R: kVK_RightCommand, /* Alt Right (-> Command) */
		Keysyms.XK_Shift_L: kVK_Shift, /* Shift Left */
		Keysyms.XK_Shift_R: kVK_RightShift, /* Shift Right */
		Keysyms.XK_Meta_L: kVK_Option, /* Option Left (-> Option) */
		Keysyms.XK_Meta_R: kVK_RightOption, /* Option Right (-> Option) */
		Keysyms.XK_Super_L: kVK_Option, /* Option Left (-> Option) */
		Keysyms.XK_Super_R: kVK_RightOption, /* Option Right (-> Option) */
		Keysyms.XK_Control_L: kVK_Control, /* Ctrl Left */
		Keysyms.XK_Control_R: kVK_RightControl /* Ctrl Right */,
	]

	static var keyTable: [CGKeyCode] = [CGKeyCode](repeating: 0, count: keyTableSize)
	static var keyTableMods: [UInt8] = [UInt8](repeating: 0, count: keyTableSize)
	static var keymapInitialized: Bool = false

	static var keyCodeShift: CGKeyCode = 0
	static var keyCodeOption: CGKeyCode = 0
	static var keyCodeControl: CGKeyCode = 0
	static var keyCodeCommand: CGKeyCode = 0
	static var keyNumericPadCommand: CGKeyCode = 0
	static var keyFunctionCommand: CGKeyCode = 0

	var currentModifiers: NSEvent.ModifierFlags = []
	var unicodeInputSource: Unmanaged<TISInputSource>! = nil
	var currentInputSource: Unmanaged<TISInputSource>! = TISCopyCurrentKeyboardInputSource()
	var modiferKeys = [Bool](repeating: false, count: 256)
	var modifierDelay: Int = 5000
	var pressModsForKeys = false

	static func setupKeyMapper() {
		guard keymapInitialized == false else {
			return
		}

		keymapInitialized = true

		Self.USKeyCodes.forEach { k,v in
			keyTable[Int(k)] = CGKeyCode(v)
		}

		Self.SpecialKeyCodes.forEach { k, v in
			keyTable[Int(k)] = CGKeyCode(v)
		}

		self.keyCodeShift = keyTable[Int(Keysyms.XK_Shift_L)]
		self.keyCodeOption = keyTable[Int(Keysyms.XK_Meta_L)]
		self.keyCodeControl = keyTable[Int(Keysyms.XK_Control_L)]
		self.keyCodeCommand = keyTable[Int(Keysyms.XK_Alt_L)]
	}

	func setupKeyMapper() throws {
		Self.setupKeyMapper()
	}

	func mapVNCKey(_ vncKey: UInt32, isDown: Bool, sendKeyEvent: HandleKeyMapping) {
		let keyCode = UInt16(Self.keyTable[Int(vncKey)])
		let characters = CGKeyCode.characterForKeysym(vncKey)

		if keyCode == 0xFFFF {
			Logger(self).debug("keyCode not found: \(vncKey)")
		} else {
			self.modiferKeys[Int(keyCode)] = isDown

			// Record them in our "currentModifiers"
			switch vncKey {
			case Keysyms.XK_Shift_L:
				if isDown {
					currentModifiers.insert(.leftShift)
				} else {
					currentModifiers.remove(.leftShift)
				}
			case Keysyms.XK_Shift_R:
				if isDown {
					currentModifiers.insert(.rightShift)
				} else {
					currentModifiers.remove(.rightShift)
				}

			case Keysyms.XK_Control_L:
				if isDown {
					currentModifiers.insert(.leftControl)
				} else {
					currentModifiers.remove(.leftControl)
				}
			case Keysyms.XK_Control_R:
				if isDown {
					currentModifiers.insert(.rightControl)
				} else {
					currentModifiers.remove(.rightControl)
				}

			case Keysyms.XK_Meta_L:
				if isDown {
					currentModifiers.insert(.leftOption)
				} else {
					currentModifiers.remove(.leftOption)
				}
			case Keysyms.XK_Meta_R:
				if isDown {
					currentModifiers.insert(.rightOption)
				} else {
					currentModifiers.remove(.rightOption)
				}

			case Keysyms.XK_Alt_L:
				if isDown {
					currentModifiers.insert(.leftCommand)
				} else {
					currentModifiers.remove(.leftCommand)
				}
			case Keysyms.XK_Alt_R:
				if isDown {
					currentModifiers.insert(.rightCommand)
				} else {
					currentModifiers.remove(.rightCommand)
				}

			default:
				break
			}

			sendKeyEvent(keyCode, currentModifiers, characters, characters)
		}
	}
}
