import Foundation

// Authentication types
enum VNCAuthType: UInt32, CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .invalid:
            return "invalid"
        case .none:
            return "none"
        case .vnc:
            return "vnc"
        }
    }

    case invalid = 0
    case none = 1
    case vnc = 2
}

// Server message types
enum VNCServerMessageType: UInt8, CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .framebufferUpdate:
            return "framebufferUpdate"
        case .setColorMapEntries:
            return "setColorMapEntries"
        case .bell:
            return "bell"
        case .serverCutText:
            return "serverCutText"
        case .unknown:
            return "unknown"
        }
    }

    case unknown = 255
    case framebufferUpdate = 0
    case setColorMapEntries = 1
    case bell = 2
    case serverCutText = 3

    init(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .framebufferUpdate
        case 1: self = .setColorMapEntries
        case 2: self = .bell
        case 3: self = .serverCutText
        default: self = .unknown
        }
    }
}

// Client message types
enum VNCClientMessageType: UInt8, CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .setPixelFormat:
            return "setPixelFormat"
        case .setEncodings:
            return "setEncodings"
        case .framebufferUpdateRequest:
            return "framebufferUpdateRequest"
        case .keyEvent:
            return "keyEvent"
        case .pointerEvent:
            return "pointerEvent"
        case .clientCutText:
            return "clientCutText"
        case .unknown:
            return "unknown"
        }
    }

    case unknown = 255
    case setPixelFormat = 0
    case setEncodings = 2
    case framebufferUpdateRequest = 3
    case keyEvent = 4
    case pointerEvent = 5
    case clientCutText = 6

    init(rawValue: UInt8) {
        switch rawValue { 
        case 0: self = .setPixelFormat
        case 2: self = .setEncodings
        case 3: self = .framebufferUpdateRequest
        case 4: self = .keyEvent
        case 5: self = .pointerEvent
        case 6: self = .clientCutText
        default: self = .unknown
        }
    }
}

// Encoding types
enum VNCEncoding: UInt32, CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .raw:
            return "raw"
        case .copyRect:
            return "copyRect"
        case .rre:
            return "rre"
        case .hextile:
            return "hextile"
        }
    }

    case raw = 0
    case copyRect = 1
    case rre = 2
    case hextile = 5
}

// Message structures
struct VNCPixelFormat {
    var bitsPerPixel: UInt8 = 0
    var depth: UInt8 = 0
    var bigEndianFlag: UInt8 = 0
    var trueColorFlag: UInt8 = 0
    var redMax: UInt16 = 0
    var greenMax: UInt16 = 0
    var blueMax: UInt16 = 0
    var redShift: UInt8 = 0
    var greenShift: UInt8 = 0
    var blueShift: UInt8 = 0
    var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
}

struct VNCServerInit {
    var framebufferWidth: UInt16 = 0
    var framebufferHeight: UInt16 = 0
    var pixelFormat = VNCPixelFormat()
}

struct VNCFramebufferUpdateMsg {
    var messageType: UInt8 = 0
    var padding: UInt8 = 0
    var numberOfRectangles: UInt16 = 0
}

struct VNCRectangle {
    var x: UInt16 = 0
    var y: UInt16 = 0
    var width: UInt16 = 0
    var height: UInt16 = 0
    var encoding: UInt32 = 0
}

// Client messages
struct VNCKeyEvent {
    var messageType: UInt8 = 4
    var downFlag: UInt8 = 0
    var padding: UInt16 = 0
    var key: UInt32 = 0
}

struct VNCPointerEvent {
    var messageType: UInt8 = 5
    var buttonMask: UInt8 = 0
    var xPosition: UInt16 = 0
    var yPosition: UInt16 = 0
}

struct VNCFramebufferUpdateRequest {
    var messageType: UInt8 = 3
    var incremental: UInt8 = 0
    var x: UInt16 = 0
    var y: UInt16 = 0
    var width: UInt16 = 0
    var height: UInt16 = 0
}
