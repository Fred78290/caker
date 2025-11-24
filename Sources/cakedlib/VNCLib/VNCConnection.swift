import Foundation
import Network
import CryptoKit
import CommonCrypto

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
    private var authChallenge: Data?
    private let vncPassword: String?
    
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
        
        connection.send(content: versionData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.delegate?.vncConnection(self!, didReceiveError: error)
                return
            }
            self?.receiveClientVersion()
        })
    }
    
    private func receiveClientVersion() {
        connection.receive(minimumIncompleteLength: 12, maximumLength: 12) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                self.delegate?.vncConnection(self, didReceiveError: error)
                return
            }
            
            // Send authentication methods
            self.sendAuthenticationMethods()
        }
    }
    
    private func sendAuthenticationMethods() {
        if vncPassword == nil {
            // No password - use no authentication
            var authCount: UInt8 = 1
            var authType: UInt32 = Self.VNC_AUTH_NONE.bigEndian
            
            var authData = Data()
            authData.append(Data(bytes: &authCount, count: 1))
            authData.append(Data(bytes: &authType, count: 4))
            
            connection.send(content: authData, completion: .contentProcessed { [weak self] error in
                if error == nil {
                    self?.receiveAuthenticationChoice()
                }
            })
        } else {
            // Password required - use VNC authentication
            var authCount: UInt8 = 1
            var authType: UInt32 = Self.VNC_AUTH_VNC.bigEndian
            
            var authData = Data()
            authData.append(Data(bytes: &authCount, count: 1))
            authData.append(Data(bytes: &authType, count: 4))
            
            connection.send(content: authData, completion: .contentProcessed { [weak self] error in
                if error == nil {
                    self?.receiveAuthenticationChoice()
                }
            })
        }
    }
    
    private func receiveAuthenticationChoice() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, _, error in
            guard let self = self, let data = data, data.count > 0 else {
                return
            }
            
            if let error = error {
                self.delegate?.vncConnection(self, didReceiveError: error)
                return
            }
            
            let authType = data[0]
            
            if authType == UInt8(Self.VNC_AUTH_NONE) {
                self.sendAuthenticationResult(success: true)
            } else if authType == UInt8(Self.VNC_AUTH_VNC) {
                self.sendVNCAuthChallenge()
            } else {
                self.sendAuthenticationResult(success: false)
            }
        }
    }
    
    private func sendVNCAuthChallenge() {
        // Generate 16-byte random challenge
        authChallenge = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        
        connection.send(content: authChallenge!, completion: .contentProcessed { [weak self] error in
            if error == nil {
                self?.receiveVNCAuthResponse()
            }
        })
    }
    
    private func receiveVNCAuthResponse() {
        connection.receive(minimumIncompleteLength: 16, maximumLength: 16) { [weak self] data, _, _, error in
            guard let self = self, let responseData = data, responseData.count == 16 else {
                return
            }
            
            if let error = error {
                self.delegate?.vncConnection(self, didReceiveError: error)
                return
            }
            
            let isValid = self.validateVNCAuthResponse(responseData)
            self.sendAuthenticationResult(success: isValid)
        }
    }
    
    private func validateVNCAuthResponse(_ response: Data) -> Bool {
        guard let password = vncPassword,
              let challenge = authChallenge else {
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
            nil, // IV
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
        var result: UInt32 = success ? Self.VNC_AUTH_OK.bigEndian : Self.VNC_AUTH_FAILED.bigEndian
        let resultData = Data(bytes: &result, count: 4)
        
        connection.send(content: resultData, completion: .contentProcessed { [weak self] error in
            if error == nil && success {
                self?.isAuthenticated = true
                self?.sendServerInit()
                self?.receiveClientMessages()
            } else if !success {
                // Authentication failed - disconnect
                self?.disconnect()
            }
        })
    }
    
    private func sendServerInit() {
        let state = framebuffer.getCurrentState()
        
        var serverInit = VNCServerInit()
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
        
        let name = "NSView VNC Server"
        let nameData = name.data(using: .utf8)!
        var nameLength = UInt32(nameData.count).bigEndian
        
        var initData = Data()
        initData.append(Data(bytes: &serverInit, count: MemoryLayout<VNCServerInit>.size))
        initData.append(Data(bytes: &nameLength, count: 4))
        initData.append(nameData)
        
        connection.send(content: initData, completion: .contentProcessed { _ in })
    }
    
    private func receiveClientMessages() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, data.count > 0 else {
                self?.receiveClientMessages()
                return
            }
            
            let messageType = data[0]
            self.handleClientMessage(type: messageType)
            
            if !isComplete {
                self.receiveClientMessages()
            }
        }
    }
    
    private func handleClientMessage(type: UInt8) {
        switch type {
        case VNCClientMessageType.setPixelFormat.rawValue:
            receiveSetPixelFormat()
        case VNCClientMessageType.setEncodings.rawValue:
            receiveSetEncodings()
        case VNCClientMessageType.framebufferUpdateRequest.rawValue:
            receiveFramebufferUpdateRequest()
        case VNCClientMessageType.keyEvent.rawValue:
            receiveKeyEvent()
        case VNCClientMessageType.pointerEvent.rawValue:
            receivePointerEvent()
        case VNCClientMessageType.clientCutText.rawValue:
            receiveClientCutText()
        default:
            receiveClientMessages()
        }
    }
    
    // MARK: - Message Handlers
    
    private func receiveSetPixelFormat() {
        connection.receive(minimumIncompleteLength: 19, maximumLength: 19) { [weak self] data, _, _, _ in
            // Ignore for now, use default format
            self?.receiveClientMessages()
        }
    }
    
    private func receiveSetEncodings() {
        connection.receive(minimumIncompleteLength: 3, maximumLength: 3) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, data.count >= 3 else {
                self?.receiveClientMessages()
                return
            }
            
            let numberOfEncodings = UInt16(data[2]) << 8 | UInt16(data[1])
            let encodingsLength = Int(numberOfEncodings) * 4
            
            self.connection.receive(minimumIncompleteLength: encodingsLength, maximumLength: encodingsLength) { _, _, _, _ in
                self.receiveClientMessages()
            }
        }
    }
    
    private func receiveFramebufferUpdateRequest() {
        connection.receive(minimumIncompleteLength: 9, maximumLength: 9) { [weak self] data, _, _, _ in
            // Send framebuffer update
            self?.sendFramebufferUpdate()
            self?.receiveClientMessages()
        }
    }
    
    private func receiveKeyEvent() {
        connection.receive(minimumIncompleteLength: 7, maximumLength: 7) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, data.count >= 8 else {
                self?.receiveClientMessages()
                return
            }
            
            let downFlag = data[1] != 0
            let key = UInt32(data[4]) << 24 | UInt32(data[5]) << 16 | UInt32(data[6]) << 8 | UInt32(data[7])
            
            DispatchQueue.main.async {
                self.inputHandler.handleKeyEvent(key: key, isDown: downFlag)
                self.inputDelegate?.vncConnection(self, didReceiveKeyEvent: key, isDown: downFlag)
            }
            
            self.receiveClientMessages()
        }
    }
    
    private func receivePointerEvent() {
        connection.receive(minimumIncompleteLength: 5, maximumLength: 5) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, data.count >= 6 else {
                self?.receiveClientMessages()
                return
            }
            
            let buttonMask = data[1]
            let x = UInt16(data[2]) << 8 | UInt16(data[3])
            let y = UInt16(data[4]) << 8 | UInt16(data[5])
            
            DispatchQueue.main.async {
                self.inputHandler.handlePointerEvent(x: Int(x), y: Int(y), buttonMask: buttonMask)
                self.inputDelegate?.vncConnection(self, didReceiveMouseEvent: Int(x), y: Int(y), buttonMask: buttonMask)
            }
            
            self.receiveClientMessages()
        }
    }
    
    private func receiveClientCutText() {
        connection.receive(minimumIncompleteLength: 7, maximumLength: 7) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, data.count >= 8 else {
                self?.receiveClientMessages()
                return
            }
            
            let textLength = UInt32(data[4]) << 24 | UInt32(data[5]) << 16 | UInt32(data[6]) << 8 | UInt32(data[7])
            
            self.connection.receive(minimumIncompleteLength: Int(textLength), maximumLength: Int(textLength)) { textData, _, _, _ in
                if let textData = textData, let text = String(data: textData, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.inputHandler.handleClipboardText(text)
                    }
                }
                self.receiveClientMessages()
            }
        }
    }
    
    func sendFramebufferUpdate() {
        guard isAuthenticated else { return }
        
        let state = framebuffer.getCurrentState()
        guard state.hasChanges else { return }
        
        connectionQueue.async {
            var updateMsg = VNCFramebufferUpdateMsg()
            updateMsg.messageType = 0 // VNC_MSG_FRAMEBUFFER_UPDATE
            updateMsg.padding = 0
            updateMsg.numberOfRectangles = UInt16(1).bigEndian
            
            var rect = VNCRectangle()
            rect.x = 0
            rect.y = 0
            rect.width = UInt16(state.width).bigEndian
            rect.height = UInt16(state.height).bigEndian
            rect.encoding = UInt32(0).bigEndian // VNC_ENCODING_RAW
            
            var msgData = Data()
            msgData.append(Data(bytes: &updateMsg, count: MemoryLayout<VNCFramebufferUpdateMsg>.size))
            msgData.append(Data(bytes: &rect, count: MemoryLayout<VNCRectangle>.size))
            msgData.append(state.data)
            
            self.connection.send(content: msgData, completion: .contentProcessed { _ in
                self.framebuffer.markAsProcessed()
            })
        }
    }
    
    func notifyFramebufferSizeChange() {
        sendFramebufferUpdate()
    }
    
    private func handleDisconnection() {
        delegate?.vncConnectionDidDisconnect(self, clientAddress: clientAddress)
    }
}