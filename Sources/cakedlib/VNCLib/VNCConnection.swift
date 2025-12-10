import CommonCrypto
import CryptoKit
import Foundation
import Network
import Semaphore
import System

private let kNotEnoughDataError = NSError(domain: "VNCConnectionError", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Not enough data"])

protocol VNCConnectionDelegate: AnyObject {
	func vncConnectionDidDisconnect(_ connection: VNCConnection, clientAddress: String)
	func vncConnection(_ connection: VNCConnection, didReceiveError error: Error)
}

protocol VNCInputDelegate: AnyObject {
	func vncConnection(_ connection: VNCConnection, didReceiveKeyEvent key: UInt32, isDown: Bool)
	func vncConnection(_ connection: VNCConnection, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8)
}

final class VNCConnection: @unchecked Sendable {
	weak var delegate: VNCConnectionDelegate?
	weak var inputDelegate: VNCInputDelegate?
	var sendFramebufferContinous: Bool = false {
		didSet {
			self.logger.debug("sendFramebufferContinous: \(self.sendFramebufferContinous)")
		}
	}

	var connectionState: NWConnection.State {
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

	// VNC Auth constants
	private static let VNC_AUTH_NONE: UInt32 = 1
	private static let VNC_AUTH_VNC: UInt32 = 2
	private static let VNC_AUTH_OK: UInt32 = 0
	private static let VNC_AUTH_FAILED: UInt32 = 1

	struct SetEncoding {
		var preferredEncoding: VNCSetEncoding.Encoding = .rfbEncodingNone
		var useCopyRect: Bool = false
		var useNewFBSize: Bool = false
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
		connection.stateUpdateHandler = { [weak self] state in
			self?.logger.debug("Connection state: \(state)")

			switch state {
			case .ready:
				self?.handleInitialHandshake()
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

	private func setClientColourMapBGR233() -> Bool {
		var data = Data(count: MemoryLayout<VNCSetColourMapEntries>.size + (256 * 3 * 2))
		var result = data.withUnsafeMutableBytes { ptr in
			guard let message = ptr.bindMemory(to: VNCSetColourMapEntries.self).baseAddress else {
				return false
			}

			message.pointee = VNCSetColourMapEntries()

			guard var ptr = ptr.bindMemory(to: UInt16.self).baseAddress else {
				return false
			}

			ptr = ptr.advanced(by: MemoryLayout<VNCSetColourMapEntries>.size)
			
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

			return true
		}

		if result {
			let semaphore = DispatchSemaphore(value: 1)
			
			self.sendDatas(data) { [weak self] error in
				guard let self = self else { return }

				if self.handleError(error) {
					self.receiveAuthenticationChoice()
				} else {
					result = false
				}
				
				semaphore.signal()
			}

			semaphore.wait()
		}

		return result
	}

	private func setClientPixelFormat(_ pixelFormat: VNCPixelFormat) -> Bool {
		var pixelFormat = pixelFormat

		guard pixelFormat.bitsPerPixel == 32 || pixelFormat.bitsPerPixel == 16 || pixelFormat.bitsPerPixel == 8 else {
			return false
		}

		if pixelFormat.trueColorFlag == 0 {
			guard pixelFormat.bitsPerPixel == 8 else {
				return false
			}

			guard setClientColourMapBGR233() else {
				return false
			}

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

			return true
		}

		self.clientPixelFormat = pixelFormat
		self.translatePixelFormat = rfbTranslateNone

		return true
	}

	private func handleInitialHandshake() {
		// Send RFB protocol version
		let version = "RFB 003.008\n"
		let versionData = version.data(using: .ascii)!

		connection.send(
			content: versionData,
			completion: .contentProcessed { [weak self] error in
				if let self = self {
					if let error = error {
						self.didReceiveError(error)
						return
					}
					self.receiveClientVersion()
				}
			})
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

	private func receiveClientVersion() {
		self.receiveDatas(ofType: UInt8.self, countOf: 12) { result in
			if case let .success(data) = result {
				if let versionString = String(bytes: data, encoding: .ascii) {
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
								self.sendAuthenticationMethods()
							} else {
								// Unsupported version
								self.didReceiveError(NSError(domain: "VNCConnectionError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Unsupported VNC version: \(majorVersion).\(minorVersion)"]))
								self.disconnect()
							}
						} else {
							// Invalid version format
							self.didReceiveError(NSError(domain: "VNCConnectionError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Invalid version format: \(versionPart)"]))
							self.disconnect()
						}
					} else {
						// Not a valid RFB protocol string
						self.didReceiveError(NSError(domain: "VNCConnectionError", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Invalid RFB protocol string: \(trimmedVersion)"]))
						self.disconnect()
					}
				} else {
					self.didReceiveError(NSError(domain: "VNCConnectionError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid client version format"]))
					self.disconnect()
				}
			} else if case let .failure(error) = result{
				self.logger.error("Failed to receive client version: \(error)")
			}
		}
	}

	private func sendAuthenticationMethods() {
		self.logger.debug("Sending authentication methods for VNC \(majorVersion).\(minorVersion)")

		// VNC 3.3 uses a different authentication protocol format
		if majorVersion == 3 && minorVersion == 3 {
			sendAuthenticationForVersion33()
		} else {
			// VNC 3.7+ uses the standard authentication list format
			sendAuthenticationForVersion37Plus()
		}
	}

	private func sendAuthenticationForVersion33() {
		// VNC 3.3: Server decides authentication type, no list sent
		if vncPassword == nil {
			// Send AUTH_NONE directly (4 bytes, big endian)
			var authType: UInt32 = Self.VNC_AUTH_NONE.bigEndian
			let authData = Data(bytes: &authType, count: 4)

			connection.send(
				content: authData,
				completion: .contentProcessed { [weak self] error in
					if error == nil {
						// For AUTH_NONE in 3.3, proceed directly to client init
						self?.receiveClientInit()
					}
				})
		} else {
			// Send AUTH_VNC directly (4 bytes, big endian)
			var authType: UInt32 = Self.VNC_AUTH_VNC.bigEndian
			let authData = Data(bytes: &authType, count: 4)

			connection.send(
				content: authData,
				completion: .contentProcessed { [weak self] error in
					if error == nil {
						// For AUTH_VNC in 3.3, send challenge immediately
						self?.sendVNCAuthChallenge()
					}
				})
		}
	}

	private func sendAuthenticationForVersion37Plus() {
		// Send authentication type list
		var authData = Data(count: 2)
		
		authData.withUnsafeMutableBytes { authData in
			guard let ptr = authData.bindMemory(to: UInt8.self).baseAddress else {
				return
			}
			
			ptr[0] = 1
			ptr[1] = vncPassword == nil ? UInt8(Self.VNC_AUTH_NONE) : UInt8(Self.VNC_AUTH_VNC)
 		}

		self.sendDatas(authData) { [weak self] error in
			guard let self = self else { return }

			if self.handleError(error) {
				self.receiveAuthenticationChoice()
			}
		}
	}

	private func receiveClientInit() {
		// Receive ClientInit message (1 byte: shared flag)
		self.receiveDatas(ofType: UInt8.self) { result in
			if case let .success(sharedFlag) = result {
				self.logger.debug("ClientInit received \(sharedFlag) starting VNC session")
				
				// Send ServerInit and start receiving client messages
				self.sendServerInit()
			} else if case let .failure(error) = result {
				self.logger.error("Error parsing ClientInit: \(error)")
				self.connection.cancel()
			}
		}
	}

	private func receiveAuthenticationChoice() {
		// Only used for VNC 3.7+ where client chooses from authentication list
		self.receiveDatas(ofType: UInt8.self) { result in
			if case let .success(authType) = result {
				self.logger.debug("Client chose authentication type: \(authType)")

				if authType == UInt8(Self.VNC_AUTH_NONE) {
					// No authentication - proceed to authentication result
					self.sendAuthenticationResult(success: true)
				} else if authType == UInt8(Self.VNC_AUTH_VNC) {
					// VNC authentication - send challenge
					self.sendVNCAuthChallenge()
				} else {
					// Unsupported authentication type
					self.logger.error("Client requested unsupported authentication type: \(authType)")
					self.sendAuthenticationResult(success: false)
				}
			} else if case let .failure(error) = result {
				self.logger.error("Failed to receive authentication choice: \(error)")
				self.connection.cancel()
			}
		}
	}

	private func sendVNCAuthChallenge() {
		// Generate 16-byte random challenge
		self.authChallenge = Data((0..<16).map { _ in UInt8.random(in: 0...255) })

		self.logger.debug("Sending VNC authentication challenge: \(authChallenge.toHexString())")

		self.sendDatas(self.authChallenge!) { [weak self] error in
			guard let self = self else { return }

			if self.handleError(error) {
				self.receiveVNCAuthResponse()
			}
		}
	}

	private func receiveVNCAuthResponse() {
		self.receiveDatas(ofType: UInt8.self, countOf: 16) { result in
			if case let .success(value) = result {
				self.sendAuthenticationResult(success: self.validateVNCAuthResponse(Data(value)))
			} else if case let .failure(error) = result {
				self.logger.error("Failed to receive authentication response: \(error)")
			}
		}
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

	private func sendAuthenticationResult(success: Bool) {
		self.logger.debug("Sending authentication result: \(success ? "SUCCESS" : "FAILED")")

		// VNC 3.3+: Always send authentication result
		var result: UInt32 = success ? Self.VNC_AUTH_OK.bigEndian : Self.VNC_AUTH_FAILED.bigEndian
		let resultData = Data(bytes: &result, count: 4)

		self.sendDatas(resultData) { [weak self] error in
			guard let self: VNCConnection = self else { return }

			if self.handleError(error) {
				if success {
				// Authentication successful - wait for ClientInit
					self.receiveClientInit()
				} else {
					if self.majorVersion == 3 && self.minorVersion < 8 {
						self.disconnect()
					} else {
						// Send failure reason (mandatory in 3.7+)
						let reason = "Authentication failed - invalid credentials"
						let reasonData = reason.data(using: .utf8)!
						var reasonLength = UInt32(reasonData.count).bigEndian
						var failureData = Data()

						failureData.append(Data(bytes: &reasonLength, count: 4))
						failureData.append(reasonData)

						self.sendDatas(failureData) { [weak self] error in
							self?.disconnect()
						}
					}
				}
			} else {
				self.disconnect()
			}
		}
	}

	private func sendServerInit() {
		var serverInit = VNCServerInit()
		let nameData = self.name.data(using: .utf8)!
		var nameLength = UInt32(nameData.count).bigEndian
		var initData = Data()

		serverInit.framebufferWidth = UInt16(framebuffer.width).bigEndian
		serverInit.framebufferHeight = UInt16(framebuffer.height).bigEndian
		serverInit.pixelFormat = self.clientPixelFormat.bigEndian

		initData.append(Data(bytes: &serverInit, count: MemoryLayout<VNCServerInit>.size))
		initData.append(Data(bytes: &nameLength, count: 4))
		initData.append(nameData)

		self.sendDatas(initData) { [weak self] error in
			guard let self = self else { return }

			if self.handleError(error) {
				self.isAuthenticated = true
				self.receiveClientMessages()
				self.logger.debug("Send server init")
			} else {
				self.logger.debug("Send server init failed")
			}
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

	private func receiveDatas<T: VNCLoadMessage>(dataLength: Int = MemoryLayout<T>.size) async -> Result<T, Error> {
		let semaphore = AsyncSemaphore(value: 0)
		var result: Result<T, Error> = .failure(NSError(domain: "VNCConnectionError", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Not enough data"]))

		self.connection.receive(minimumIncompleteLength: dataLength, maximumLength: dataLength) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data, data.count >= dataLength {
					let value = data.withUnsafeBytes { ptr in
						return ptr.load(as: T.self)
					}
					
					result = .success(value)
				} else {
					result = .failure(kNotEnoughDataError)
				}
			} else {
				result = .failure(error!)
			}
			
			semaphore.signal()
		}
		
		await semaphore.wait()
		
		if case .failure(let error) = result {
			self.didReceiveError(error)
			self.disconnect()
		}

		return result
	}

	private func receiveClientMessages() {
		self.logger.trace("Poll client message")

		self.receiveDatas(ofType: UInt8.self) { result in
			if case let .success(type) = result {
				self.handleClientMessage(VNCClientMessageType(rawValue: type))
			} else if case let .failure(error) = result {
				self.logger.error("Failed to receive client message type: \(error)")
			}
		}
	}

	private func handleClientMessage(_ messageType: VNCClientMessageType) {
		if messageType != .keyEvent && messageType != .pointerEvent && messageType != .framebufferUpdateRequest {
			self.logger.debug("Handle client message: \(messageType.debugDescription )")
		}

		switch messageType {
		case .setPixelFormat:
			self.receiveSetPixelFormat()
		case .setEncodings:
			self.receiveSetEncodings()
		case .framebufferUpdateRequest:
			self.receiveFramebufferUpdateRequest()
		case .keyEvent:
			self.receiveKeyEvent()
		case .pointerEvent:
			self.receivePointerEvent()
		case .clientCutText:
			self.receiveClientCutText()
		case .framebufferUpdateContinue:
			self.receiveFramebufferUpdateContinue()
		case .clientFence:
			self.receiveClientFence()
		case .xvpServerMessage:
			self.receiveXVPServerMessage()
		case .setDesktopSize:
			self.receiveSetDesktopSize()
		case .giiClientVersion:
			self.receiveGIIClientVersion()
		case .qemuClientMessage:
			self.receiveQemuClientMessage()
		default:
			self.receiveClientMessages()
		}
	}

	// MARK: - Message Handlers

	private func receiveSetPixelFormat() {
		self.receiveDatas(ofType: VNCSetPixelFormat.self, dataLength: 19) { result in
			if case let .success(value) = result {
				self.logger.debug("Client set pixel format: \(value)")
				if self.setClientPixelFormat(value.pixelFormat) {
					self.receiveClientMessages()
				} else {
					self.disconnect()
				}
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read VNC pixel format: \(error)")
			}
		}
	}

	private func receiveSetEncodings() {
		self.receiveDatas(ofType: VNCSetEncoding.self, dataLength: 3) { result in
			if case let .success(value) = result {
				self.receiveDatas(ofType: Int32.self, countOf: Int(value.numberOfEncodings)) { result in
					if case let .success(values) = result {
						self.logger.debug("Client set encoding: \(values)")
						var setEncoding = SetEncoding()

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
							self.sendDatas(Data(repeating: 150, count: 1)) { error in
								if self.handleError(error) {
									self.receiveClientMessages()
								}
							}
						} else {
							self.receiveClientMessages()
						}
					} else if case let .failure(error) = result {
						self.logger.error("Failed to read encodings: \(error)")
					}
				}
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read encodings: \(error)")
			}
		}
	}

	private func receiveFramebufferUpdateRequest() {
		self.receiveDatas(ofType: VNCFramebufferUpdateRequest.self, dataLength: 9) { result in
			if case let .success(value) = result {
				self.logger.trace("Client request update: \(value)")

				// Send framebuffer update
				Task {
					await self.sendFramebufferUpdate()
				}

				self.receiveClientMessages()
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read request update: \(error)")
			}
		}
	}

	private func receiveFramebufferUpdateContinue() {
		self.receiveDatas(ofType: VNCFramebufferUpdateContinue.self, dataLength: 9) { result in
			if case let .success(value) = result {
				self.logger.debug("Client request update continue: \(value)")

				self.sendFramebufferContinous = value.active != 0

				if value.active == 0 {
					self.sendDatas(Data(repeating: 150, count: 1)) { error in
						if self.handleError(error) {
							self.receiveClientMessages()
						}
					}
				} else {
					self.receiveClientMessages()
				}
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read update continue: \(error)")
			}
		}
	}

	private func receiveKeyEvent() {
		self.receiveDatas(ofType: VNCKeyEvent.self, dataLength: 7) { result in
			if case let .success(value) = result {
				self.logger.debug("Client send key event: \(value.description)")
				let down = value.downFlag != 0

				DispatchQueue.main.async {
					self.inputHandler.handleKeyEvent(key: value.key, isDown: down)
					self.inputDelegate?.vncConnection(self, didReceiveKeyEvent: value.key, isDown: value.downFlag != 0)
				}

				self.receiveClientMessages()
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read key event: \(error)")
			}
		}
	}

	private func receivePointerEvent() {
		self.receiveDatas(ofType: VNCPointerEvent.self, dataLength: 5) { result in
			if case let .success(value) = result {
				self.logger.trace("Client send pointer event: \(value)")

				DispatchQueue.main.async {
					self.inputHandler.handlePointerEvent(x: Int(value.xPosition), y: Int(value.yPosition), buttonMask: value.buttonMask)
					self.inputDelegate?.vncConnection(self, didReceiveMouseEvent: Int(value.xPosition), y: Int(value.yPosition), buttonMask: value.buttonMask)
				}

				self.receiveClientMessages()
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read pointer event: \(error)")
			}
		}
	}

	private func receiveClientCutText() {
		self.receiveDatas(ofType: VNCClientCutText.self, dataLength: 7) { result in
			if case let .success(value) = result {
				self.logger.debug("Client send cut text: \(value)")

				self.receiveDatas(ofType: UInt8.self, countOf: Int(value.textLength)) { result in
					if case let .success(value) = result {
						let text = String(decoding: value, as: Unicode.UTF8.self)
						
						DispatchQueue.main.async {
							self.inputHandler.handleClipboardText(text)
						}

						self.receiveClientMessages()
					} else if case let .failure(error) = result {
						self.logger.error("Failed to read text: \(error)")
					}
				}
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read cut text: \(error)")
			}
		}
	}

	private func receiveClientFence() {
		self.receiveDatas(ofType: VNCFenceClient.self, dataLength: 9) { result in
			if case let .success(value) = result {
				self.logger.debug("Client send fence: \(value)")

				self.receiveDatas(ofType: UInt8.self, countOf: Int(value.payloadLength)) { result in
					if case let .success(value) = result {
						self.logger.debug("fence: \(value)")

						self.receiveClientMessages()
					} else if case let .failure(error) = result {
						self.logger.error("Failed to read fence: \(error)")
					}
				}
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read fence request: \(error)")
			}
		}
	}

	private func receiveXVPServerMessage() {
		self.receiveDatas(ofType: UInt8.self, countOf: 3) { result in
			if case let .success(value) = result {
				self.logger.debug("XVP server message: \(value)")
				self.receiveClientMessages()
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read XVP server message: \(error)")
			}
		}
	}

	private func receiveSetDesktopSize() {
		self.receiveDatas(ofType: VNCSetDesktopSize.self, dataLength: 7) { result in
			if case let .success(value) = result {
				self.logger.debug("Client set desktop size: \(value)")

				self.receiveDatas(ofType: VNCScreenDesktop.self, countOf: Int(value.numberOfScreen)) { result in
					if case let .success(values) = result {
						self.logger.debug("desktops: \(values)")

						self.receiveClientMessages()
					} else if case let .failure(error) = result {
						self.logger.error("Failed to read desktop: \(error)")
					}
				}
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read desktop size request: \(error)")
			}
		}
	}

	private func receiveGIIClientVersion() {
		self.receiveDatas(ofType: VNCGiiVersion.self, dataLength: 3) { result in
			if case let .success(value) = result {
				self.logger.debug("Client Gii version: \(value)")

				self.receiveDatas(ofType: UInt8.self, countOf: Int(value.length)) { result in
					if case let .success(values) = result {
						self.logger.debug("Gii payload: \(values)")

						self.receiveClientMessages()
					} else if case let .failure(error) = result {
						self.logger.error("Failed to read Gii payload: \(error)")
					}
				}
			} else if case let .failure(error) = result {
				self.logger.error("Failed to read Gii request: \(error)")
			}
		}
	}

	private func receiveQemuClientMessage() {
		self.receiveDatas(ofType: UInt8.self) { result in
			if case let .success(value) = result {
				self.logger.debug("Client qemu message: \(value)")

				if value == 0 {
					self.receiveDatas(ofType: VNCQemuKeyEvent.self) { result in
						if case let .success(values) = result {
							self.logger.debug("Client qemu key event: \(values)")
							
							self.receiveClientMessages()
						} else if case let .failure(error) = result {
							self.logger.error("Failed to read qemu key event: \(error)")
						}
					}
				} else {
					self.receiveDatas(ofType: UInt16.self) { result in
						if case let .success(value) = result {
							self.logger.debug("Client qemu audio operation: \(value)")

							if value == 2 {
								self.receiveDatas(ofType: VNCQemuAudioFormat.self) { result in
									if case let .success(value) = result {
										self.logger.debug("Client qemu audio format: \(value)")
										
										self.receiveClientMessages()
									}
								}
							} else {
								self.receiveClientMessages()
							}
						} else if case let .failure(error) = result {
							self.logger.error("Failed to read qemu audio operation: \(error)")
						}
					}
				}

			} else if case let .failure(error) = result {
				self.logger.error("Failed to read qemu request: \(error)")
			}
		}
	}

	func sendFramebufferUpdate() async {
		if isAuthenticated && self.connection.state == .ready {
			let state = await framebuffer.getCurrentState()
			var msgData = Data(count: MemoryLayout<VNCFramebufferUpdatePayload>.size)
			let semaphore = AsyncSemaphore(value: 0)
			let pixelData = transformPixel(state.data, width: state.width, height: state.height)

			let _ = msgData.withUnsafeMutableBytes { msgBytes in
				guard let baseAddress = msgBytes.bindMemory(to: VNCFramebufferUpdatePayload.self).baseAddress else {
					return VNCFramebufferUpdatePayload()
				}

				//var payload = baseAddress.pointee
				baseAddress.pointee.message.messageType = 0  // VNC_MSG_FRAMEBUFFER_UPDATE
				baseAddress.pointee.message.padding = 0
				baseAddress.pointee.message.numberOfRectangles = UInt16(1).bigEndian

				baseAddress.pointee.rectangle.x = 0
				baseAddress.pointee.rectangle.y = 0
				baseAddress.pointee.rectangle.width = UInt16(state.width).bigEndian
				baseAddress.pointee.rectangle.height = UInt16(state.height).bigEndian
				baseAddress.pointee.rectangle.encoding = UInt32(0).bigEndian  // VNC_ENCODING_RAW

				return baseAddress.pointee
			}

			self.sendDatas(msgData) { [weak self] error in
				guard let self: VNCConnection = self else { return }

				if self.handleError(error) {
					self.sendDatas(pixelData) { [weak self] error in
						guard let self: VNCConnection = self else { return }

						Task {
							if self.handleError(error) {
								await self.framebuffer.markAsProcessed()
							}
							
							semaphore.signal()
						}
					}
				} else {
					semaphore.signal()
				}
			}
			
			await semaphore.wait()
			
			if self.encodings.enableContinousUpdate && self.sendFramebufferContinous == false {
				self.sendFramebufferContinous = true
			}
		}

	}

	func sendDatas(_ data: Data, completion: @escaping (_ error: NWError?) -> Void) {
		if self.connection.state == .ready {
			self.connection.send(content: data, completion: .contentProcessed { completion($0) })
		} else {
			completion(NWError.posix(.EADDRNOTAVAIL))
		}
	}

	func notifyFramebufferSizeChange() async {
		if self.sendFramebufferContinous == false {
			await self.sendFramebufferUpdate()
		}
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
}

