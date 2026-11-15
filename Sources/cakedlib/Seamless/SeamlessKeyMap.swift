import Foundation

/// macOS virtual key codes (`NSEvent.keyCode`, ANSI positions) to Linux evdev codes.
///
/// Keys are sent by physical position, so the guest compositor's keyboard layout has to match the host's;
/// translating characters instead is what an input-method aware protocol would add later.
public enum SeamlessKeyMap {
	public static func evdev(forMacKeyCode code: UInt16) -> UInt32? {
		table[code]
	}

	/// Modifier keys, reported by `flagsChanged`: pressed state can't be told from the event's keyCode alone.
	public static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62]

	private static let table: [UInt16: UInt32] = [
		// Letters
		0: 30, 11: 48, 8: 46, 2: 32, 14: 18, 3: 33, 5: 34, 4: 35, 34: 23, 38: 36, 40: 37, 37: 38, 46: 50,
		45: 49, 31: 24, 35: 25, 12: 16, 15: 19, 1: 31, 17: 20, 32: 22, 9: 47, 13: 17, 7: 45, 16: 21, 6: 44,
		// Digits
		18: 2, 19: 3, 20: 4, 21: 5, 23: 6, 22: 7, 26: 8, 28: 9, 25: 10, 29: 11,
		// Punctuation
		27: 12, 24: 13, 33: 26, 30: 27, 41: 39, 39: 40, 50: 41, 42: 43, 43: 51, 47: 52, 44: 53,
		// Editing and whitespace
		36: 28, 48: 15, 49: 57, 51: 14, 53: 1, 117: 111,
		// Modifiers (left/right)
		55: 125, 54: 126, 56: 42, 60: 54, 58: 56, 61: 100, 59: 29, 62: 97, 57: 58,
		// Navigation
		123: 105, 124: 106, 125: 108, 126: 103, 115: 102, 119: 107, 116: 104, 121: 109,
		// Function keys
		122: 59, 120: 60, 99: 61, 118: 62, 96: 63, 97: 64, 98: 65, 100: 66, 101: 67, 109: 68, 103: 87, 111: 88,
		// Keypad
		82: 82, 83: 79, 84: 80, 85: 81, 86: 75, 87: 76, 88: 77, 89: 71, 91: 72, 92: 73, 65: 83, 67: 55, 69: 78, 78: 74, 75: 98, 76: 96,
	]
}
