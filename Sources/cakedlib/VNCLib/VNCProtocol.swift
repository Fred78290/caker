import Foundation

// Authentication types
enum VNCAuthType: UInt32 {
    case invalid = 0
    case none = 1
    case vnc = 2
}

// Server message types
enum VNCServerMessageType: UInt8 {
    case framebufferUpdate = 0
    case setColorMapEntries = 1
    case bell = 2
    case serverCutText = 3
}

// Client message types
enum VNCClientMessageType: UInt8 {
    case setPixelFormat = 0
    case setEncodings = 2
    case framebufferUpdateRequest = 3
    case keyEvent = 4
    case pointerEvent = 5
    case clientCutText = 6
}

// Encoding types
enum VNCEncoding: UInt32 {
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