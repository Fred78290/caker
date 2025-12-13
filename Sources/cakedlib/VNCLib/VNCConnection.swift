import CommonCrypto
import CryptoKit
import Foundation
import Network
import Semaphore
import System

extension [UInt8] {
	mutating func rfbSetBit(_ position: Int) {
		self[(position & 0xFF) / 8] |= (1 << (position % 8))
	}
}

private let kNotEnoughDataError = NSError(domain: "VNCConnectionError", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Not enough data"])

protocol VNCConnectionDelegate: AnyObject {
	func vncConnectionResizeDesktop(_ connection: VNCConnection, screens: [VNCScreenDesktop])
	func vncConnectionDidDisconnect(_ connection: VNCConnection, clientAddress: String)
	func vncConnection(_ connection: VNCConnection, didReceiveError error: Error)
}

protocol VNCInputDelegate: AnyObject {
	func vncConnection(_ connection: VNCConnection, didReceiveKeyEvent key: UInt32, isDown: Bool)
	func vncConnection(_ connection: VNCConnection, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8)
}

struct SetEncoding {
	var preferredEncoding: VNCSetEncoding.Encoding = .rfbEncodingNone
	var useCopyRect: Bool = false
	var useNewFBSize: Bool = false
	var useExtDesktopSize: Bool = false
	var cursorWasChanged: Bool = false
	var cursorWasMoved: Bool = false
	var useRichCursorEncoding: Bool = false
	var enableCursorPosUpdates: Bool = false
	var enableCursorShapeUpdates: Bool = false
	var enableLastRectEncoding: Bool = false
	var enableKeyboardLedState: Bool = false
	var enableSupportedMessages: Bool = false
	var enableSupportedEncodings: Bool = false
	var enableServerIdentity: Bool = false
	var enableContinousUpdate: Bool = false
	var appleVNCEncoding: Bool = false
}

final class VNCConnection: @unchecked Sendable {
	weak var delegate: VNCConnectionDelegate?
	weak var inputDelegate: VNCInputDelegate?
	var sendFramebufferContinous: Bool = false {
		didSet {
			self.logger.debug("sendFramebufferContinous: \(self.sendFramebufferContinous)")
		}
	}
	
	internal var newFBSizePending = false
	internal var connectionState: NWConnection.State {
		self.connection.state
	}
	
	private let connection: NWConnection
	private let framebuffer: VNCFramebuffer
	private let inputHandler: VNCInputHandler
	private var isAuthenticated = false
	private var clientAddress: String = ""
	private let connectionQueue = DispatchQueue(label: "vnc.connection")
	private var authChallenge: Data!
	private let vncPassword: String?
	private var majorVersion: Int = 3
	private var minorVersion: Int = 8
	private let logger = Logger("VNCConnection")
	private let name: String
	private var clientPixelFormat: VNCPixelFormat
	private var encodings = SetEncoding()
	private var translatePixelFormat: ClientTranslatePixelFormat = rfbTranslateNone
	private var translateLookupTable: [[any FixedWidthInteger]] = [[]]
	private var messageClientStream: AsyncStream<VNCClientMessageType>!
	private var messageClientContinuation: AsyncStream<VNCClientMessageType>.Continuation!
	
	// VNC Auth constants
	private static let VNC_AUTH_NONE: UInt32 = 1
	private static let VNC_AUTH_VNC: UInt32 = 2
	private static let VNC_AUTH_OK: UInt32 = 0
	private static let VNC_AUTH_FAILED: UInt32 = 1
	
	init(_ name: String, connection: NWConnection, framebuffer: VNCFramebuffer, password: String? = nil) {
		self.name = name
		self.connection = connection
		self.framebuffer = framebuffer
		self.inputHandler = VNCInputHandler(targetView: framebuffer.sourceView)
		self.vncPassword = password
		self.clientPixelFormat = framebuffer.pixelFormat
		
		if case .hostPort(let host, _) = connection.endpoint {
			self.clientAddress = "\(host)"
		}
	}
	
	func start() {
		self.messageClientStream = AsyncStream() { continuation in
			self.messageClientContinuation = continuation
		}
		
		connection.stateUpdateHandler = { [weak self] state in
			self?.logger.debug("Connection state: \(state)")
			
			switch state {
			case .ready:
				Task {
					do {
						try await self?.handleInitialHandshake()
					} catch {
						self?.logger.logger.error("Failed to complete initial handshake: \(error)")
						self?.didReceiveError(error)
						self?.disconnect()
						
						return
					}

					do {
						try await self?.pollClientMessage()
					} catch {
						self?.logger.logger.error("Failed to handle client messages: \(error)")
						self?.didReceiveError(error)
						self?.disconnect()
					}
				}

			case .cancelled, .failed:
				self?.handleDisconnection()
			default:
				break
			}
		}
		
		connection.start(queue: connectionQueue)
	}
	
	func disconnect() {
		connection.cancel()
	}
	
	private func transformPixel(_ pixelData: Data, width: Int, height: Int) -> Data {
		return self.translatePixelFormat(self.translateLookupTable, self.clientPixelFormat, pixelData, width * 4, width, height)
		
		//return framebuffer.convertToClient(state.data, clientFormat: self.clientPixelFormat)
	}
	
	private func setClientColourMapBGR233() async throws {
		var data = Data(count: MemoryLayout<VNCSetColourMapEntries>.size + (256 * 3 * 2))
		
		data.withUnsafeMutableBytes { ptr in
			guard let message = ptr.bindMemory(to: VNCSetColourMapEntries.self).baseAddress else {
				return
			}
			
			message.pointee = VNCSetColourMapEntries()
			
			guard var ptr = ptr.bindMemory(to: UInt16.self).baseAddress else {
				return
			}
			
			ptr = ptr.advanced(by: MemoryLayout<VNCSetColourMapEntries>.size / 2)
			
			for b in 0..<4 {
				for g in 0..<8 {
					for r in 0..<8 {
						ptr.initialize(to: UInt16(r * 65535 / 7).bigEndian)
						ptr.initialize(to: UInt16(g * 65535 / 7).bigEndian)
						ptr.initialize(to: UInt16(b * 65535 / 7).bigEndian)
						ptr = ptr.advanced(by: 3)
					}
				}
			}
		}
		
		try await self.sendDatas(data)
		try await self.receiveAuthenticationChoice()
	}
	
	private func setClientPixelFormat(_ pixelFormat: VNCPixelFormat) async throws {
		var pixelFormat = pixelFormat
		
		guard pixelFormat.bitsPerPixel == 32 || pixelFormat.bitsPerPixel == 16 || pixelFormat.bitsPerPixel == 8 else {
			throw ServiceError("Unsupported pixel format")
		}
		
		if pixelFormat.trueColorFlag == 0 {
			guard pixelFormat.bitsPerPixel == 8 else {
				throw ServiceError("Unsupported pixel format")
			}
			
			try await setClientColourMapBGR233()
			
			pixelFormat = VNCPixelFormat(bitsPerPixel: 8, depth: 8, bigEndianFlag: 0, trueColorFlag: 1, redMax: 7, greenMax: 7, blueMax: 3, redShift: 0, greenShift: 3, blueShift: 6)
		}
		
		let serverPixelFormat = framebuffer.getPixelFormat()
		
		guard pixelFormat == serverPixelFormat else {
			if serverPixelFormat.bitsPerPixel <= 16 {
				self.translatePixelFormat = rfbTranslateWithSingleTableFns[Int(serverPixelFormat.bitsPerPixel/16)][Int(pixelFormat.bitsPerPixel/16)]
				self.translateLookupTable = rfbInitTrueColourSingleTableFns[Int(pixelFormat.bitsPerPixel / 16)](serverPixelFormat, pixelFormat);
			} else {
				self.translatePixelFormat = rfbTranslateWithRGBTablesFns[Int(serverPixelFormat.bitsPerPixel/16)][Int(pixelFormat.bitsPerPixel/16)]
				self.translateLookupTable = rfbInitTrueColourRGBTablesFns[Int(pixelFormat.bitsPerPixel / 16)](serverPixelFormat, pixelFormat);
			}
			
			self.clientPixelFormat = pixelFormat
			return
		}
		
		self.clientPixelFormat = pixelFormat
		self.translatePixelFormat = rfbTranslateNone
	}
	
	private func handleInitialHandshake() async throws {
		// Send RFB protocol version
		try await self.sendDatas("RFB 003.008\n".data(using: .ascii)!)
		try await self.receiveClientVersion()
	}
	
	@discardableResult
	private func handleError(_ error: NWError?) -> Bool {
		if let error = error {
			self.logger.error(error)
			self.didReceiveError(error)
			self.disconnect()
			return false
		}
		
		return true
	}
	
	private func validateVNCAuthResponse(_ response: Data) -> Bool {
		guard let password = vncPassword, let challenge = self.authChallenge else {
			return false
		}
		
		// Prepare password (pad with zeros to 8 bytes, truncate if longer)
		var passwordBytes = Array(password.utf8)
		passwordBytes = Array(passwordBytes.prefix(8))
		while passwordBytes.count < 8 {
			passwordBytes.append(0)
		}
		
		// VNC uses DES with bit-reversed key
		let reversedKey = passwordBytes.map { reverseBits($0) }
		
		// Encrypt challenge with DES
		let expectedResponse = desEncrypt(data: challenge, key: Data(reversedKey))
		
		self.logger.debug("Validating VNC authentication received response: \(response.toHexString())")
		self.logger.debug("Validating VNC authentication expected response: \(expectedResponse.toHexString())")
		
		return expectedResponse == response
	}
	
	private func reverseBits(_ byte: UInt8) -> UInt8 {
		var result: UInt8 = 0
		var input = byte
		for _ in 0..<8 {
			result = (result << 1) | (input & 1)
			input >>= 1
		}
		return result
	}
	
	private func desEncrypt(data: Data, key: Data) -> Data {
		let keyBytes = [UInt8](key)
		let dataBytes = [UInt8](data)
		var outputBytes = [UInt8](repeating: 0, count: data.count)
		
		let keyLength = kCCKeySizeDES
		let algorithm = CCAlgorithm(kCCAlgorithmDES)
		let options = CCOptions(kCCOptionECBMode)
		
		var numBytesEncrypted = 0
		
		let cryptStatus = CCCrypt(
			CCOperation(kCCEncrypt),
			algorithm,
			options,
			keyBytes, keyLength,
			nil,  // IV
			dataBytes, data.count,
			&outputBytes, data.count,
			&numBytesEncrypted
		)
		
		guard cryptStatus == kCCSuccess else {
			return Data()
		}
		
		return Data(outputBytes.prefix(numBytesEncrypted))
	}
	
	private func didReceiveError(_ error: Error) {
		if let delegate = self.delegate {
			DispatchQueue.main.async {
				delegate.vncConnection(self, didReceiveError: error)
			}
		}
	}
	
	private func handleDisconnection() {
		if let delegate = self.delegate {
			DispatchQueue.main.async {
				delegate.vncConnectionDidDisconnect(self, clientAddress: self.clientAddress)
			}
		}
	}
	
	private func setDesktopSize(_ screens: [VNCScreenDesktop]) {
		if let delegate = self.delegate {
			DispatchQueue.main.async {
				delegate.vncConnectionResizeDesktop(self, screens: screens)
			}
		}
	}
}

// MARK: - Client auth negotation
extension VNCConnection {
	private func receiveClientVersion() async throws {
		let value = try await self.receiveDatas(ofType: UInt8.self, countOf: 12)

		if let versionString = String(bytes: value, encoding: .ascii) {
			// Parse client version (format: "RFB MMM.mmm\n")
			let trimmedVersion = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
			
			if trimmedVersion.hasPrefix("RFB ") {
				let versionPart = String(trimmedVersion.dropFirst(4))  // Remove "RFB "
				let components = versionPart.components(separatedBy: ".")
				
				if components.count == 2, let majorVersion = Int(components[0]), let minorVersion = Int(components[1]) {
					self.majorVersion = majorVersion
					self.minorVersion = minorVersion
					
					self.logger.debug("VNC Client version: \(self.majorVersion).\(self.minorVersion)")
					
					// Check if we support this version (we support 3.3, 3.7, 3.8)
					if self.majorVersion == 3 && (self.minorVersion == 3 || self.minorVersion == 7 || self.minorVersion == 8) {
						// Version is supported, proceed with authentication
						try await self.sendAuthenticationMethods()
					} else {
						// Unsupported version
						throw NSError(domain: "VNCConnectionError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Unsupported VNC version: \(majorVersion).\(minorVersion)"])
					}
				} else {
					// Invalid version format
					throw NSError(domain: "VNCConnectionError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Invalid version format: \(versionPart)"])
				}
			} else {
				// Not a valid RFB protocol string
				throw NSError(domain: "VNCConnectionError", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Invalid RFB protocol string: \(trimmedVersion)"])
			}
		} else {
			throw NSError(domain: "VNCConnectionError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid client version format"])
		}
	}
	
	private func sendAuthenticationMethods() async throws {
		self.logger.debug("Sending authentication methods for VNC \(majorVersion).\(minorVersion)")
		
		// VNC 3.3 uses a different authentication protocol format
		if majorVersion == 3 && minorVersion == 3 {
			try await sendAuthenticationForVersion33()
		} else {
			// VNC 3.7+ uses the standard authentication list format
			try await sendAuthenticationForVersion37Plus()
		}
	}
	
	private func sendAuthenticationForVersion33() async throws {
		// VNC 3.3: Server decides authentication type, no list sent
		if vncPassword == nil {
			// Send AUTH_NONE directly (4 bytes, big endian)
			let authType: UInt32 = Self.VNC_AUTH_NONE.bigEndian
			
			try await self.sendDatas(authType)
			try await self.receiveClientInit()
		} else {
			// Send AUTH_VNC directly (4 bytes, big endian)
			let authType: UInt32 = Self.VNC_AUTH_VNC.bigEndian
			
			try await self.sendDatas(authType)
			try await self.sendVNCAuthChallenge()
		}
	}
	
	private func sendAuthenticationForVersion37Plus() async throws {
		// Send authentication type list
		let authData: [UInt8] = [1, vncPassword == nil ? UInt8(Self.VNC_AUTH_NONE) : UInt8(Self.VNC_AUTH_VNC)]

		try await self.sendDatas(authData)
		try await self.receiveAuthenticationChoice()
	}
	
	private func receiveClientInit() async throws {
		// Receive ClientInit message (1 byte: shared flag)
		let sharedFlag = try await self.receiveDatas(ofType: UInt8.self)

		self.logger.debug("ClientInit received \(sharedFlag) starting VNC session")
		
		// Send ServerInit and start receiving client messages
		try await self.sendServerInit()
	}
	
	private func receiveAuthenticationChoice() async throws {
		// Only used for VNC 3.7+ where client chooses from authentication list
		let authType = try await self.receiveDatas(ofType: UInt8.self)

		self.logger.debug("Client chose authentication type: \(authType)")
		
		if authType == UInt8(Self.VNC_AUTH_NONE) {
			// No authentication - proceed to authentication result
			try await self.sendAuthenticationResult(success: true)
		} else if authType == UInt8(Self.VNC_AUTH_VNC) {
			// VNC authentication - send challenge
			try await self.sendVNCAuthChallenge()
		} else {
			// Unsupported authentication type
			self.logger.error("Client requested unsupported authentication type: \(authType)")
			try await self.sendAuthenticationResult(success: false)
		}
	}
	
	private func sendVNCAuthChallenge() async throws {
		// Generate 16-byte random challenge
		self.authChallenge = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
		
		self.logger.debug("Sending VNC authentication challenge: \(authChallenge.toHexString())")
		
		try await self.sendDatas(self.authChallenge!)
		try await self.receiveVNCAuthResponse()
	}
	
	private func receiveVNCAuthResponse() async throws {
		let value = try await self.receiveDatas(ofType: UInt8.self, countOf: 16)

		try await self.sendAuthenticationResult(success: self.validateVNCAuthResponse(Data(value)))
	}
	
	private func sendAuthenticationResult(success: Bool) async throws {
		self.logger.debug("Sending authentication result: \(success ? "SUCCESS" : "FAILED")")
		
		// VNC 3.3+: Always send authentication result
		let result: UInt32 = success ? Self.VNC_AUTH_OK.bigEndian : Self.VNC_AUTH_FAILED.bigEndian
		
		try await self.sendDatas(result)
		if success {
			try await self.receiveClientInit()
		} else {
			if self.majorVersion == 3 && self.minorVersion < 8 {
				self.disconnect()
			} else {
				// Send failure reason (mandatory in 3.7+)
				let reasonData = "Authentication failed - invalid credentials".data(using: .utf8)!
				let reasonLength = UInt32(reasonData.count).bigEndian
				
				try await self.sendDatas(reasonLength)
				try await self.sendDatas(reasonData)

				self.disconnect()
			}
		}
	}
	
	private func sendServerInit() async throws {
		var serverInit = VNCServerInit()
		let nameData = self.name.data(using: .utf8)!
		let nameLength = UInt32(nameData.count).bigEndian
		
		serverInit.framebufferWidth = UInt16(framebuffer.width).bigEndian
		serverInit.framebufferHeight = UInt16(framebuffer.height).bigEndian
		serverInit.pixelFormat = self.clientPixelFormat.bigEndian

		try await self.sendDatas(serverInit)
		try await self.sendDatas(nameLength)
		try await self.sendDatas(nameData)

		self.isAuthenticated = true
		self.receiveClientMessages()

		self.logger.debug("Send server init")
	}
}

// MARK: - Receive client message
extension VNCConnection {
	private func receiveClientMessages() {
		self.logger.trace("Poll client message")
		
		self.receiveDatas(ofType: UInt8.self) { result in
			if case let .success(type) = result {
				self.messageClientContinuation.yield(VNCClientMessageType(rawValue: type))
			} else if case let .failure(error) = result {
				self.logger.error("Failed to receive client message type: \(error)")
				self.messageClientContinuation.finish()
			}
		}
	}
	
	private func pollClientMessage() async throws {
		self.logger.trace("Poll client message")

		if let messageClientStream {
			do {
				for await message in messageClientStream {
					try await self.handleClientMessage(message)
				}
			} catch {
				self.logger.error("Failed to handle client message: \(error)")
				self.didReceiveError(error)
				self.disconnect()
			}
		}
	}

	private func handleClientMessage(_ messageType: VNCClientMessageType) async throws {
		if messageType != .keyEvent && messageType != .pointerEvent && messageType != .framebufferUpdateRequest {
			self.logger.debug("Handle client message: \(messageType.debugDescription )")
		}
		
		switch messageType {
		case .setPixelFormat:
			try await self.receiveSetPixelFormat()
		case .setEncodings:
			try await self.receiveSetEncodings()
		case .framebufferUpdateRequest:
			try await self.receiveFramebufferUpdateRequest()
		case .keyEvent:
			try await self.receiveKeyEvent()
		case .pointerEvent:
			try await self.receivePointerEvent()
		case .clientCutText:
			try await self.receiveClientCutText()
		case .framebufferUpdateContinue:
			try await self.receiveFramebufferUpdateContinue()
		case .clientFence:
			try await self.receiveClientFence()
		case .xvpServerMessage:
			try await self.receiveXVPServerMessage()
		case .setDesktopSize:
			try await self.receiveSetDesktopSize()
		case .giiClientVersion:
			try await self.receiveGIIClientVersion()
		case .qemuClientMessage:
			try await self.receiveQemuClientMessage()
		default:
			break
		}

		self.receiveClientMessages()
	}
		
	private func receiveSetPixelFormat() async throws {
		let value = try await self.receiveDatas(ofType: VNCSetPixelFormat.self, dataLength: 19)

		self.logger.debug("Client set pixel format: \(value)")
		try await self.setClientPixelFormat(value.pixelFormat)
	}
	
	private func receiveSetEncodings() async throws {
		let value = try await self.receiveDatas(ofType: VNCSetEncoding.self, dataLength: 3)
		let values = try await self.receiveDatas(ofType: Int32.self, countOf: Int(value.numberOfEncodings))
		var setEncoding = SetEncoding()

		self.logger.debug("Client set encoding: \(values)")

		values.forEach {
			if let encoding = VNCSetEncoding.Encoding(rawValue: Int32($0)) {
				self.logger.debug("Client encoding: \(encoding)")
				
				switch encoding {
				case .rfbEncodingCopyRect:
					setEncoding.useCopyRect = true;
					break;
				case .rfbEncodingRaw, .rfbEncodingRRE, .rfbEncodingCoRRE, .rfbEncodingHextile, .rfbEncodingUltra, .rfbEncodingZlib, .rfbEncodingZRLE, .rfbEncodingZYWRLE, .rfbEncodingTight, .rfbEncodingTightPng, .rfbEncodingZlibHex:
					if setEncoding.preferredEncoding == .rfbEncodingNone {
						setEncoding.preferredEncoding = encoding
					}
				case .rfbEncodingXCursor:
					setEncoding.enableCursorShapeUpdates = true
					setEncoding.cursorWasChanged = true
				case .rfbEncodingRichCursor:
					setEncoding.enableCursorShapeUpdates = true
					setEncoding.useRichCursorEncoding = true
					setEncoding.cursorWasChanged = true
				case .rfbEncodingPointerPos:
					setEncoding.enableCursorPosUpdates = true
					setEncoding.cursorWasMoved = true
				case .rfbEncodingLastRect:
					setEncoding.enableLastRectEncoding = true
				case .rfbEncodingNewFBSize:
					setEncoding.useNewFBSize = true
				case .rfbEncodingExtDesktopSize:
					setEncoding.useNewFBSize = true
					setEncoding.useExtDesktopSize = true
				case .rfbEncodingKeyboardLedState:
					setEncoding.enableKeyboardLedState = true
				case .rfbEncodingSupportedMessages:
					setEncoding.enableSupportedMessages = true
				case .rfbEncodingSupportedEncodings:
					setEncoding.enableSupportedEncodings = true
				case .rfbEncodingServerIdentity:
					setEncoding.enableServerIdentity = true
				case .rfbEncodingEnableContinousUpdate:
					setEncoding.enableContinousUpdate = true
					//default: break
				case .rfbEncodingNone:
					break
				case .rfbEncodingXvp:
					break
				case .appleEncoding1000:
					setEncoding.appleVNCEncoding = true
				case .appleEncoding1001:
					setEncoding.appleVNCEncoding = true
				case .appleEncoding1002:
					setEncoding.appleVNCEncoding = true
				case .appleEncoding1011:
					setEncoding.appleVNCEncoding = true
				case .appleEncoding1100:
					setEncoding.appleVNCEncoding = true
				case .appleEncoding1101:
					setEncoding.appleVNCEncoding = true
				case .appleEncoding1102:
					setEncoding.appleVNCEncoding = true
				case .appleEncoding1103:
					setEncoding.appleVNCEncoding = true
				case .appleEncoding1104:
					setEncoding.appleVNCEncoding = true
				case .appleEncoding1105:
					setEncoding.appleVNCEncoding = true
				}
			}
		}
		
		self.encodings = setEncoding
		
		if setEncoding.enableContinousUpdate || setEncoding.appleVNCEncoding {
			self.logger.debug("enable continous frame update")
		}
		
		if (setEncoding.enableCursorPosUpdates && setEncoding.enableCursorShapeUpdates == false) {
			setEncoding.enableCursorPosUpdates = false
		}
		
		if setEncoding.preferredEncoding == .rfbEncodingNone {
			setEncoding.preferredEncoding = .rfbEncodingRaw
		}
		
		if setEncoding.enableContinousUpdate {
			try await self.sendDatas(Data(repeating: 150, count: 1))
		}
	}
	
	private func receiveFramebufferUpdateRequest() async throws {
		let value = try await self.receiveDatas(ofType: VNCFramebufferUpdateRequest.self, dataLength: 9)

		self.logger.trace("Client request update: \(value)")
		if self.encodings.useExtDesktopSize && value.incremental == 0 {
			self.newFBSizePending = true
		}

		// Send framebuffer update
		try await self.sendFramebufferUpdateThrowing()
	}
	
	private func receiveFramebufferUpdateContinue() async throws {
		let value = try await self.receiveDatas(ofType: VNCFramebufferUpdateContinue.self, dataLength: 9)

		self.sendFramebufferContinous = value.active != 0
		
		self.logger.debug("Client request update continue: \(value)")

		if value.active == 0 {
			try await self.sendDatas(Data(repeating: 150, count: 1))
		}
	}
	
	private func receiveKeyEvent() async throws {
		let value = try await self.receiveDatas(ofType: VNCKeyEvent.self, dataLength: 7)

		self.logger.debug("Client send key event: \(value.description)")
		let down = value.downFlag != 0
		
		DispatchQueue.main.async {
			self.inputHandler.handleKeyEvent(key: value.key, isDown: down)
			self.inputDelegate?.vncConnection(self, didReceiveKeyEvent: value.key, isDown: value.downFlag != 0)
		}
	}
	
	private func receivePointerEvent() async throws {
		let value = try await self.receiveDatas(ofType: VNCPointerEvent.self, dataLength: 5)

		self.logger.trace("Client send pointer event: \(value)")

		DispatchQueue.main.async {
			self.inputHandler.handlePointerEvent(x: Int(value.xPosition), y: Int(value.yPosition), buttonMask: value.buttonMask)
			self.inputDelegate?.vncConnection(self, didReceiveMouseEvent: Int(value.xPosition), y: Int(value.yPosition), buttonMask: value.buttonMask)
		}
	}
	
	private func receiveClientCutText() async throws {
		let value = try await self.receiveDatas(ofType: VNCClientCutText.self, dataLength: 7)
		let values = try await self.receiveDatas(ofType: UInt8.self, countOf: Int(value.textLength))
		let text = String(decoding: values, as: Unicode.UTF8.self)

		self.logger.debug("Client send cut text: \(text)")

		DispatchQueue.main.async {
			self.inputHandler.handleClipboardText(text)
		}
	}
	
	private func receiveClientFence() async throws {
		let value = try await self.receiveDatas(ofType: VNCFenceClient.self, dataLength: 9)
		let values = try await self.receiveDatas(ofType: UInt8.self, countOf: Int(value.payloadLength))

		self.logger.debug("Client send fence: \(value)")
		self.logger.debug("fences: \(values)")
	}
	
	private func receiveXVPServerMessage() async throws {
		let value = try await self.receiveDatas(ofType: UInt8.self, countOf: 3)
		
		self.logger.debug("XVP server message: \(value)")
	}
	
	private func receiveSetDesktopSize() async throws {
		let value = try await self.receiveDatas(ofType: VNCSetDesktopSize.self, dataLength: 7)

		self.logger.debug("Client set desktop size: \(value)")

		let screens = try await self.receiveDatas(ofType: VNCScreenDesktop.self, countOf: Int(value.numberOfScreen))
		self.logger.debug("desktops: \(screens)")

		self.setDesktopSize(screens)
	}
	
	private func receiveGIIClientVersion() async throws {
		let version = try await self.receiveDatas(ofType: VNCGiiVersion.self, dataLength: 3)
		let values = try await self.receiveDatas(ofType: UInt8.self, countOf: Int(version.length))

		self.logger.debug("Gii payload: \(values)")
	}
	
	private func receiveQemuClientMessage() async throws {
		let value = try await self.receiveDatas(ofType: UInt8.self)

		self.logger.debug("Client qemu message: \(value)")
		
		if value == 0 {
			let values = try await self.receiveDatas(ofType: VNCQemuKeyEvent.self)
			
			self.logger.debug("Client qemu key event: \(values)")
		} else {
			if try await self.receiveDatas(ofType: UInt16.self) == 2 {
				let audio = try await self.receiveDatas(ofType: VNCQemuAudioFormat.self)

				self.logger.debug("Client qemu audio format: \(audio)")
			}
		}
	}
	
}

// MARK: - Send server message
extension VNCConnection {
	func sendNewFBSize(width: UInt16, height: UInt16) async throws {
		self.logger.debug("sendNewFBSize: \(width)x\(height)")
		var payload = VNCFramebufferUpdatePayload()

		payload.message.messageType = 0  // VNC_MSG_FRAMEBUFFER_UPDATE
		payload.message.padding = 0
		payload.message.numberOfRectangles = UInt16(1).bigEndian
		
		payload.rectangle.x = 0
		payload.rectangle.y = 0
		payload.rectangle.width = UInt16(width).bigEndian
		payload.rectangle.height = UInt16(height).bigEndian
		payload.rectangle.encoding = VNCSetEncoding.Encoding.rfbEncodingNewFBSize.rawValue.bigEndian

		try await self.sendDatas(payload)
	}

	private func sendExDesktopSize(width: UInt16, height: UInt16) async throws {
		self.logger.debug("sendExDesktopSize: \(width)x\(height)")
		var payload = VNCFramebufferUpdatePayload()
		var message = VNCExtDesktopSizeMessage()

		payload.message.messageType = 0  // VNC_MSG_FRAMEBUFFER_UPDATE
		payload.message.padding = 0
		payload.message.numberOfRectangles = UInt16(1).bigEndian

		payload.rectangle.x = 0
		payload.rectangle.y = 0
		payload.rectangle.width = UInt16(width).bigEndian
		payload.rectangle.height = UInt16(height).bigEndian
		payload.rectangle.encoding = VNCSetEncoding.Encoding.rfbEncodingExtDesktopSize.rawValue.bigEndian

		message.numOfScreens = 1
		message.screen.height = height.bigEndian
		message.screen.width = width.bigEndian

		try await self.sendDatas(payload)
		try await self.sendDatas(message)
	}

	private func sendUpdateBuffer(_ pixelData: Data, width: Int, height: Int) async throws {
		let pixelData = transformPixel(pixelData, width: width, height: height)
		var payload = VNCFramebufferUpdatePayload()
		
		payload.message.messageType = 0  // VNC_MSG_FRAMEBUFFER_UPDATE
		payload.message.padding = 0
		payload.message.numberOfRectangles = UInt16(1).bigEndian
		
		payload.rectangle.x = 0
		payload.rectangle.y = 0
		payload.rectangle.width = UInt16(width).bigEndian
		payload.rectangle.height = UInt16(height).bigEndian
		payload.rectangle.encoding = 0
		
		try await self.sendDatas(payload)
		try await self.sendDatas(pixelData)
		
		if self.encodings.enableContinousUpdate && self.sendFramebufferContinous == false {
			self.sendFramebufferContinous = true
		}
	}

	func sendFramebufferUpdateThrowing() async throws {
		if isAuthenticated && self.connection.state == .ready {
			var sendSupportedMessages = false
			var sendSupportedEncodings = false
			let state = await framebuffer.getCurrentState()

			if self.encodings.enableSupportedEncodings {
				sendSupportedEncodings = true
				self.encodings.enableSupportedEncodings = false
			}

			if self.encodings.enableSupportedMessages {
				sendSupportedMessages = true
				self.encodings.enableSupportedMessages = false
			}

			if self.newFBSizePending && self.encodings.useNewFBSize {
				self.newFBSizePending = false
				
				if self.encodings.useExtDesktopSize {
					try await sendExDesktopSize(width: UInt16(state.width), height: UInt16(state.height))
				} else {
					try await sendNewFBSize(width: UInt16(state.width), height: UInt16(state.height))
				}
			}
			
			try await sendUpdateBuffer(state.data, width: state.width, height: state.height)

			if sendSupportedMessages {
				try await self.sendSupportedMessages()
			}

			if sendSupportedEncodings {
				try await self.sendSupportedEncodings()
			}
		}
	}

	func sendFramebufferNewSize() async {
		self.newFBSizePending = true
		await self.sendFramebufferUpdate()
	}

	func sendFramebufferUpdate() async {
		if isAuthenticated && self.connection.state == .ready {
			do {
				try await self.sendFramebufferUpdateThrowing()
			} catch {
				self.logger.error("send framebuffer failed error: \(error)")
				self.didReceiveError(error)
				self.disconnect()
			}
		}
	}

	func sendSupportedMessages() async throws {
		self.logger.debug("sendSupportedMessages")

		var payload = VNCFramebufferUpdatePayload()
		var client2server: [UInt8] = Array(repeating: 0, count: 32); /* maximum of 256 message types (256/8)=32 */
		var server2client: [UInt8] = Array(repeating: 0, count: 32); /* maximum of 256 message types (256/8)=32 */
		
		payload.message.messageType = 0  // VNC_MSG_FRAMEBUFFER_UPDATE
		payload.message.padding = 0
		payload.message.numberOfRectangles = UInt16(1).bigEndian

		payload.rectangle.x = 0
		payload.rectangle.y = 0
		payload.rectangle.width = UInt16(64).bigEndian
		payload.rectangle.height = 0
		payload.rectangle.encoding = VNCSetEncoding.Encoding.rfbEncodingSupportedMessages.rawValue.bigEndian
		
		client2server.rfbSetBit(Int(VNCClientMessageType.setPixelFormat.rawValue))
		client2server.rfbSetBit(Int(VNCClientMessageType.setEncodings.rawValue))
		client2server.rfbSetBit(Int(VNCClientMessageType.framebufferUpdateRequest.rawValue))
		client2server.rfbSetBit(Int(VNCClientMessageType.keyEvent.rawValue))
		client2server.rfbSetBit(Int(VNCClientMessageType.pointerEvent.rawValue))
		client2server.rfbSetBit(Int(VNCClientMessageType.clientCutText.rawValue))
		client2server.rfbSetBit(Int(VNCClientMessageType.setDesktopSize.rawValue))

		server2client.rfbSetBit(Int(VNCServerMessageType.rfbFramebufferUpdate.rawValue))
		server2client.rfbSetBit(Int(VNCServerMessageType.rfbResizeFrameBuffer.rawValue))
		
		try await self.sendDatas(payload)
		try await self.sendDatas(client2server)
		try await self.sendDatas(server2client)
	}

	func sendSupportedEncodings() async throws {
		self.logger.debug("sendSupportedEncodings")

		var payload = VNCFramebufferUpdatePayload()
		let supportedEncoding: [Int32] = [
			VNCSetEncoding.Encoding.rfbEncodingRaw.rawValue.bigEndian,
			VNCSetEncoding.Encoding.rfbEncodingNewFBSize.rawValue.bigEndian,
			VNCSetEncoding.Encoding.rfbEncodingExtDesktopSize.rawValue.bigEndian,
			VNCSetEncoding.Encoding.rfbEncodingSupportedMessages.rawValue.bigEndian,
			VNCSetEncoding.Encoding.rfbEncodingSupportedEncodings.rawValue.bigEndian,
		]

		payload.message.messageType = 0  // VNC_MSG_FRAMEBUFFER_UPDATE
		payload.message.padding = 0
		payload.message.numberOfRectangles = UInt16(1).bigEndian

		payload.rectangle.x = 0
		payload.rectangle.y = 0
		payload.rectangle.width = UInt16(supportedEncoding.count * 4).bigEndian
		payload.rectangle.height = UInt16(supportedEncoding.count).bigEndian
		payload.rectangle.encoding = VNCSetEncoding.Encoding.rfbEncodingSupportedEncodings.rawValue.bigEndian

		try await self.sendDatas(payload)
		try await self.sendDatas(supportedEncoding)
	}
}

// MARK: - Sync Network data Handlers
extension VNCConnection {
	private func sendDatas<T>(_ data: [T], completion: @escaping (_ error: NWError?) -> Void) {
		var msg = Data(count: MemoryLayout<T>.size * data.count)
		
		msg.withUnsafeMutableBytes { rawBuffer in
			guard let base = rawBuffer.bindMemory(to: T.self).baseAddress else {
				return
			}
			let buffer = UnsafeMutableBufferPointer(start: base, count: data.count)
			_ = buffer.initialize(from: data)
		}
		
		self.sendDatas(msg, completion: completion)
	}


	func sendDatas<T>(_ data: T, completion: @escaping (_ error: NWError?) -> Void) {
		var msg = Data(count: MemoryLayout<T>.size)
		
		msg.withUnsafeMutableBytes { ptr in
			ptr.bindMemory(to: T.self).baseAddress!.pointee = data
		}

		self.sendDatas(msg, completion: completion)
	}

	func sendDatas(_ data: Data, completion: @escaping (_ error: NWError?) -> Void) {
		if self.connection.state == .ready {
			self.connection.send(content: data, completion: .contentProcessed { completion($0) })
		} else {
			completion(NWError.posix(.EADDRNOTAVAIL))
		}
	}
	
	private func receiveDatas<T: VNCLoadMessage>(ofType: T.Type, countOf: Int, dataLength: Int = MemoryLayout<T>.size, _ completion: @escaping (Result<[T], Error>) -> Void) {
		self.connection.receive(minimumIncompleteLength: countOf * dataLength, maximumLength: countOf * dataLength) { [weak self] data, _, _, error in
			guard let self = self else { return }
			
			if self.handleError(error) {
				if let data = data, data.count >= dataLength {
					var values: [T] = []
					values.reserveCapacity(countOf)
					
					data.withUnsafeBytes { ptr in
						for offset in 0..<countOf {
							let start = offset * dataLength
							let end = start + dataLength
							
							values.append(T.load(from: UnsafeRawBufferPointer(rebasing: ptr[start..<end])))
						}
					}
					
					completion(.success(values))
				} else {
					self.didReceiveError(kNotEnoughDataError)
					self.disconnect()
					completion(.failure(kNotEnoughDataError))
				}
			} else {
				completion(.failure(error!))
			}
		}
	}
	
	private func receiveDatas<T : VNCLoadMessage>(ofType: T.Type, dataLength: Int = MemoryLayout<T>.size, _ completion: @escaping (Result<T, Error>) -> Void) {
		self.connection.receive(minimumIncompleteLength: dataLength, maximumLength: dataLength) { [weak self] data, _, _, error in
			guard let self = self else { return }
			
			if self.handleError(error) {
				if let data = data, data.count >= dataLength {
					let value = data.withUnsafeBytes { ptr in
						T.load(from: ptr)
					}
					
					completion(.success(value))
				} else {
					self.didReceiveError(kNotEnoughDataError)
					self.disconnect()
					completion(.failure(kNotEnoughDataError))
				}
			} else {
				completion(.failure(error!))
			}
		}
	}
	
}

// MARK: - Async Network data Handlers
extension VNCConnection {
	private func sendDatas<T>(_ data: [T]) async throws {
		var msg = Data(count: MemoryLayout<T>.size * data.count)
		
		msg.withUnsafeMutableBytes { rawBuffer in
			guard let base = rawBuffer.bindMemory(to: T.self).baseAddress else {
				return
			}
			let buffer = UnsafeMutableBufferPointer(start: base, count: data.count)
			_ = buffer.initialize(from: data)
		}
		
		try await sendDatas(msg)
	}

	private func sendDatas<T>(_ data: T) async throws {
		var msg = Data(count: MemoryLayout<T>.size)
		
		msg.withUnsafeMutableBytes { ptr in
			ptr.bindMemory(to: T.self).baseAddress!.pointee = data
		}
		
		try await sendDatas(msg)
	}

	private func sendDatas(_ data: Data) async throws {
		if self.connection.state == .ready {
			// Use an AsyncStream to await completion of the send
			let stream = AsyncStream<NWError?> { continuation in
				self.connection.send(content: data, completion: .contentProcessed { error in
					continuation.yield(error)
					continuation.finish()
				})
			}

			// Await the first (and only) event signaling send completion
			for await error in stream {
				if let error {
					throw error
				}
				
				break
			}
		} else {
			throw NWError.posix(.EADDRNOTAVAIL)
		}
	}

	private func receiveDatas<T: VNCLoadMessage>(ofType: T.Type, countOf: Int, dataLength: Int = MemoryLayout<T>.size) async throws -> [T] {
		let stream = AsyncStream<Result<[T], Error>>() { continuation in
			self.connection.receive(minimumIncompleteLength: countOf * dataLength, maximumLength: countOf * dataLength) { [weak self] data, _, _, error in
				guard let self = self else { return }
				var result: Result<[T], Error>

				if self.handleError(error) {
					if let data = data, data.count >= dataLength {
						var values: [T] = []
						values.reserveCapacity(countOf)
						
						data.withUnsafeBytes { ptr in
							for offset in 0..<countOf {
								let start = offset * dataLength
								let end = start + dataLength
								
								values.append(T.load(from: UnsafeRawBufferPointer(rebasing: ptr[start..<end])))
							}
						}
						
						result = .success(values)
					} else {
						result = .failure(kNotEnoughDataError)
					}
				} else {
					result = .failure(error!)
				}

				continuation.yield(result)
				continuation.finish()
			}
		}

		for await result in stream {
			if case let .success(result) = result {
				return result
			} else if case let .failure(error) = result {
				throw error
			}
		}
		
		throw kNotEnoughDataError
	}

	private func receiveDatas<T: VNCLoadMessage>(ofType: T.Type, dataLength: Int = MemoryLayout<T>.size) async throws -> T {
		let stream = AsyncStream<Result<T, Error>>() { continuation in
			self.connection.receive(minimumIncompleteLength: dataLength, maximumLength: dataLength) { [weak self] data, _, _, error in
				guard let self = self else { return }
				var result: Result<T, Error>

				if self.handleError(error) {
					if let data = data, data.count >= dataLength {
						let value = data.withUnsafeBytes { ptr in
							T.load(from: ptr)
						}
						
						result = .success(value)
					} else {
						result = .failure(kNotEnoughDataError)
					}
				} else {
					result = .failure(error!)
				}
				
				continuation.yield(result)
				continuation.finish()
			}
		}

		for await result in stream {
			if case let .success(result) = result {
				return result
			} else if case let .failure(error) = result {
				throw error
			}
		}
		
		throw kNotEnoughDataError
	}
}
