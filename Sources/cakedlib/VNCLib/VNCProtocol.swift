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
enum VNCClientMessageType: UInt, CustomDebugStringConvertible {
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
		case .framebufferUpdateContinue:
			return "framebufferUpdateContinue"
		case .clientFence:
			return "clientFence"
		case .xvpServerMessage:
			return "xvpServerMessage"
		case .setDesktopSize:
			return "setDesktopSize"
		case .giiClientVersion:
			return "giiClientVersion"
		case .qemuClientMessage:
			return "qemuClientMessage"
		case .unknown:
			return "unknown: \(rawValue)"
		}
	}

	case unknown = 0xFFFF
	case setPixelFormat = 0
	case setEncodings = 2
	case framebufferUpdateRequest = 3
	case keyEvent = 4
	case pointerEvent = 5
	case clientCutText = 6
	case framebufferUpdateContinue = 150
	case clientFence = 248
	case xvpServerMessage = 250
	case setDesktopSize = 251
	case giiClientVersion = 253
	case qemuClientMessage = 255

	init(rawValue: UInt8) {
		switch rawValue {
		case 0: self = .setPixelFormat
		case 2: self = .setEncodings
		case 3: self = .framebufferUpdateRequest
		case 4: self = .keyEvent
		case 5: self = .pointerEvent
		case 6: self = .clientCutText
		case 150: self = .framebufferUpdateContinue
		case 248: self = .clientFence
		case 250: self = .xvpServerMessage
		case 251: self = .setDesktopSize
		case 253: self = .giiClientVersion
		case 255: self = .qemuClientMessage
		default:
			Logger("VNCClientMessageType").error("Unknown raw value: \(rawValue)")
			self = .unknown
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

struct VNCSetEncoding {
	var heading: UInt8 = 0
	var numberOfEncodings: UInt16 = 0
}

// Message structures
public struct VNCPixelFormat {
	public var heading: (UInt8, UInt8, UInt8) = (0, 0, 0)
	public var bitsPerPixel: UInt8 = 32
	public var depth: UInt8 = 24
	public var bigEndianFlag: UInt8 = 0
	public var trueColorFlag: UInt8 = 1
	public var redMax: UInt16 = UInt16(255).bigEndian
	public var greenMax: UInt16 = UInt16(255).bigEndian
	public var blueMax: UInt16 = UInt16(255).bigEndian
	public var redShift: UInt8 = 0
	public var greenShift: UInt8 = 8
	public var blueShift: UInt8 = 16
	public var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
}

struct VNCServerInit {
	var framebufferWidth: UInt16 = 0
	var framebufferHeight: UInt16 = 0
	var pixelFormat = VNCPixelFormat()
}

public struct VNCFramebufferUpdateMsg {
	public var messageType: UInt8 = 0
	public var padding: UInt8 = 0
	public var numberOfRectangles: UInt16 = 0
}

struct VNCRectangle {
	var x: UInt16 = 0
	var y: UInt16 = 0
	var width: UInt16 = 0
	var height: UInt16 = 0
	var encoding: UInt32 = 0
}

struct VNCFramebufferUpdatePayload {
	var message: VNCFramebufferUpdateMsg = VNCFramebufferUpdateMsg()
	var rectangle: VNCRectangle = VNCRectangle()
}

// Client messages
struct VNCKeyEvent {
	var downFlag: UInt8 = 0
	var padding: UInt16 = 0
	var key: UInt32 = 0
}

struct VNCPointerEvent {
	var buttonMask: UInt8 = 0
	var xPosition: UInt16 = 0
	var yPosition: UInt16 = 0
}

struct VNCFramebufferUpdateRequest {
	var incremental: UInt8 = 0
	var x: UInt16 = 0
	var y: UInt16 = 0
	var width: UInt16 = 0
	var height: UInt16 = 0
}

struct VNCFramebufferUpdateContinue {
	var active: UInt8 = 0
	var x: UInt16 = 0
	var y: UInt16 = 0
	var width: UInt16 = 0
	var height: UInt16 = 0
}

struct VNCFenceClient {
	public var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
	public var flags: UInt32 = 0
	public var payloadLength: UInt8 = 0
}

struct VNCSetDesktopSize {
	public var padding: UInt8 = 0
	public var width: UInt16 = 0
	public var height: UInt16 = 0
	public var numberOfScreen: UInt8 = 0
	public var padding2: UInt8 = 0
}

struct VNCScreenDesktop {
	public var screenID: UInt32 = 0
	public var posX: UInt16 = 0
	public var posY: UInt16 = 0
	public var width: UInt16 = 0
	public var height: UInt16 = 0
	public var flags: UInt32 = 0
}

struct VNCQemuKeyEvent {
	public var downFlag: UInt16 = 0
	public var keySym: UInt32 = 0
	public var keyCode: UInt32 = 0
}
