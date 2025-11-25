import CommonCrypto
import CryptoKit
import Foundation
import Network

extension Data {
	func toHexString() -> String {
		return self.map { String(format: "%02X", $0) }.joined()
	}
}

protocol VNCConnectionDelegate: AnyObject {
	func vncConnectionDidDisconnect(_ connection: VNCConnection, clientAddress: String)
	func vncConnection(_ connection: VNCConnection, didReceiveError error: Error)
}

protocol VNCInputDelegate: AnyObject {
	func vncConnection(_ connection: VNCConnection, didReceiveKeyEvent key: UInt32, isDown: Bool)
	func vncConnection(_ connection: VNCConnection, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8)
}

class VNCConnection {
	weak var delegate: VNCConnectionDelegate?
	weak var inputDelegate: VNCInputDelegate?

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

	// VNC Auth constants
	private static let VNC_AUTH_NONE: UInt32 = 1
	private static let VNC_AUTH_VNC: UInt32 = 2
	private static let VNC_AUTH_OK: UInt32 = 0
	private static let VNC_AUTH_FAILED: UInt32 = 1

	init(connection: NWConnection, framebuffer: VNCFramebuffer, password: String? = nil) {
		self.connection = connection
		self.framebuffer = framebuffer
		self.inputHandler = VNCInputHandler(targetView: framebuffer.sourceView)
		self.vncPassword = password

		if case .hostPort(let host, _) = connection.endpoint {
			self.clientAddress = "\(host)"
		}
	}

	func start() {
		connection.stateUpdateHandler = { [weak self] state in
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

	private func handleInitialHandshake() {
		// Send RFB protocol version
		let version = "RFB 003.008\n"
		let versionData = version.data(using: .ascii)!

		connection.send(
			content: versionData,
			completion: .contentProcessed { [weak self] error in
				if let self = self {
					if let error = error {
						self.delegate?.vncConnection(self, didReceiveError: error)
						return
					}
					self.receiveClientVersion()
				}
			})
	}

	private func handleError(_ error: NWError?) -> Bool {
		if let error = error {
			self.delegate?.vncConnection(self, didReceiveError: error)

			if connection.state != .ready {
				self.disconnect()
			}

			return false
		}

		return true
	}

	private func receiveClientVersion() {
		connection.receive(minimumIncompleteLength: 12, maximumLength: 12) { [weak self] data, _, isComplete, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data, let versionString = String(data: data, encoding: .ascii) {
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
								let unsupportedVersionError = NSError(
									domain: "VNCConnectionError", code: 1002,
									userInfo: [NSLocalizedDescriptionKey: "Unsupported VNC version: \(majorVersion).\(minorVersion)"])
								self.delegate?.vncConnection(self, didReceiveError: unsupportedVersionError)
								self.disconnect()
							}
						} else {
							// Invalid version format
							let invalidFormatError = NSError(
								domain: "VNCConnectionError", code: 1003,
								userInfo: [NSLocalizedDescriptionKey: "Invalid version format: \(versionPart)"])
							self.delegate?.vncConnection(self, didReceiveError: invalidFormatError)
							self.disconnect()
						}
					} else {
						// Not a valid RFB protocol string
						let invalidProtocolError = NSError(
							domain: "VNCConnectionError", code: 1004,
							userInfo: [NSLocalizedDescriptionKey: "Invalid RFB protocol string: \(trimmedVersion)"])
						self.delegate?.vncConnection(self, didReceiveError: invalidProtocolError)
						self.disconnect()
					}
				} else {
					let invalidVersionError = NSError(domain: "VNCConnectionError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid client version format"])
					self.delegate?.vncConnection(self, didReceiveError: invalidVersionError)
				}
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
						self?.isAuthenticated = true
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
		// VNC 3.7+: Send list of supported authentication types
		var supportedAuthTypes: [UInt32] = []

		// Always support no authentication if no password set
		if vncPassword == nil {
			supportedAuthTypes.append(Self.VNC_AUTH_NONE)
		} else {
			supportedAuthTypes.append(Self.VNC_AUTH_VNC)
		}

		// If no authentication methods available, send empty list (connection failure)
		if supportedAuthTypes.isEmpty {
			var authCount: UInt8 = 0
			let authData = Data(bytes: &authCount, count: 1)

			connection.send(
				content: authData,
				completion: .contentProcessed { [weak self] error in
					// Send failure reason
					let reason = "No supported authentication methods available"
					let reasonData = reason.data(using: .utf8)!
					var reasonLength = UInt32(reasonData.count).bigEndian

					var failureData = Data()
					failureData.append(Data(bytes: &reasonLength, count: 4))
					failureData.append(reasonData)

					self?.connection.send(
						content: failureData,
						completion: .contentProcessed { _ in
							self?.disconnect()
						})
				})
			return
		}

		// Send authentication type list
		var authCount = UInt8(supportedAuthTypes.count)
		var authData = Data()
		authData.append(Data(bytes: &authCount, count: 1))

		for authType in supportedAuthTypes {
			var bigEndianAuthType = authType.bigEndian

			authData.append(Data(bytes: &bigEndianAuthType, count: 4))
		}

		self.connection.send(
			content: authData,
			completion: .contentProcessed { [weak self] error in
				if error == nil {
					self?.receiveAuthenticationChoice()
				}
			})
	}

	private func receiveClientInit() {
		// Receive ClientInit message (1 byte: shared flag)
		self.connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				self.logger.debug("ClientInit received \(data!.toHexString()) starting VNC session")

				// Send ServerInit and start receiving client messages
				self.sendServerInit()
				self.receiveClientMessages()
			}
		}
	}

	private func receiveAuthenticationChoice() {
		// Only used for VNC 3.7+ where client chooses from authentication list
		self.connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					let authType = data[0]

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
				} else {
					self.receiveAuthenticationChoice()
				}
			}
		}
	}

	private func sendVNCAuthChallenge() {
		// Generate 16-byte random challenge
		self.authChallenge = Data((0..<16).map { _ in UInt8.random(in: 0...255) })

		self.logger.debug("Sending VNC authentication challenge: \(authChallenge.toHexString())")

		self.connection.send(
			content: self.authChallenge!,
			completion: .contentProcessed { [weak self] error in
				if error == nil {
					self?.receiveVNCAuthResponse()
				}
			})
	}

	private func receiveVNCAuthResponse() {
		self.connection.receive(minimumIncompleteLength: 16, maximumLength: 16) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					self.sendAuthenticationResult(success: self.validateVNCAuthResponse(data))
				}
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

		self.connection.send(
			content: resultData,
			completion: .contentProcessed { [weak self] error in
				if let self {
					if error == nil && success {
						// Authentication successful - wait for ClientInit
						self.isAuthenticated = true
						self.receiveClientInit()
					} else if success == false {
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

							self.connection.send(
								content: failureData,
								completion: .contentProcessed { _ in
									self.disconnect()
								})
						}
					}
				}
			})
	}

	private func sendServerInit() {
		let state = framebuffer.getCurrentState()

		var serverInit = VNCServerInit()
		let name = "NSView VNC Server"
		let nameData = name.data(using: .utf8)!
		var nameLength = UInt32(nameData.count).bigEndian
		var initData = Data()

		serverInit.framebufferWidth = UInt16(state.width).bigEndian
		serverInit.framebufferHeight = UInt16(state.height).bigEndian
		serverInit.pixelFormat.bitsPerPixel = 32
		serverInit.pixelFormat.depth = 24
		serverInit.pixelFormat.bigEndianFlag = 0
		serverInit.pixelFormat.trueColorFlag = 1
		serverInit.pixelFormat.redMax = UInt16(255).bigEndian
		serverInit.pixelFormat.greenMax = UInt16(255).bigEndian
		serverInit.pixelFormat.blueMax = UInt16(255).bigEndian
		serverInit.pixelFormat.redShift = 0
		serverInit.pixelFormat.greenShift = 8
		serverInit.pixelFormat.blueShift = 16

		initData.append(Data(bytes: &serverInit, count: MemoryLayout<VNCServerInit>.size))
		initData.append(Data(bytes: &nameLength, count: 4))
		initData.append(nameData)

		self.connection.send(content: initData, completion: .contentProcessed { _ in })
	}

	private func receiveClientMessages() {
		self.connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, isComplete, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					self.handleClientMessage(type: data[0])

					if isComplete == false {
						self.receiveClientMessages()
					}
				} else {
					self.receiveClientMessages()
				}
			}
		}
	}

	private func handleClientMessage(type: UInt8) {
		let messageType = VNCClientMessageType(rawValue: type)

		self.logger.debug("Receive message: \(messageType.debugDescription )")

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
		default:
			self.receiveClientMessages()
		}
	}

	// MARK: - Message Handlers

	private func receiveSetPixelFormat() {
		self.connection.receive(minimumIncompleteLength: 19, maximumLength: 19) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					// Message type already heated (1 byte)
					// Skip padding bytes (3 bytes after message type)
					// Parse VNC Pixel Format (16 bytes starting at offset 3)
					var pixelFormat = VNCPixelFormat()

					pixelFormat.bitsPerPixel = data[3]
					pixelFormat.depth = data[4]
					pixelFormat.bigEndianFlag = data[5]
					pixelFormat.trueColorFlag = data[6]
					pixelFormat.redMax = UInt16(data[7]) << 8 | UInt16(data[8])
					pixelFormat.greenMax = UInt16(data[9]) << 8 | UInt16(data[10])
					pixelFormat.blueMax = UInt16(data[11]) << 8 | UInt16(data[12])
					pixelFormat.redShift = data[13]
					pixelFormat.greenShift = data[14]
					pixelFormat.blueShift = data[15]
					// Skip padding bytes 17-19

					self.logger.debug("Client set pixel format: \(pixelFormat.bitsPerPixel)bpp, depth=\(pixelFormat.depth)")
				}

				// Ignore for now, use default format
				self.receiveClientMessages()
			}
		}
	}

	private func receiveSetEncodings() {
		self.connection.receive(minimumIncompleteLength: 3, maximumLength: 3) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					let numberOfEncodings = UInt16(data[2]) << 8 | UInt16(data[1])
					let encodingsLength = Int(numberOfEncodings) * 4

					self.connection.receive(minimumIncompleteLength: encodingsLength, maximumLength: encodingsLength) { _, _, _, error in
						if self.handleError(error) == true {
							return
						}

						self.receiveClientMessages()
					}
				} else {
					self.receiveClientMessages()
				}

			}
		}
	}

	private func receiveFramebufferUpdateRequest() {
		self.connection.receive(minimumIncompleteLength: 9, maximumLength: 9) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					var request = VNCFramebufferUpdateRequest()

					request.incremental = data[0]
					request.x = UInt16(data[2]) << 8 | UInt16(data[1])
					request.y = UInt16(data[4]) << 8 | UInt16(data[3])
					request.width = UInt16(data[6]) << 8 | UInt16(data[5])
					request.height = UInt16(data[8]) << 8 | UInt16(data[7])

					// Send framebuffer update
					self.sendFramebufferUpdate()
				}
				self.receiveClientMessages()
			}
		}
	}

	private func receiveFramebufferUpdateContinue() {
		self.connection.receive(minimumIncompleteLength: 9, maximumLength: 9) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					var request = VNCFramebufferUpdateContinue()

					request.active = data[0]
					request.x = UInt16(data[2]) << 8 | UInt16(data[1])
					request.y = UInt16(data[4]) << 8 | UInt16(data[3])
					request.width = UInt16(data[6]) << 8 | UInt16(data[5])
					request.height = UInt16(data[8]) << 8 | UInt16(data[7])
				}

				self.receiveClientMessages()
			}
		}
	}

	private func receiveKeyEvent() {
		self.connection.receive(minimumIncompleteLength: 7, maximumLength: 7) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					let downFlag = data[0] != 0
					let key = UInt32(data[4]) << 24 | UInt32(data[3]) << 16 | UInt32(data[6]) << 8 | UInt32(data[5])

					DispatchQueue.main.async {
						self.inputHandler.handleKeyEvent(key: key, isDown: downFlag)
						self.inputDelegate?.vncConnection(self, didReceiveKeyEvent: key, isDown: downFlag)
					}
				}

				self.receiveClientMessages()
			}
		}
	}

	private func receivePointerEvent() {
		self.connection.receive(minimumIncompleteLength: 5, maximumLength: 5) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					let buttonMask = data[0]
					let x = UInt16(data[1]) << 8 | UInt16(data[2])
					let y = UInt16(data[3]) << 8 | UInt16(data[4])

					DispatchQueue.main.async {
						self.inputHandler.handlePointerEvent(x: Int(x), y: Int(y), buttonMask: buttonMask)
						self.inputDelegate?.vncConnection(self, didReceiveMouseEvent: Int(x), y: Int(y), buttonMask: buttonMask)
					}
				}

				self.receiveClientMessages()
			}
		}
	}

	private func receiveClientCutText() {
		self.connection.receive(minimumIncompleteLength: 7, maximumLength: 7) { [weak self] data, _, _, error in
			guard let self = self else { return }

			if self.handleError(error) {
				if let data = data {
					let textLength = UInt32(data[3]) << 24 | UInt32(data[4]) << 16 | UInt32(data[5]) << 8 | UInt32(data[6])

					self.connection.receive(minimumIncompleteLength: Int(textLength), maximumLength: Int(textLength)) { textData, _, _, error in
						if self.handleError(error) == true {
							return
						}

						if let textData = textData, let text = String(data: textData, encoding: .utf8) {
							DispatchQueue.main.async {
								self.inputHandler.handleClipboardText(text)
							}
						}

						self.receiveClientMessages()
					}
				} else {
					self.receiveClientMessages()
				}
			}
		}
	}

	func sendFramebufferUpdate() {
		guard isAuthenticated else { return }

		let state = framebuffer.getCurrentState()
		guard state.hasChanges else { return }

		self.connectionQueue.async {
			var updateMsg = VNCFramebufferUpdateMsg()
			var rect = VNCRectangle()
			var msgData = Data()

			updateMsg.messageType = 0  // VNC_MSG_FRAMEBUFFER_UPDATE
			updateMsg.padding = 0
			updateMsg.numberOfRectangles = UInt16(1).bigEndian

			rect.x = 0
			rect.y = 0
			rect.width = UInt16(state.width).bigEndian
			rect.height = UInt16(state.height).bigEndian
			rect.encoding = UInt32(0).bigEndian  // VNC_ENCODING_RAW

			msgData.append(Data(bytes: &updateMsg, count: MemoryLayout<VNCFramebufferUpdateMsg>.size))
			msgData.append(Data(bytes: &rect, count: MemoryLayout<VNCRectangle>.size))
			msgData.append(state.data)

			self.connection.send(
				content: msgData,
				completion: .contentProcessed { _ in
					self.framebuffer.markAsProcessed()
				})
		}
	}

	func notifyFramebufferSizeChange() {
		self.sendFramebufferUpdate()
	}

	private func handleDisconnection() {
		self.delegate?.vncConnectionDidDisconnect(self, clientAddress: clientAddress)
	}
}
