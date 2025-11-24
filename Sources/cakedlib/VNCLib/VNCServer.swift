import Foundation
import AppKit
import Network
import Darwin
import Metal

public protocol VZVNCServer {
	func start() throws
	func stop()
	func connectionURL() -> URL
}

public enum VNCCaptureMethod {
    case coreGraphics
    case metal
}

public protocol VNCServerDelegate: AnyObject {
    func vncServer(_ server: VNCServer, clientDidConnect clientAddress: String)
    func vncServer(_ server: VNCServer, clientDidDisconnect clientAddress: String)
    func vncServer(_ server: VNCServer, didReceiveError error: Error)
    func vncServer(_ server: VNCServer, didReceiveKeyEvent key: UInt32, isDown: Bool)
    func vncServer(_ server: VNCServer, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8)
}

public extension VNCServerDelegate {
    // Méthodes optionnelles avec implémentation par défaut
    func vncServer(_ server: VNCServer, didReceiveKeyEvent key: UInt32, isDown: Bool) {}
    func vncServer(_ server: VNCServer, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8) {}
}

public class VNCServer: NSObject, VZVNCServer {
    public weak var delegate: VNCServerDelegate?
    public weak var sourceView: NSView? {
        didSet {
            setupViewObservers()
            framebuffer?.sourceView = sourceView
        }
    }
    
    public private(set) var port: UInt16
    public private(set) var isRunning = false
    public var allowRemoteInput = true // Controls if remote inputs are accepted
    public let captureMethod: VNCCaptureMethod
    public var password: String? // VNC Auth password
    
    private var listener: NWListener?
    private var connections: [VNCConnection] = []
    private var framebuffer: VNCFramebuffer?
    private var updateTimer: Timer?
    private let connectionQueue = DispatchQueue(label: "vnc.server.connections", attributes: .concurrent)
    
    public init(_ sourceView: NSView, password: String? = nil, port: UInt16 = 0, captureMethod: VNCCaptureMethod = .metal, metalConfig: VNCMetalFramebuffer.MetalConfiguration = .standard) {
        self.sourceView = sourceView
        self.captureMethod = captureMethod
        self.password = password
        
        if port == 0 {
            self.port = Self.findAvailablePort(in: 30000...32767) ?? UInt16.random(in: 30000...32767)
        } else {
            self.port = port
        }
        super.init()
        
        // Create appropriate framebuffer based on capture method
        switch captureMethod {
        case .metal:
            if MTLCreateSystemDefaultDevice() != nil {
                self.framebuffer = VNCMetalFramebuffer(view: sourceView, captureMethod: .metal, metalConfig: metalConfig)
            } else {
                print("Metal not available, falling back to Core Graphics")
                self.framebuffer = VNCFramebuffer(view: sourceView)
            }
        case .coreGraphics:
            self.framebuffer = VNCFramebuffer(view: sourceView)
        }
        
        setupViewObservers()
    }
    
    private func setupViewObservers() {
        guard let view = sourceView else { return }
        
        // Observer for size changes
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: view
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewFrameDidChange),
            name: NSView.frameDidChangeNotification,
            object: view
        )
        
        // Enable notifications
        view.postsFrameChangedNotifications = true
        view.postsBoundsChangedNotifications = true
    }
    
    @objc private func viewBoundsDidChange() {
        handleViewSizeChange()
    }
    
    @objc private func viewFrameDidChange() {
        handleViewSizeChange()
    }
    
    private func handleViewSizeChange() {
        guard let view = sourceView else { return }
        
        // Update framebuffer with new size
        framebuffer?.updateSize(width: Int(view.bounds.width), height: Int(view.bounds.height))
        
        // Notify all clients of size change
        connectionQueue.async {
            for connection in self.connections {
                connection.notifyFramebufferSizeChange()
            }
        }
    }
    
	public func connectionURL() -> URL {
		if let password = password {
			return URL(string: "vnc://:\(password)@127.0.0.1:\(port)")!
		} else {
			return URL(string: "vnc://127.0.0.1:\(port)")!
		}
	}

	public func start() throws {
        guard !isRunning else { return }
        
        // Check if port is available before starting
        if !Self.isPortAvailable(port) {
            throw VNCServerError.portNotAvailable(port)
        }
        
        let parameters = NWParameters.tcp
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                self?.startFramebufferUpdates()
            case .failed(let error):
                self?.delegate?.vncServer(self!, didReceiveError: error)
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }
        
        listener?.start(queue: connectionQueue)
    }
    
    public func stop() {
        guard isRunning else { return }
        
        updateTimer?.invalidate()
        updateTimer = nil
        
        listener?.cancel()
        listener = nil
        
        connectionQueue.async {
            for connection in self.connections {
                connection.disconnect()
            }
            self.connections.removeAll()
        }
        
        isRunning = false
    }
    
    private func handleNewConnection(_ nwConnection: NWConnection) {
        let connection = VNCConnection(connection: nwConnection, framebuffer: framebuffer!, password: password)
        connection.delegate = self
        connection.inputDelegate = self
        
        connectionQueue.async(flags: .barrier) {
            self.connections.append(connection)
        }
        
        connection.start()
        
        let endpoint = nwConnection.endpoint
        if case .hostPort(let host, _) = endpoint {
            DispatchQueue.main.async {
                self.delegate?.vncServer(self, clientDidConnect: "\(host)")
            }
        }
    }
    
    private func startFramebufferUpdates() {
        DispatchQueue.main.async {
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
                self.framebuffer?.updateFromView()
                self.sendFramebufferUpdates()
            }
        }
    }
    
    private func sendFramebufferUpdates() {
        connectionQueue.async {
            for connection in self.connections {
                connection.sendFramebufferUpdate()
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    /// Get render performance statistics
    public var renderStats: String? {
        if let metalFramebuffer = framebuffer as? VNCMetalFramebuffer {
            return metalFramebuffer.renderStats
        }
        return nil
    }
    
    /// Get average render time in milliseconds
    public var averageRenderTime: TimeInterval {
        if let metalFramebuffer = framebuffer as? VNCMetalFramebuffer {
            return metalFramebuffer.averageRenderTime * 1000 // Convert to ms
        }
        return 0
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stop()
    }
    
    // MARK: - Port Availability
    
    private static func isPortAvailable(_ port: UInt16) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD != -1 else { return false }
        
        defer { close(socketFD) }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let addrSize = MemoryLayout<sockaddr_in>.size
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.bind(socketFD, sockPtr, socklen_t(addrSize))
            }
        }
        
        return bindResult == 0
    }
    
    private static func findAvailablePort(in range: ClosedRange<UInt16>) -> UInt16? {
        // Try random ports first
        for _ in 0..<10 {
            let randomPort = UInt16.random(in: range)
            if isPortAvailable(randomPort) {
                return randomPort
            }
        }
        
        // If no random port is available, search sequentially
        for port in range {
            if isPortAvailable(port) {
                return port
            }
        }
        
        return nil
    }
}

// MARK: - VNC Server Errors

public enum VNCServerError: Error, LocalizedError {
    case portNotAvailable(UInt16)
    case listenerCreationFailed
    case framebufferInitializationFailed
    
    public var errorDescription: String? {
        switch self {
        case .portNotAvailable(let port):
            return "Port \(port) is not available"
        case .listenerCreationFailed:
            return "Failed to create network listener"
        case .framebufferInitializationFailed:
            return "Framebuffer initialization failed"
        }
    }
}

// MARK: - VNCConnectionDelegate

extension VNCServer: VNCConnectionDelegate {
    func vncConnectionDidDisconnect(_ connection: VNCConnection, clientAddress: String) {
        connectionQueue.async(flags: .barrier) {
            self.connections.removeAll { $0 === connection }
        }
        
        DispatchQueue.main.async {
            self.delegate?.vncServer(self, clientDidDisconnect: clientAddress)
        }
    }
    
    func vncConnection(_ connection: VNCConnection, didReceiveError error: Error) {
        DispatchQueue.main.async {
            self.delegate?.vncServer(self, didReceiveError: error)
        }
    }
}

// MARK: - VNCInputDelegate

extension VNCServer: VNCInputDelegate {
    func vncConnection(_ connection: VNCConnection, didReceiveKeyEvent key: UInt32, isDown: Bool) {
        guard allowRemoteInput else { return }
        
        DispatchQueue.main.async {
            self.delegate?.vncServer(self, didReceiveKeyEvent: key, isDown: isDown)
        }
    }
    
    func vncConnection(_ connection: VNCConnection, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8) {
        guard allowRemoteInput else { return }
        
        DispatchQueue.main.async {
            self.delegate?.vncServer(self, didReceiveMouseEvent: x, y: Int(buttonMask), buttonMask: buttonMask)
        }
    }
}
