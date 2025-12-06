import Foundation

protocol VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> Self
}

extension Data {
	func toHexString() -> String {
		return self.map { String(format: "%02X", $0) }.joined()
	}
}

extension UInt32: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> UInt32 {
		UInt32.build(data[0], data[1], data[2], data[3])
	}
}

extension UInt32 {
	static func build(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> UInt32 {
		var value: UInt32 = 0

		withUnsafeMutableBytes(of: &value) { ptr in
			ptr[3] = a
			ptr[2] = b
			ptr[1] = c
			ptr[0] = d
		}
		
		return value
	}

	var hexa: String {
		withUnsafeBytes(of: self) { ptr in
			String(format: "%02X %02X %02X %02X", ptr[0], ptr[1], ptr[2], ptr[3])
		}
	}
}

extension Int32: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> Int32 {
		Int32.build(data[0], data[1], data[2], data[3])
	}
}

extension Int32 {
	static func build(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> Int32 {
		var value: Int32 = 0

		withUnsafeMutableBytes(of: &value) { ptr in
			ptr[3] = a
			ptr[2] = b
			ptr[1] = c
			ptr[0] = d
		}
		
		return value
	}

	var hexa: String {
		withUnsafeBytes(of: self) { ptr in
			String(format: "%02X %02X %02X %02X", ptr[0], ptr[1], ptr[2], ptr[3])
		}
	}
}

extension UInt16: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> UInt16 {
		UInt16.build(data[0], data[1])
	}
}

extension UInt16 {
	static func build(_ a: UInt8, _ b: UInt8) -> UInt16 {
		var value: UInt16 = 0

		withUnsafeMutableBytes(of: &value) { ptr in
			ptr[1] = a
			ptr[0] = b
		}
		
		return value
	}

	var hexa: String {
		withUnsafeBytes(of: self) { ptr in
			String(format: "%02X %02X", ptr[0], ptr[1])
		}
	}
}

extension Int16: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> Int16 {
		Int16.build(data[0], data[1])
	}

	static func build(_ a: UInt8, _ b: UInt8) -> Int16 {
		var value: Int16 = 0

		withUnsafeMutableBytes(of: &value) { ptr in
			ptr[1] = a
			ptr[0] = b
		}
		
		return value
	}

	var hexa: String {
		withUnsafeBytes(of: self) { ptr in
			String(format: "%02X %02X", ptr[0], ptr[1])
		}
	}
}

extension UInt8: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> UInt8 {
		data[0]
	}
}

// and any other primitives you pass to receiveDatas(...)
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

struct VNCSetEncoding: VNCLoadMessage {
	// Encoding types
	enum Encoding: Int32, Equatable {
		case rfbEncodingNone = -1
		case rfbEncodingRaw = 0
		case rfbEncodingCopyRect = 1
		case rfbEncodingRRE = 2
		case rfbEncodingCoRRE = 4
		case rfbEncodingHextile = 5
		case rfbEncodingZlib = 6
		case rfbEncodingTight = 7
		case rfbEncodingTightPng = -260
		case rfbEncodingZlibHex = 8
		case rfbEncodingUltra = 9
		case rfbEncodingZRLE = 16
		case rfbEncodingZYWRLE = 17
		case rfbEncodingXCursor = -240
		case rfbEncodingRichCursor = -239
		case rfbEncodingPointerPos = -232
		case rfbEncodingLastRect = -224
		case rfbEncodingNewFBSize = -223
		case rfbEncodingKeyboardLedState = -131072
		case rfbEncodingSupportedMessages = -131071
		case rfbEncodingSupportedEncodings = -131070
		case rfbEncodingServerIdentity = -131069
		case rfbEncodingXvp = -309
		case rfbEncodingEnableContinousUpdate = -313
		
		case appleEncoding1000 = 1000
		case appleEncoding1001 = 1001
		case appleEncoding1002 = 1002
		case appleEncoding1011 = 1011
		case appleEncoding1100 = 1100
		case appleEncoding1101 = 1101
		case appleEncoding1102 = 1102
		case appleEncoding1103 = 1103
		case appleEncoding1104 = 1104
		case appleEncoding1105 = 1105

	}

	static func load(from data: UnsafeRawBufferPointer) -> VNCSetEncoding {
		var value = VNCSetEncoding()

		value.numberOfEncodings = UInt16.build(data[1], data[2])

		return value
	}
	
	var heading: UInt8 = 0
	var numberOfEncodings: UInt16 = 0
}

struct VNCSetPixelFormat: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCSetPixelFormat {
		var value = VNCSetPixelFormat()

		value.pixelFormat = .load(from: UnsafeRawBufferPointer(rebasing: data[3...]))

		return value
	}
	
	var heading: (UInt8, UInt8, UInt8) = (0, 0, 0)
	var pixelFormat = VNCPixelFormat()
}

// Message structures
struct VNCPixelFormat: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCPixelFormat {
		var value = VNCPixelFormat()

		value.bitsPerPixel = data[0]
		value.depth = data[1]
		value.bigEndianFlag = data[2]
		value.trueColorFlag = data[3]
		value.redMax = UInt16.build(data[4], data[5])
		value.greenMax = UInt16.build(data[6], data[7])
		value.blueMax = UInt16.build(data[8], data[9])
		value.redShift = data[10]
		value.greenShift = data[11]
		value.blueShift = data[12]
		
		return value
	}
	
	var bitsPerPixel: UInt8 = 32
	var depth: UInt8 = 24
	var bigEndianFlag: UInt8 = 0
	var trueColorFlag: UInt8 = 1
	var redMax: UInt16 = UInt16(255).bigEndian
	var greenMax: UInt16 = UInt16(255).bigEndian
	var blueMax: UInt16 = UInt16(255).bigEndian
	var redShift: UInt8 = 16
	var greenShift: UInt8 = 8
	var blueShift: UInt8 = 0
	var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)

	func transform(_ imageSource: Data) -> Data {
		guard self.bigEndianFlag == 0 else {
			if self.redShift == 0 {
				return imageSource
			} else {
				var pixelData = Data(count: imageSource.count)

				imageSource.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
					pixelData.withUnsafeMutableBytes { (dstRaw: UnsafeMutableRawBufferPointer) in
						guard let sp = srcRaw.bindMemory(to: UInt32.self).baseAddress, let dp = dstRaw.bindMemory(to: UInt32.self).baseAddress else { return }
						let count = imageSource.count/4

						for i in 0..<count {
							dp[i] = sp[i].littleEndian
						}
					}
				}

				return pixelData
			}
		}

		var pixelData = Data(count: imageSource.count)
		
		imageSource.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
			pixelData.withUnsafeMutableBytes { (dstRaw: UnsafeMutableRawBufferPointer) in
				guard let sp = srcRaw.bindMemory(to: UInt8.self).baseAddress,
					  let dp = dstRaw.bindMemory(to: UInt8.self).baseAddress else { return }
				let count = imageSource.count
				var i = 0

				while i < count {
					let r = sp[i]
					let g = sp[i + 1]
					let b = sp[i + 2]
					let a = sp[i + 3]

					dp[i]     = b // B
					dp[i + 1] = g // G
					dp[i + 2] = r // R
					dp[i + 3] = a // A

					i += 4
				}
			}
		}

		return pixelData
	}
}

struct VNCServerInit {
	var framebufferWidth: UInt16 = 0
	var framebufferHeight: UInt16 = 0
	var pixelFormat = VNCPixelFormat()
}

struct VNCFramebufferUpdateMsg: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCFramebufferUpdateMsg {
		var value = VNCFramebufferUpdateMsg()

		value.messageType = data[0]
		value.padding = data[1]
		value.numberOfRectangles = UInt16.build(data[2], data[3])

		return value
	}
	
	var messageType: UInt8 = 0
	var padding: UInt8 = 0
	var numberOfRectangles: UInt16 = 0
}

struct VNCRectangle: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCRectangle {
		var value = VNCRectangle()

		value.x = UInt16.build(data[0], data[1])
		value.y = UInt16.build(data[2], data[3])
		value.width = UInt16.build(data[4], data[5])
		value.height = UInt16.build(data[6], data[7])
		value.encoding = UInt32.build(data[8], data[9], data[10], data[11])

		return value
	}
	
	var x: UInt16 = 0
	var y: UInt16 = 0
	var width: UInt16 = 0
	var height: UInt16 = 0
	var encoding: UInt32 = 0
}

struct VNCFramebufferUpdatePayload: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCFramebufferUpdatePayload {
		var value = VNCFramebufferUpdatePayload()

		value.message = VNCFramebufferUpdateMsg.load(from: UnsafeRawBufferPointer(rebasing: data[0..<4]))
		value.rectangle = VNCRectangle.load(from: UnsafeRawBufferPointer(rebasing: data[4..<data.count]))

		return value
	}
	
	var message: VNCFramebufferUpdateMsg = VNCFramebufferUpdateMsg()
	var rectangle: VNCRectangle = VNCRectangle()
}

// Client messages
struct VNCKeyEvent: VNCLoadMessage, CustomStringConvertible {
	var description: String {
		"key=\(key.hexa), down:\(downFlag)"
	}
	
	static func load(from data: UnsafeRawBufferPointer) -> VNCKeyEvent {
		var value = VNCKeyEvent()

		value.downFlag = data[0]
		value.padding = UInt16.build(data[1], data[2])
		value.key = UInt32.build(data[3], data[4], data[5], data[6])

		return value
	}
	
	var downFlag: UInt8 = 0
	var padding: UInt16 = 0
	var key: UInt32 = 0
}

struct VNCPointerEvent: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCPointerEvent {
		var value = VNCPointerEvent()

		value.buttonMask = data[0]
		value.xPosition = UInt16.build(data[1], data[2])
		value.yPosition = UInt16.build(data[3], data[4])
		
		return value
	}
	
	var buttonMask: UInt8 = 0
	var xPosition: UInt16 = 0
	var yPosition: UInt16 = 0
}

struct VNCClientCutText: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCClientCutText {
		var value = VNCClientCutText()
		
		value.textLength = UInt32.build(data[3], data[4], data[5], data[6])
		return value
	}
	
	var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
	var textLength: UInt32 = 0
}

struct VNCFramebufferUpdateRequest: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCFramebufferUpdateRequest {
		var value = VNCFramebufferUpdateRequest()

		value.incremental = data[0]
		value.x = UInt16.build(data[1], data[2])
		value.y = UInt16.build(data[3], data[4])
		value.width = UInt16.build(data[5], data[6])
		value.height = UInt16.build(data[7], data[8])

		return value
	}
	
	var incremental: UInt8 = 0
	var x: UInt16 = 0
	var y: UInt16 = 0
	var width: UInt16 = 0
	var height: UInt16 = 0
}

struct VNCFramebufferUpdateContinue: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCFramebufferUpdateContinue {
		var value = VNCFramebufferUpdateContinue()

		value.active = data[0]
		value.x = UInt16.build(data[1], data[2])
		value.y = UInt16.build(data[3], data[4])
		value.width = UInt16.build(data[5], data[6])
		value.height = UInt16.build(data[7], data[8])

		return value
	}
	
	var active: UInt8 = 0
	var x: UInt16 = 0
	var y: UInt16 = 0
	var width: UInt16 = 0
	var height: UInt16 = 0
}

struct VNCFenceClient: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCFenceClient {
		var value = VNCFenceClient()

		value.flags = UInt32.build(data[3], data[4], data[5], data[6])
		value.payloadLength = data[7]

		return value
	}
	
	var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
	var flags: UInt32 = 0
	var payloadLength: UInt8 = 0
}

struct VNCSetDesktopSize: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCSetDesktopSize {
		var value = VNCSetDesktopSize()

		value.width = UInt16.build(data[1], data[2])
		value.height = UInt16.build(data[3], data[4])
		value.numberOfScreen = data[5]

		return value
	}
	
	var padding: UInt8 = 0
	var width: UInt16 = 0
	var height: UInt16 = 0
	var numberOfScreen: UInt8 = 0
	var padding2: UInt8 = 0
}

struct VNCScreenDesktop: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCScreenDesktop {
		var value = VNCScreenDesktop()

		value.screenID = UInt32.build(data[0], data[1], data[4], data[5])
		value.posX = UInt16.build(data[6], data[7])
		value.posY = UInt16.build(data[8], data[9])
		value.width = UInt16.build(data[10], data[11])
		value.height = UInt16.build(data[12], data[13])
		value.flags = UInt32.build(data[14], data[15], data[16], data[17])

		return value
	}
	
	var screenID: UInt32 = 0
	var posX: UInt16 = 0
	var posY: UInt16 = 0
	var width: UInt16 = 0
	var height: UInt16 = 0
	var flags: UInt32 = 0
}

struct VNCQemuKeyEvent: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCQemuKeyEvent {
		var value = VNCQemuKeyEvent()

		value.downFlag = UInt16.build(data[0], data[1])
		value.keySym = UInt32.build(data[2], data[3], data[4], data[5])
		value.keyCode = UInt32.build(data[6], data[7], data[8], data[9])

		return value
	}
	
	var downFlag: UInt16 = 0
	var keySym: UInt32 = 0
	var keyCode: UInt32 = 0
}

struct VNCQemuAudioFormat: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCQemuAudioFormat {
		var value = VNCQemuAudioFormat()
		
		value.sampleFormat = data[0]
		value.numOfChannels = data[1]
		value.frequency = UInt32.build(data[2], data[3], data[4], data[5])

		return value
	}
	
	var sampleFormat: UInt8 = 0
	var numOfChannels: UInt8 = 0
	var frequency: UInt32 = 0
}

struct VNCGiiVersion: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> VNCGiiVersion {
		var value = VNCGiiVersion()
		
		value.subType = data[0]
		value.length = UInt16.build(data[1], data[2])

		return value
	}
	
	var subType: UInt8 = 0
	var length: UInt16 = 0
}

