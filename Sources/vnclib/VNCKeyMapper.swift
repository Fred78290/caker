import Foundation
import AppKit
import Carbon

public class VNCKeyMapper {
    
    // Mapping des touches VNC vers les key codes macOS
    private let vncToMacKeyMap: [UInt32: UInt16] = [
        // Letters
        0x0061: UInt16(kVK_ANSI_A),      // a
        0x0062: UInt16(kVK_ANSI_S),      // b -> s (QWERTY to AZERTY)
        0x0063: UInt16(kVK_ANSI_D),      // c -> d
        0x0064: UInt16(kVK_ANSI_F),      // d -> f
        0x0065: UInt16(kVK_ANSI_H),      // e -> h
        0x0066: UInt16(kVK_ANSI_G),      // f -> g
        0x0067: UInt16(kVK_ANSI_Y),      // g -> y
        0x0068: UInt16(kVK_ANSI_H),      // h
        0x0069: UInt16(kVK_ANSI_U),      // i -> u
        0x006A: UInt16(kVK_ANSI_J),      // j
        0x006B: UInt16(kVK_ANSI_K),      // k
        0x006C: UInt16(kVK_ANSI_L),      // l
        0x006D: UInt16(kVK_ANSI_M),      // m
        0x006E: UInt16(kVK_ANSI_N),      // n
        0x006F: UInt16(kVK_ANSI_O),      // o
        0x0070: UInt16(kVK_ANSI_P),      // p
        0x0071: UInt16(kVK_ANSI_Q),      // q
        0x0072: UInt16(kVK_ANSI_R),      // r
        0x0073: UInt16(kVK_ANSI_S),      // s
        0x0074: UInt16(kVK_ANSI_T),      // t
        0x0075: UInt16(kVK_ANSI_U),      // u
        0x0076: UInt16(kVK_ANSI_V),      // v
        0x0077: UInt16(kVK_ANSI_W),      // w
        0x0078: UInt16(kVK_ANSI_X),      // x
        0x0079: UInt16(kVK_ANSI_Y),      // y
        0x007A: UInt16(kVK_ANSI_Z),      // z
        
        // Numbers
        0x0030: UInt16(kVK_ANSI_0),      // 0
        0x0031: UInt16(kVK_ANSI_1),      // 1
        0x0032: UInt16(kVK_ANSI_2),      // 2
        0x0033: UInt16(kVK_ANSI_3),      // 3
        0x0034: UInt16(kVK_ANSI_4),      // 4
        0x0035: UInt16(kVK_ANSI_5),      // 5
        0x0036: UInt16(kVK_ANSI_6),      // 6
        0x0037: UInt16(kVK_ANSI_7),      // 7
        0x0038: UInt16(kVK_ANSI_8),      // 8
        0x0039: UInt16(kVK_ANSI_9),      // 9
        
        // Special keys
        0xFF08: UInt16(kVK_Delete),       // Backspace
        0xFF09: UInt16(kVK_Tab),          // Tab
        0xFF0D: UInt16(kVK_Return),       // Return
        0xFF1B: UInt16(kVK_Escape),       // Escape
        0x0020: UInt16(kVK_Space),        // Space
        
        // Function keys
        0xFFBE: UInt16(kVK_F1),           // F1
        0xFFBF: UInt16(kVK_F2),           // F2
        0xFFC0: UInt16(kVK_F3),           // F3
        0xFFC1: UInt16(kVK_F4),           // F4
        0xFFC2: UInt16(kVK_F5),           // F5
        0xFFC3: UInt16(kVK_F6),           // F6
        0xFFC4: UInt16(kVK_F7),           // F7
        0xFFC5: UInt16(kVK_F8),           // F8
        0xFFC6: UInt16(kVK_F9),           // F9
        0xFFC7: UInt16(kVK_F10),          // F10
        0xFFC8: UInt16(kVK_F11),          // F11
        0xFFC9: UInt16(kVK_F12),          // F12
        
        // Arrows
        0xFF51: UInt16(kVK_LeftArrow),    // Left
        0xFF52: UInt16(kVK_UpArrow),      // Up
        0xFF53: UInt16(kVK_RightArrow),   // Right
        0xFF54: UInt16(kVK_DownArrow),    // Down
        
        // Navigation keys
        0xFF50: UInt16(kVK_Home),         // Home
        0xFF57: UInt16(kVK_End),          // End
        0xFF55: UInt16(kVK_PageUp),       // Page Up
        0xFF56: UInt16(kVK_PageDown),     // Page Down
        
        // Modifiers
        0xFFE1: UInt16(kVK_Shift),        // Left Shift
        0xFFE2: UInt16(kVK_RightShift),   // Right Shift
        0xFFE3: UInt16(kVK_Control),      // Left Control
        0xFFE4: UInt16(kVK_RightControl), // Right Control
        0xFFE9: UInt16(kVK_Option),       // Left Alt
        0xFFEA: UInt16(kVK_RightOption),  // Right Alt
        0xFFEB: UInt16(kVK_Command),      // Left Command
        0xFFEC: UInt16(kVK_RightCommand), // Right Command
        
        // Numeric keypad
        0xFF9C: UInt16(kVK_ANSI_Keypad0), // Keypad 0
        0xFF9D: UInt16(kVK_ANSI_Keypad1), // Keypad 1
        0xFF9E: UInt16(kVK_ANSI_Keypad2), // Keypad 2
        0xFF9F: UInt16(kVK_ANSI_Keypad3), // Keypad 3
        0xFFA0: UInt16(kVK_ANSI_Keypad4), // Keypad 4
        0xFFA1: UInt16(kVK_ANSI_Keypad5), // Keypad 5
        0xFFA2: UInt16(kVK_ANSI_Keypad6), // Keypad 6
        0xFFA3: UInt16(kVK_ANSI_Keypad7), // Keypad 7
        0xFFA4: UInt16(kVK_ANSI_Keypad8), // Keypad 8
        0xFFA5: UInt16(kVK_ANSI_Keypad9), // Keypad 9
        
        // Punctuation
        0x002E: UInt16(kVK_ANSI_Period),     // .
        0x002C: UInt16(kVK_ANSI_Comma),      // ,
        0x003B: UInt16(kVK_ANSI_Semicolon),  // ;
        0x0027: UInt16(kVK_ANSI_Quote),      // '
        0x005B: UInt16(kVK_ANSI_LeftBracket), // [
        0x005D: UInt16(kVK_ANSI_RightBracket), // ]
        0x005C: UInt16(kVK_ANSI_Backslash),  // \
        0x002F: UInt16(kVK_ANSI_Slash),      // /
        0x002D: UInt16(kVK_ANSI_Minus),      // -
        0x003D: UInt16(kVK_ANSI_Equal),      // =
        0x0060: UInt16(kVK_ANSI_Grave)       // `
    ]
    
    // Mapping des modificateurs VNC vers NSEvent.ModifierFlags
    private let vncModifiers: [UInt32: NSEvent.ModifierFlags] = [
        0xFFE1: .shift,         // Left Shift
        0xFFE2: .shift,         // Right Shift
        0xFFE3: .control,       // Left Control
        0xFFE4: .control,       // Right Control
        0xFFE9: .option,        // Left Alt
        0xFFEA: .option,        // Right Alt
        0xFFEB: .command,       // Left Command
        0xFFEC: .command        // Right Command
    ]
    
    func mapVNCKey(_ vncKey: UInt32) -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String) {
        // Check if it's a modifier
        if let modifier = vncModifiers[vncKey] {
            let keyCode = vncToMacKeyMap[vncKey] ?? 0
            return (keyCode: keyCode, modifiers: modifier, characters: "")
        }
        
        // Map main key
        let keyCode = vncToMacKeyMap[vncKey] ?? 0
        let characters = characterForVNCKey(vncKey)
        
        return (keyCode: keyCode, modifiers: [], characters: characters)
    }
    
    private func characterForVNCKey(_ vncKey: UInt32) -> String {
        // Convert VNC codes to characters
        if vncKey >= 0x20 && vncKey <= 0x7E {
            // ASCII printable characters
            if let scalar = UnicodeScalar(vncKey) {
                return String(Character(scalar))
            }
        }
        
        // Special characters
        switch vncKey {
        case 0xFF08: return "\u{8}"     // Backspace
        case 0xFF09: return "\t"        // Tab
        case 0xFF0D: return "\r"        // Return
        case 0xFF1B: return "\u{1B}"    // Escape
        case 0x0020: return " "         // Space
        default: return ""
        }
    }
}