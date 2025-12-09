//
//  CarbonKeyMapper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/12/2025.
//
import Foundation
import AppKit
import Carbon

enum CarbonKeyCode: CGKeyCode {
	/* keycodes for keys that are dependent on keyboard layout*/
	case kVK_ANSI_A                    = 0
	case kVK_ANSI_S                    = 1
	case kVK_ANSI_D                    = 2
	case kVK_ANSI_F                    = 3
	case kVK_ANSI_H                    = 4
	case kVK_ANSI_G                    = 5
	case kVK_ANSI_Z                    = 6
	case kVK_ANSI_X                    = 7
	case kVK_ANSI_C                    = 8
	case kVK_ANSI_V                    = 9
	case kVK_ISO_Section               = 10 // ISO keyboards only
	case kVK_ANSI_B                    = 11
	case kVK_ANSI_Q                    = 12
	case kVK_ANSI_W                    = 13
	case kVK_ANSI_E                    = 14
	case kVK_ANSI_R                    = 15
	
	case kVK_ANSI_Y                    = 16
	case kVK_ANSI_T                    = 17
	case kVK_ANSI_1                    = 18
	case kVK_ANSI_2                    = 19
	case kVK_ANSI_3                    = 20
	case kVK_ANSI_4                    = 21
	case kVK_ANSI_6                    = 22
	case kVK_ANSI_5                    = 23
	case kVK_ANSI_Equal                = 24
	case kVK_ANSI_9                    = 25
	case kVK_ANSI_7                    = 26
	case kVK_ANSI_Minus                = 27
	case kVK_ANSI_8                    = 28
	case kVK_ANSI_0                    = 29
	case kVK_ANSI_RightBracket         = 30
	case kVK_ANSI_O                    = 31
	
	case kVK_ANSI_U                    = 32
	case kVK_ANSI_LeftBracket          = 33
	case kVK_ANSI_I                    = 34
	case kVK_ANSI_P                    = 35
	case kVK_Return                    = 36
	case kVK_ANSI_L                    = 37
	case kVK_ANSI_J                    = 38
	case kVK_ANSI_Quote                = 39
	case kVK_ANSI_K                    = 40
	case kVK_ANSI_Semicolon            = 41
	case kVK_ANSI_Backslash            = 42
	case kVK_ANSI_Comma                = 43
	case kVK_ANSI_Slash                = 44
	case kVK_ANSI_N                    = 45
	case kVK_ANSI_M                    = 46
	case kVK_ANSI_Period               = 47
	
	case kVK_Tab                       = 48
	case kVK_Space                     = 49
	case kVK_ANSI_Grave                = 50
	case kVK_Delete                    = 51
	case kVK_Unknown01                 = 52
	case kVK_Escape                    = 53
	case kVK_RightCommand              = 54
	case kVK_Command                   = 55
	case kVK_Shift                     = 56
	case kVK_CapsLock                  = 57
	case kVK_Option                    = 58
	case kVK_Control                   = 59
	case kVK_RightShift                = 60
	case kVK_RightOption               = 61
	case kVK_RightControl              = 62
	case kVK_Function                  = 63
	
	case kVK_F17                       = 64
	case kVK_ANSI_KeypadDecimal        = 65
	case kVK_Unknown02                 = 66
	case kVK_ANSI_KeypadMultiply       = 67
	case kVK_Unknown03                 = 68
	case kVK_ANSI_KeypadPlus           = 69
	case kVK_Unknown04                 = 70
	case kVK_ANSI_KeypadClear          = 71
	case kVK_VolumeUp                  = 72
	case kVK_VolumeDown                = 73
	case kVK_Mute                      = 74
	case kVK_ANSI_KeypadDivide         = 75
	case kVK_ANSI_KeypadEnter          = 76
	case kVK_Unknown05                 = 77
	case kVK_ANSI_KeypadMinus          = 78
	case kVK_F18                       = 79
	
	case kVK_F19                       = 80
	case kVK_ANSI_KeypadEquals         = 81
	case kVK_ANSI_Keypad0              = 82
	case kVK_ANSI_Keypad1              = 83
	case kVK_ANSI_Keypad2              = 84
	case kVK_ANSI_Keypad3              = 85
	case kVK_ANSI_Keypad4              = 86
	case kVK_ANSI_Keypad5              = 87
	case kVK_ANSI_Keypad6              = 88
	case kVK_ANSI_Keypad7              = 89
	case kVK_F20                       = 90
	case kVK_ANSI_Keypad8              = 91
	case kVK_ANSI_Keypad9              = 92
	case kVK_JIS_Yen                   = 93 // JIS keyboards only
	case kVK_JIS_Underscore            = 94 // JIS keyboards only
	case kVK_JIS_KeypadComma           = 95 // JIS keyboards only
	
	/* keycodes for keys that are independent of keyboard layout*/
	
	case kVK_F5                        = 96
	case kVK_F6                        = 97
	case kVK_F7                        = 98
	case kVK_F3                        = 99
	case kVK_F8                        = 100
	case kVK_F9                        = 101
	case kVK_JIS_Eisu                  = 102 // JIS keyboards only
	case kVK_F11                       = 103
	case kVK_JIS_Kana                  = 104 // JIS keyboards only
	case kVK_F13                       = 105
	case kVK_F16                       = 106
	case kVK_F14                       = 107
	case kVK_F10                       = 109
	case kVK_Unknown08                 = 108
	case kVK_ContextualMenu            = 110
	case kVK_F12                       = 111
	
	case kVK_Unknown06                 = 112
	case kVK_F15                       = 113
	case kVK_Help                      = 114
	case kVK_Home                      = 115
	case kVK_PageUp                    = 116
	case kVK_ForwardDelete             = 117
	case kVK_F4                        = 118
	case kVK_End                       = 119
	case kVK_F2                        = 120
	case kVK_PageDown                  = 121
	case kVK_F1                        = 122
	case kVK_LeftArrow                 = 123
	case kVK_RightArrow                = 124
	case kVK_DownArrow                 = 125
	case kVK_UpArrow                   = 126
	case kVK_Unknown07                 = 127
	
	static let USKeyCodes: [UInt32:CarbonKeyCode] = [
		/* Numbers */
		Keysyms.XK_0: .kVK_ANSI_0, /* 0 */
		Keysyms.XK_1: .kVK_ANSI_1, /* 1 */
		Keysyms.XK_2: .kVK_ANSI_2, /* 2 */
		Keysyms.XK_3: .kVK_ANSI_3, /* 3 */
		Keysyms.XK_4: .kVK_ANSI_4, /* 4 */
		Keysyms.XK_5: .kVK_ANSI_5, /* 5 */
		Keysyms.XK_6: .kVK_ANSI_6, /* 6 */
		Keysyms.XK_7: .kVK_ANSI_7, /* 7 */
		Keysyms.XK_8: .kVK_ANSI_8, /* 8 */
		Keysyms.XK_9: .kVK_ANSI_9, /* 9 */

		/* The alphabet */
		Keysyms.XK_A: .kVK_ANSI_A, /* A */
		Keysyms.XK_B: .kVK_ANSI_B, /* B */
		Keysyms.XK_C: .kVK_ANSI_C, /* C */
		Keysyms.XK_D: .kVK_ANSI_D, /* D */
		Keysyms.XK_E: .kVK_ANSI_E, /* E */
		Keysyms.XK_F: .kVK_ANSI_F, /* F */
		Keysyms.XK_G: .kVK_ANSI_G, /* G */
		Keysyms.XK_H: .kVK_ANSI_H, /* H */
		Keysyms.XK_I: .kVK_ANSI_I, /* I */
		Keysyms.XK_J: .kVK_ANSI_J, /* J */
		Keysyms.XK_K: .kVK_ANSI_K, /* K */
		Keysyms.XK_L: .kVK_ANSI_L, /* L */
		Keysyms.XK_M: .kVK_ANSI_M, /* M */
		Keysyms.XK_N: .kVK_ANSI_N, /* N */
		Keysyms.XK_O: .kVK_ANSI_O, /* O */
		Keysyms.XK_P: .kVK_ANSI_P, /* P */
		Keysyms.XK_Q: .kVK_ANSI_Q, /* Q */
		Keysyms.XK_R: .kVK_ANSI_R, /* R */
		Keysyms.XK_S: .kVK_ANSI_S, /* S */
		Keysyms.XK_T: .kVK_ANSI_T, /* T */
		Keysyms.XK_U: .kVK_ANSI_U, /* U */
		Keysyms.XK_V: .kVK_ANSI_V, /* V */
		Keysyms.XK_W: .kVK_ANSI_W, /* W */
		Keysyms.XK_X: .kVK_ANSI_X, /* X */
		Keysyms.XK_Y: .kVK_ANSI_Y, /* Y */
		Keysyms.XK_Z: .kVK_ANSI_Z, /* Z */
		Keysyms.XK_a: .kVK_ANSI_A, /* a */
		Keysyms.XK_b: .kVK_ANSI_B, /* b */
		Keysyms.XK_c: .kVK_ANSI_C, /* c */
		Keysyms.XK_d: .kVK_ANSI_D, /* d */
		Keysyms.XK_e: .kVK_ANSI_E, /* e */
		Keysyms.XK_f: .kVK_ANSI_F, /* f */
		Keysyms.XK_g: .kVK_ANSI_G, /* g */
		Keysyms.XK_h: .kVK_ANSI_H, /* h */
		Keysyms.XK_i: .kVK_ANSI_I, /* i */
		Keysyms.XK_j: .kVK_ANSI_J, /* j */
		Keysyms.XK_k: .kVK_ANSI_K, /* k */
		Keysyms.XK_l: .kVK_ANSI_L, /* l */
		Keysyms.XK_m: .kVK_ANSI_M, /* m */
		Keysyms.XK_n: .kVK_ANSI_N, /* n */
		Keysyms.XK_o: .kVK_ANSI_O, /* o */
		Keysyms.XK_p: .kVK_ANSI_P, /* p */
		Keysyms.XK_q: .kVK_ANSI_Q, /* q */
		Keysyms.XK_r: .kVK_ANSI_R, /* r */
		Keysyms.XK_s: .kVK_ANSI_S, /* s */
		Keysyms.XK_t: .kVK_ANSI_T, /* t */
		Keysyms.XK_u: .kVK_ANSI_U, /* u */
		Keysyms.XK_v: .kVK_ANSI_V, /* v */
		Keysyms.XK_w: .kVK_ANSI_W, /* w */
		Keysyms.XK_x: .kVK_ANSI_X, /* x */
		Keysyms.XK_y: .kVK_ANSI_Y, /* y */
		Keysyms.XK_z: .kVK_ANSI_Z, /* z */

		/* Symbols */
		Keysyms.XK_exclam: .kVK_ANSI_1, /* ! */
		Keysyms.XK_at: .kVK_ANSI_2, /* @ */
		Keysyms.XK_numbersign: .kVK_ANSI_3, /* # */
		Keysyms.XK_dollar: .kVK_ANSI_4, /* $ */
		Keysyms.XK_percent: .kVK_ANSI_5, /* % */
		Keysyms.XK_asciicircum: .kVK_ANSI_6, /* ^ */
		Keysyms.XK_ampersand: .kVK_ANSI_7, /* & */
		Keysyms.XK_asterisk: .kVK_ANSI_8, /* * */
		Keysyms.XK_parenleft: .kVK_ANSI_9, /* ( */
		Keysyms.XK_parenright: .kVK_ANSI_0, /* ) */
		Keysyms.XK_minus: .kVK_ANSI_Minus, /* - */
		Keysyms.XK_underscore: .kVK_ANSI_Minus, /* _ */
		Keysyms.XK_equal: .kVK_ANSI_Equal, /* = */
		Keysyms.XK_plus: .kVK_ANSI_Equal, /* + */
		Keysyms.XK_grave: .kVK_ANSI_Grave, /* ` */

		// Numeric keypad
		0xFF9C: CarbonKeyCode.kVK_ANSI_Keypad0,  // Keypad 0
		Keysyms.XK_KP_Begin: CarbonKeyCode.kVK_ANSI_Keypad1,  // Keypad 1
		Keysyms.XK_KP_Insert: CarbonKeyCode.kVK_ANSI_Keypad2,  // Keypad 2
		Keysyms.XK_KP_Delete: CarbonKeyCode.kVK_ANSI_Keypad3,  // Keypad 3
		0xFFA0: CarbonKeyCode.kVK_ANSI_Keypad4,  // Keypad 4
		0xFFA1: CarbonKeyCode.kVK_ANSI_Keypad5,  // Keypad 5
		0xFFA2: CarbonKeyCode.kVK_ANSI_Keypad6,  // Keypad 6
		0xFFA3: CarbonKeyCode.kVK_ANSI_Keypad7,  // Keypad 7
		0xFFA4: CarbonKeyCode.kVK_ANSI_Keypad8,  // Keypad 8
		0xFFA5: CarbonKeyCode.kVK_ANSI_Keypad9,  // Keypad 9

		Keysyms.XK_KP_0: CarbonKeyCode.kVK_ANSI_Keypad0, /* KP 0 */
		Keysyms.XK_KP_1: CarbonKeyCode.kVK_ANSI_Keypad1, /* KP 1 */
		Keysyms.XK_KP_2: CarbonKeyCode.kVK_ANSI_Keypad2, /* KP 2 */
		Keysyms.XK_KP_3: CarbonKeyCode.kVK_ANSI_Keypad3, /* KP 3 */
		Keysyms.XK_KP_4: CarbonKeyCode.kVK_ANSI_Keypad4, /* KP 4 */
		Keysyms.XK_KP_5: CarbonKeyCode.kVK_ANSI_Keypad5, /* KP 5 */
		Keysyms.XK_KP_6: CarbonKeyCode.kVK_ANSI_Keypad6, /* KP 6 */
		Keysyms.XK_KP_7: CarbonKeyCode.kVK_ANSI_Keypad7, /* KP 7 */
		Keysyms.XK_KP_8: CarbonKeyCode.kVK_ANSI_Keypad8, /* KP 8 */
		Keysyms.XK_KP_9: CarbonKeyCode.kVK_ANSI_Keypad9, /* KP 9 */

		/* Function keys */
		Keysyms.XK_F1: CarbonKeyCode.kVK_F1, /* F1 */
		Keysyms.XK_F2: CarbonKeyCode.kVK_F2, /* F2 */
		Keysyms.XK_F3: CarbonKeyCode.kVK_F3, /* F3 */
		Keysyms.XK_F4: CarbonKeyCode.kVK_F4, /* F4 */
		Keysyms.XK_F5: CarbonKeyCode.kVK_F5, /* F5 */
		Keysyms.XK_F6: CarbonKeyCode.kVK_F6, /* F6 */
		Keysyms.XK_F7: CarbonKeyCode.kVK_F7, /* F7 */
		Keysyms.XK_F8: CarbonKeyCode.kVK_F8, /* F8 */
		Keysyms.XK_F9: CarbonKeyCode.kVK_F9, /* F9 */
		Keysyms.XK_F10: CarbonKeyCode.kVK_F10, /* F10 */
		Keysyms.XK_F11: CarbonKeyCode.kVK_F11, /* F11 */
		Keysyms.XK_F12: CarbonKeyCode.kVK_F12, /* F12 */
		Keysyms.XK_F13: CarbonKeyCode.kVK_F13, /* F12 */
		Keysyms.XK_F14: CarbonKeyCode.kVK_F14, /* F12 */
		Keysyms.XK_F15: CarbonKeyCode.kVK_F15, /* F12 */
		Keysyms.XK_F16: CarbonKeyCode.kVK_F16, /* F12 */
		Keysyms.XK_F17: CarbonKeyCode.kVK_F17, /* F12 */
		Keysyms.XK_F18: CarbonKeyCode.kVK_F18, /* F12 */
		Keysyms.XK_F19: CarbonKeyCode.kVK_F19, /* F12 */
		Keysyms.XK_F20: CarbonKeyCode.kVK_F20, /* F12 */

		// Arrows
		Keysyms.XK_Left: CarbonKeyCode.kVK_LeftArrow, /* Cursor Left */
		Keysyms.XK_Up: CarbonKeyCode.kVK_UpArrow, /* Cursor Up */
		Keysyms.XK_Right: CarbonKeyCode.kVK_RightArrow, /* Cursor Right */
		Keysyms.XK_Down: CarbonKeyCode.kVK_DownArrow, /* Cursor Down */

		// Navigation keys
		Keysyms.XK_Home: CarbonKeyCode.kVK_Home, /* Home */
		Keysyms.XK_End: CarbonKeyCode.kVK_End, /* End */
		Keysyms.XK_Page_Up: CarbonKeyCode.kVK_PageUp, /* Page Up */
		Keysyms.XK_Page_Down: CarbonKeyCode.kVK_PageDown, /* Page Down */
		Keysyms.XK_Insert: CarbonKeyCode.kVK_Help, /* Insert */

		// Special keys
		Keysyms.XK_Return: CarbonKeyCode.kVK_Return, /* Return */
		Keysyms.XK_Delete: CarbonKeyCode.kVK_ForwardDelete, /* Delete */
		Keysyms.XK_Tab: CarbonKeyCode.kVK_Tab, /* Tab */
		Keysyms.XK_Escape: CarbonKeyCode.kVK_Escape, /* Esc */
		Keysyms.XK_Caps_Lock: CarbonKeyCode.kVK_CapsLock, /* Caps Lock */
		Keysyms.XK_Num_Lock: CarbonKeyCode.kVK_ANSI_KeypadClear, /* Num Lock */
		Keysyms.XK_Scroll_Lock: CarbonKeyCode.kVK_F14, /* Scroll Lock */
		Keysyms.XK_Pause: CarbonKeyCode.kVK_F15, /* Pause */
		Keysyms.XK_BackSpace: CarbonKeyCode.kVK_Delete, /* Backspace */
		Keysyms.XK_Help: CarbonKeyCode.kVK_Help, /* Insert */

		// Punctuation
		Keysyms.XK_period: CarbonKeyCode.kVK_ANSI_Period, /* . */
		Keysyms.XK_comma: CarbonKeyCode.kVK_ANSI_Comma, /* , */
		Keysyms.XK_semicolon: CarbonKeyCode.kVK_ANSI_Semicolon, /* ; */
		Keysyms.XK_bracketleft: CarbonKeyCode.kVK_ANSI_LeftBracket, /* [ */
		Keysyms.XK_bracketright: CarbonKeyCode.kVK_ANSI_RightBracket, /* ] */
		Keysyms.XK_backslash: CarbonKeyCode.kVK_ANSI_Backslash, /* \ */
		Keysyms.XK_slash: CarbonKeyCode.kVK_ANSI_Slash, /* / */
		Keysyms.XK_minus: CarbonKeyCode.kVK_ANSI_Minus, /* - */
		Keysyms.XK_equal: CarbonKeyCode.kVK_ANSI_Equal, /* = */
		Keysyms.XK_grave: CarbonKeyCode.kVK_ANSI_Grave, /* ` */

		/* XXX ? */
		Keysyms.XK_asciitilde: .kVK_ANSI_Grave, /* ~ */
		Keysyms.XK_bracketleft: .kVK_ANSI_LeftBracket, /* [ */
		Keysyms.XK_braceleft: .kVK_ANSI_LeftBracket, /* { */
		Keysyms.XK_bracketright: .kVK_ANSI_RightBracket, /* ] */
		Keysyms.XK_braceright: .kVK_ANSI_RightBracket, /* } */
		Keysyms.XK_semicolon: .kVK_ANSI_Semicolon, /* ; */
		Keysyms.XK_colon: .kVK_ANSI_Semicolon, /* : */
		Keysyms.XK_apostrophe: .kVK_ANSI_Quote, /* ' */
		Keysyms.XK_quotedbl: .kVK_ANSI_Quote, /* " */
		Keysyms.XK_comma: .kVK_ANSI_Comma, /* , */
		Keysyms.XK_less: .kVK_ANSI_Comma, /* < */
		Keysyms.XK_period: .kVK_ANSI_Period, /* . */
		Keysyms.XK_greater: .kVK_ANSI_Period, /* > */
		Keysyms.XK_slash: .kVK_ANSI_Slash, /* / */
		Keysyms.XK_question: .kVK_ANSI_Period, /* ? */
		Keysyms.XK_backslash: .kVK_ANSI_Backslash, /* \ */
		Keysyms.XK_bar: .kVK_ANSI_Backslash, /* | */

		// OS X Sends this (END OF MEDIUM) for Shift-Tab (with US Keyboard)
		0x0019: .kVK_Tab, /* Tab */
		Keysyms.XK_space: .kVK_Space /* Space */,
	]
}

public class CarbonKeyMapper: Keymapper {
	// Mapping des touches VNC vers les key codes macOS
	static let vncToMacKeyMap = [
		// Letters
		Keysyms.XK_A: CarbonKeyCode.kVK_ANSI_A, /* A */
		Keysyms.XK_B: CarbonKeyCode.kVK_ANSI_B, /* B */
		Keysyms.XK_C: CarbonKeyCode.kVK_ANSI_C, /* C */
		Keysyms.XK_D: CarbonKeyCode.kVK_ANSI_D, /* D */
		Keysyms.XK_E: CarbonKeyCode.kVK_ANSI_E, /* E */
		Keysyms.XK_F: CarbonKeyCode.kVK_ANSI_F, /* F */
		Keysyms.XK_G: CarbonKeyCode.kVK_ANSI_G, /* G */
		Keysyms.XK_H: CarbonKeyCode.kVK_ANSI_H, /* H */
		Keysyms.XK_I: CarbonKeyCode.kVK_ANSI_I, /* I */
		Keysyms.XK_J: CarbonKeyCode.kVK_ANSI_J, /* J */
		Keysyms.XK_K: CarbonKeyCode.kVK_ANSI_K, /* K */
		Keysyms.XK_L: CarbonKeyCode.kVK_ANSI_L, /* L */
		Keysyms.XK_M: CarbonKeyCode.kVK_ANSI_M, /* M */
		Keysyms.XK_N: CarbonKeyCode.kVK_ANSI_N, /* N */
		Keysyms.XK_O: CarbonKeyCode.kVK_ANSI_O, /* O */
		Keysyms.XK_P: CarbonKeyCode.kVK_ANSI_P, /* P */
		Keysyms.XK_Q: CarbonKeyCode.kVK_ANSI_Q, /* Q */
		Keysyms.XK_R: CarbonKeyCode.kVK_ANSI_R, /* R */
		Keysyms.XK_S: CarbonKeyCode.kVK_ANSI_S, /* S */
		Keysyms.XK_T: CarbonKeyCode.kVK_ANSI_T, /* T */
		Keysyms.XK_U: CarbonKeyCode.kVK_ANSI_U, /* U */
		Keysyms.XK_V: CarbonKeyCode.kVK_ANSI_V, /* V */
		Keysyms.XK_W: CarbonKeyCode.kVK_ANSI_W, /* W */
		Keysyms.XK_X: CarbonKeyCode.kVK_ANSI_X, /* X */
		Keysyms.XK_Y: CarbonKeyCode.kVK_ANSI_Y, /* Y */
		Keysyms.XK_Z: CarbonKeyCode.kVK_ANSI_Z, /* Z */
		Keysyms.XK_a: CarbonKeyCode.kVK_ANSI_A, /* a */
		Keysyms.XK_b: CarbonKeyCode.kVK_ANSI_B, /* b */
		Keysyms.XK_c: CarbonKeyCode.kVK_ANSI_C, /* c */
		Keysyms.XK_d: CarbonKeyCode.kVK_ANSI_D, /* d */
		Keysyms.XK_e: CarbonKeyCode.kVK_ANSI_E, /* e */
		Keysyms.XK_f: CarbonKeyCode.kVK_ANSI_F, /* f */
		Keysyms.XK_g: CarbonKeyCode.kVK_ANSI_G, /* g */
		Keysyms.XK_h: CarbonKeyCode.kVK_ANSI_H, /* h */
		Keysyms.XK_i: CarbonKeyCode.kVK_ANSI_I, /* i */
		Keysyms.XK_j: CarbonKeyCode.kVK_ANSI_J, /* j */
		Keysyms.XK_k: CarbonKeyCode.kVK_ANSI_K, /* k */
		Keysyms.XK_l: CarbonKeyCode.kVK_ANSI_L, /* l */
		Keysyms.XK_m: CarbonKeyCode.kVK_ANSI_M, /* m */
		Keysyms.XK_n: CarbonKeyCode.kVK_ANSI_N, /* n */
		Keysyms.XK_o: CarbonKeyCode.kVK_ANSI_O, /* o */
		Keysyms.XK_p: CarbonKeyCode.kVK_ANSI_P, /* p */
		Keysyms.XK_q: CarbonKeyCode.kVK_ANSI_Q, /* q */
		Keysyms.XK_r: CarbonKeyCode.kVK_ANSI_R, /* r */
		Keysyms.XK_s: CarbonKeyCode.kVK_ANSI_S, /* s */
		Keysyms.XK_t: CarbonKeyCode.kVK_ANSI_T, /* t */
		Keysyms.XK_u: CarbonKeyCode.kVK_ANSI_U, /* u */
		Keysyms.XK_v: CarbonKeyCode.kVK_ANSI_V, /* v */
		Keysyms.XK_w: CarbonKeyCode.kVK_ANSI_W, /* w */
		Keysyms.XK_x: CarbonKeyCode.kVK_ANSI_X, /* x */
		Keysyms.XK_y: CarbonKeyCode.kVK_ANSI_Y, /* y */
		Keysyms.XK_z: CarbonKeyCode.kVK_ANSI_Z, /* z */

		/* Numbers */
		Keysyms.XK_0: CarbonKeyCode.kVK_ANSI_0, /* 0 */
		Keysyms.XK_1: CarbonKeyCode.kVK_ANSI_1, /* 1 */
		Keysyms.XK_2: CarbonKeyCode.kVK_ANSI_2, /* 2 */
		Keysyms.XK_3: CarbonKeyCode.kVK_ANSI_3, /* 3 */
		Keysyms.XK_4: CarbonKeyCode.kVK_ANSI_4, /* 4 */
		Keysyms.XK_5: CarbonKeyCode.kVK_ANSI_5, /* 5 */
		Keysyms.XK_6: CarbonKeyCode.kVK_ANSI_6, /* 6 */
		Keysyms.XK_7: CarbonKeyCode.kVK_ANSI_7, /* 7 */
		Keysyms.XK_8: CarbonKeyCode.kVK_ANSI_8, /* 8 */
		Keysyms.XK_9: CarbonKeyCode.kVK_ANSI_9, /* 9 */

		// Special keys
		Keysyms.XK_Return: CarbonKeyCode.kVK_Return, /* Return */
		Keysyms.XK_Delete: CarbonKeyCode.kVK_ForwardDelete, /* Delete */
		Keysyms.XK_Tab: CarbonKeyCode.kVK_Tab, /* Tab */
		Keysyms.XK_Escape: CarbonKeyCode.kVK_Escape, /* Esc */
		Keysyms.XK_Caps_Lock: CarbonKeyCode.kVK_CapsLock, /* Caps Lock */
		Keysyms.XK_Num_Lock: CarbonKeyCode.kVK_ANSI_KeypadClear, /* Num Lock */
		Keysyms.XK_Scroll_Lock: CarbonKeyCode.kVK_F14, /* Scroll Lock */
		Keysyms.XK_Pause: CarbonKeyCode.kVK_F15, /* Pause */
		Keysyms.XK_BackSpace: CarbonKeyCode.kVK_Delete, /* Backspace */
		Keysyms.XK_Insert: CarbonKeyCode.kVK_Help, /* Insert */
		Keysyms.XK_Help: CarbonKeyCode.kVK_Help, /* Insert */

		/* Function keys */
		Keysyms.XK_F1: CarbonKeyCode.kVK_F1, /* F1 */
		Keysyms.XK_F2: CarbonKeyCode.kVK_F2, /* F2 */
		Keysyms.XK_F3: CarbonKeyCode.kVK_F3, /* F3 */
		Keysyms.XK_F4: CarbonKeyCode.kVK_F4, /* F4 */
		Keysyms.XK_F5: CarbonKeyCode.kVK_F5, /* F5 */
		Keysyms.XK_F6: CarbonKeyCode.kVK_F6, /* F6 */
		Keysyms.XK_F7: CarbonKeyCode.kVK_F7, /* F7 */
		Keysyms.XK_F8: CarbonKeyCode.kVK_F8, /* F8 */
		Keysyms.XK_F9: CarbonKeyCode.kVK_F9, /* F9 */
		Keysyms.XK_F10: CarbonKeyCode.kVK_F10, /* F10 */
		Keysyms.XK_F11: CarbonKeyCode.kVK_F11, /* F11 */
		Keysyms.XK_F12: CarbonKeyCode.kVK_F12, /* F12 */
		Keysyms.XK_F13: CarbonKeyCode.kVK_F13, /* F12 */
		Keysyms.XK_F14: CarbonKeyCode.kVK_F14, /* F12 */
		Keysyms.XK_F15: CarbonKeyCode.kVK_F15, /* F12 */
		Keysyms.XK_F16: CarbonKeyCode.kVK_F16, /* F12 */
		Keysyms.XK_F17: CarbonKeyCode.kVK_F17, /* F12 */
		Keysyms.XK_F18: CarbonKeyCode.kVK_F18, /* F12 */
		Keysyms.XK_F19: CarbonKeyCode.kVK_F19, /* F12 */
		Keysyms.XK_F20: CarbonKeyCode.kVK_F20, /* F12 */

		// Arrows
		Keysyms.XK_Left: CarbonKeyCode.kVK_LeftArrow, /* Cursor Left */
		Keysyms.XK_Up: CarbonKeyCode.kVK_UpArrow, /* Cursor Up */
		Keysyms.XK_Right: CarbonKeyCode.kVK_RightArrow, /* Cursor Right */
		Keysyms.XK_Down: CarbonKeyCode.kVK_DownArrow, /* Cursor Down */

		// Navigation keys
		Keysyms.XK_Home: CarbonKeyCode.kVK_Home, /* Home */
		Keysyms.XK_End: CarbonKeyCode.kVK_End, /* End */
		Keysyms.XK_Page_Up: CarbonKeyCode.kVK_PageUp, /* Page Up */
		Keysyms.XK_Page_Down: CarbonKeyCode.kVK_PageDown, /* Page Down */

		// Numeric keypad
		0xFF9C: CarbonKeyCode.kVK_ANSI_Keypad0,  // Keypad 0
		Keysyms.XK_KP_Begin: CarbonKeyCode.kVK_ANSI_Keypad1,  // Keypad 1
		Keysyms.XK_KP_Insert: CarbonKeyCode.kVK_ANSI_Keypad2,  // Keypad 2
		Keysyms.XK_KP_Delete: CarbonKeyCode.kVK_ANSI_Keypad3,  // Keypad 3
		0xFFA0: CarbonKeyCode.kVK_ANSI_Keypad4,  // Keypad 4
		0xFFA1: CarbonKeyCode.kVK_ANSI_Keypad5,  // Keypad 5
		0xFFA2: CarbonKeyCode.kVK_ANSI_Keypad6,  // Keypad 6
		0xFFA3: CarbonKeyCode.kVK_ANSI_Keypad7,  // Keypad 7
		0xFFA4: CarbonKeyCode.kVK_ANSI_Keypad8,  // Keypad 8
		0xFFA5: CarbonKeyCode.kVK_ANSI_Keypad9,  // Keypad 9

		// Numeric keypad
		Keysyms.XK_KP_0: CarbonKeyCode.kVK_ANSI_Keypad0, /* KP 0 */
		Keysyms.XK_KP_1: CarbonKeyCode.kVK_ANSI_Keypad1, /* KP 1 */
		Keysyms.XK_KP_2: CarbonKeyCode.kVK_ANSI_Keypad2, /* KP 2 */
		Keysyms.XK_KP_3: CarbonKeyCode.kVK_ANSI_Keypad3, /* KP 3 */
		Keysyms.XK_KP_4: CarbonKeyCode.kVK_ANSI_Keypad4, /* KP 4 */
		Keysyms.XK_KP_5: CarbonKeyCode.kVK_ANSI_Keypad5, /* KP 5 */
		Keysyms.XK_KP_6: CarbonKeyCode.kVK_ANSI_Keypad6, /* KP 6 */
		Keysyms.XK_KP_7: CarbonKeyCode.kVK_ANSI_Keypad7, /* KP 7 */
		Keysyms.XK_KP_8: CarbonKeyCode.kVK_ANSI_Keypad8, /* KP 8 */
		Keysyms.XK_KP_9: CarbonKeyCode.kVK_ANSI_Keypad9, /* KP 9 */

		Keysyms.XK_KP_Enter: CarbonKeyCode.kVK_ANSI_KeypadEnter, /* KP Enter */
		Keysyms.XK_KP_Decimal: CarbonKeyCode.kVK_ANSI_KeypadDecimal, /* KP . */
		Keysyms.XK_KP_Add: CarbonKeyCode.kVK_ANSI_KeypadPlus, /* KP + */
		Keysyms.XK_KP_Subtract: CarbonKeyCode.kVK_ANSI_KeypadMinus, /* KP - */
		Keysyms.XK_KP_Multiply: CarbonKeyCode.kVK_ANSI_KeypadMultiply, /* KP * */
		Keysyms.XK_KP_Divide: CarbonKeyCode.kVK_ANSI_KeypadDivide, /* KP / */
		Keysyms.XK_KP_Equal: CarbonKeyCode.kVK_ANSI_KeypadEquals, /* KP = */

		// Punctuation
		Keysyms.XK_period: CarbonKeyCode.kVK_ANSI_Period, /* . */
		Keysyms.XK_comma: CarbonKeyCode.kVK_ANSI_Comma, /* , */
		Keysyms.XK_semicolon: CarbonKeyCode.kVK_ANSI_Semicolon, /* ; */
		Keysyms.XK_bracketleft: CarbonKeyCode.kVK_ANSI_LeftBracket, /* [ */
		Keysyms.XK_bracketright: CarbonKeyCode.kVK_ANSI_RightBracket, /* ] */
		Keysyms.XK_backslash: CarbonKeyCode.kVK_ANSI_Backslash, /* \ */
		Keysyms.XK_slash: CarbonKeyCode.kVK_ANSI_Slash, /* / */
		Keysyms.XK_minus: CarbonKeyCode.kVK_ANSI_Minus, /* - */
		Keysyms.XK_equal: CarbonKeyCode.kVK_ANSI_Equal, /* = */
		Keysyms.XK_grave: CarbonKeyCode.kVK_ANSI_Grave, /* ` */
	]

	// Mapping des modificateurs VNC vers NSEvent.ModifierFlags
	static let vncModifiers: [UInt32: NSEvent.ModifierFlags] = [
		0xFF0B: .numericPad,
		0xFFE1: .leftShift,  // Left Shift
		0xFFE2: .rightShift,  // Right Shift
		0xFFE3: .leftControl,  // Left Control
		0xFFE4: .rightControl,  // Right Control
		0xFFE5: .capsLock,  // Shift lock
		0xFFE6: .capsLock,  // Left Shift
		0xFFE7: .leftOption,  // Left Meta
		0xFFE8: .rightOption,  // Right Meta
		0xFFE9: .leftOption,  // Left Alt
		0xFFEA: .rightOption,  // Right Alt
		0xFFEB: .leftCommand,  // Left Command
		0xFFEC: .rightCommand,  // Right Command
		0x1008FF2B: .function
	]

	private static var charKeyMap: [UniChar: CGKeyCode] = [:]
	private static var charShiftKeyMap : [UniChar: CGKeyCode] = [:]
	private static var charControlKeyMap : [UniChar: CGKeyCode] = [:]
	private static var charOptionKeyMap : [UniChar: CGKeyCode] = [:]
	private static var charShiftOptionKeyMap: [UniChar: CGKeyCode] = [:]
	private static var keymapInitialized: Bool = false

	private var currentModifiers: NSEvent.ModifierFlags = []

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

					for i: CGKeyCode in 0..<256 {
						var deadKeyState: UInt32 = 0

						for m in 0..<modifiers.count {
							var chars: [UniChar] = [0, 0, 0, 0]
							var realLength: Int = 0
							let currentModifier = modifiers[m]

							let status = UCKeyTranslate(keyboardLayout,
										   i,
										   UInt16(kUCKeyActionDisplay),
										   UInt32(currentModifier >> 8) & 0x00FF,
										   UInt32(LMGetKbdType()),
										   UInt32(kUCKeyTranslateNoDeadKeysBit),
										   &deadKeyState,
										   chars.count,
										   &realLength,
										   &chars)

							if status == 0 {
								let unicodeChar = chars[0]
								
								switch currentModifier {
								case 0:
									if charKeyMap[unicodeChar] == nil {
										charKeyMap[unicodeChar] = i
									}
								case CGEventFlags.maskShift.rawValue:
									if charShiftKeyMap[unicodeChar] == nil {
										charShiftKeyMap[unicodeChar] = i
									}
								case CGEventFlags.maskAlternate.rawValue:
									if charOptionKeyMap[unicodeChar] == nil {
										charOptionKeyMap[unicodeChar] = i
									}
								case CGEventFlags.maskShift.rawValue | CGEventFlags.maskAlternate.rawValue:
									if charShiftOptionKeyMap[unicodeChar] == nil {
										charShiftOptionKeyMap[unicodeChar] = i
									}
								default:
									continue
								}
							} else {
								print("not found")
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
		#if DEBUG
		print("charKeyMap")
		charKeyMap.map {
			"\(CGKeyCode.characterForKeysym(UInt32($0)) ?? "\($0)") = \($1)"
		}.sorted().forEach {
			print($0)
		}

		print("charShiftKeyMap")
		charShiftKeyMap.map {
			"\(CGKeyCode.characterForKeysym(UInt32($0)) ?? "\($0)") = \($1)"
		}.sorted().forEach {
			print($0)
		}
		print("charOptionKeyMap")
		charOptionKeyMap.map {
			"\(CGKeyCode.characterForKeysym(UInt32($0)) ?? "\($0)") = \($1)"
		}.sorted().forEach {
			print($0)
		}
		print("end")
		#endif
	}

	func setupKeyMapper() throws {
		try Self.setupKeyMapper()
	}
	
	func mapVNCKey(_ vncKey: UInt32, isDown: Bool, sendKeyEvent: HandleKeyMapping) {
		// Check if it's a modifier
		if let modifier = Self.vncModifiers[vncKey] {
			let keyCode = Self.vncToMacKeyMap[vncKey]?.rawValue ?? 0

			if isDown {
				self.currentModifiers.insert(modifier)
			} else {
				self.currentModifiers.remove(modifier)
			}
			sendKeyEvent(keyCode, self.currentModifiers, nil, nil)
		} else {
			var keyMap = Self.charKeyMap
			
			if self.currentModifiers.contains(.shift) {
				keyMap = Self.charShiftKeyMap;
			}
			
			if (self.currentModifiers.contains(.shift) == false && self.currentModifiers.contains(.option)) {
				keyMap = Self.charOptionKeyMap
			}
			
			if (self.currentModifiers.contains(.shift) && self.currentModifiers.contains(.option)) {
				keyMap = Self.charShiftOptionKeyMap
			}
			
			if let keyCode = keyMap[UInt16(vncKey)] {
				sendKeyEvent(keyCode, self.currentModifiers, CGKeyCode.characterForKeysym(vncKey), CGKeyCode.characterForKeysym(vncKey))
			} else if let keyCode = CarbonKeyCode.USKeyCodes[vncKey] {
				Logger(self).debug("Fallback: key=\(vncKey.hexa), keyCode=\(keyCode)")
				
				sendKeyEvent(keyCode.rawValue, self.currentModifiers, CGKeyCode.characterForKeysym(vncKey), CGKeyCode.characterForKeysym(vncKey))
			} else {
				Logger(self).debug("Not found: key=\(vncKey.hexa)")
			}
		}
	}
}

