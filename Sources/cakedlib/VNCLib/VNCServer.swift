import AppKit
import ArgumentParser
import Darwin
import Foundation
import Metal
import Network
import QuartzCore
import CakeAgentLib

public protocol VZVNCServer {
	var delegate: VNCServerDelegate? { get set }
	var urls: [URL] { get }
	func start() throws
	func stop()
}

public protocol VNCServerDelegate: AnyObject, Sendable {
	func willStart(_ server: VNCServer)
	func didStart(_ server: VNCServer)
	func willStop(_ server: VNCServer)
	func didStop(_ server: VNCServer)
	func vncServer(_ server: VNCServer, clientDidConnect clientAddress: String)
	func vncServer(_ server: VNCServer, clientDidDisconnect clientAddress: String)
	func vncServer(_ server: VNCServer, didReceiveError error: Error)
	func vncServer(_ server: VNCServer, didReceiveKeyEvent key: UInt32, isDown: Bool)
	func vncServer(_ server: VNCServer, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8)
	func vncServer(_ server: VNCServer, clientDidResizeDesktop screens: [VNCScreenDesktop])
}

public protocol VNCFrameBufferProducer {
	var bitmapInfos: CGBitmapInfo { get }
	var cgImage: CGImage? { get }
	var checkIfImageIsChanged: Bool { get }
	func startFramebufferUpdate(continuation: AsyncStream<CGImage>.Continuation)
	func stopFramebufferUpdate()
}

open class VNCServer: NSObject, VZVNCServer, @unchecked Sendable {
	public weak var delegate: VNCServerDelegate?
	public private(set) var sourceView: NSView
	public private(set) var port: UInt16
	public private(set) var isRunning = false
	public var allowRemoteInput = true  // Controls if remote inputs are accepted
	public var password: String?  // VNC Auth password

	private let logger = Logger("VNCServer")
	private var listener: NWListener!
	private var connections: [VNCConnection] = []
	private var framebuffer: VNCFramebuffer
	private let connectionQueue = DispatchQueue(label: "vnc.server.connections", attributes: .concurrent)
	private let name: String
	private let eventLoop = Utilities.group.next()
	private let allInet: Bool
	private var isLiveResize = false
	private var updateBufferTask: Task<Void, Never>?
	private var activeConnections: [VNCConnection] {
		self.connections.compactMap {
			if $0.connectionState == .ready {
				return $0
			}
			return nil
		}
	}

	static var littleEndian: Bool {
		CFByteOrderGetCurrent() == CFByteOrderLittleEndian.rawValue
	}

	public init(_ sourceView: NSView, name: String, password: String? = nil, port: UInt16 = 0, allInet: Bool) throws {
		try newKeyMapper().setupKeyMapper()

		self.sourceView = sourceView
		self.password = password
		self.name = name
		self.allInet = allInet

		if port == 0 {
			self.port = Self.findAvailablePort(in: 30000...32767) ?? UInt16.random(in: 30000...32767)
		} else {
			self.port = port
		}

		// Create appropriate framebuffer based on capture method
		self.framebuffer = VNCFramebuffer(view: sourceView)

		super.init()
	}

	public var urls: [URL] {
		if self.allInet {
			return VZSharedNetwork.networkInterfaces().compactMap { interface in
				if let password = password {
					return URL(string: "vnc://:\(password)@\(interface.value.base):\(port)")
				} else {
					return URL(string: "vnc://\(interface.value.base):\(port)")
				}
			}
		}

		if let password = password {
			return [URL(string: "vnc://:\(password)@127.0.0.1:\(port)")!]
		} else {
			return [URL(string: "vnc://127.0.0.1:\(port)")!]
		}
	}

	public func start() throws {
		guard !isRunning else { return }

		self.delegate?.willStart(self)

		// Check if port is available before starting
		if !Self.isPortAvailable(port) {
			throw VNCServerError.portNotAvailable(port)
		}

		let parameters = NWParameters.tcp
		let tcpOptions = NWProtocolTCP.Options()

		parameters.defaultProtocolStack.transportProtocol = tcpOptions

        // If not allowing all interfaces, restrict to loopback; otherwise listen on all interfaces
        if allInet == false {
            parameters.requiredInterfaceType = .loopback
        }

		listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: self.port))

		listener.newConnectionHandler = { [weak self] connection in
			if let self = self {
				#if DEBUG
					self.logger.debug("New connection: \(connection)")
				#endif

				self.handleNewConnection(connection)
			}
		}

		listener.stateUpdateHandler = { [weak self] state in
			if let self = self {
				#if DEBUG
					self.logger.debug("Update state: \(state)")
				#endif

				switch state {
				case .ready:
					self.delegate?.didStart(self)
					self.startFramebufferUpdates()
				case .failed(let error):
					self.delegate?.vncServer(self, didReceiveError: error)
				case .cancelled:
					self.stopFramebufferUpdates()
				default:
					break
				}
			}
		}

		listener?.start(queue: connectionQueue)
	}

	public func stop() {
		guard isRunning else { return }

		self.delegate?.willStop(self)

		listener?.cancel()
		listener = nil

		if self.connections.isEmpty == false {
			connectionQueue.async {
				self.connections.forEach {
					$0.disconnect()
				}
				self.connections.removeAll()
			}
		}

		isRunning = false
		self.delegate?.didStop(self)
	}

	private func handleNewConnection(_ nwConnection: NWConnection) {
		let connection = VNCConnection(self.name, connection: nwConnection, framebuffer: framebuffer, password: password)
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
		guard isRunning == false else {
			return
		}
	
		self.isRunning = true

		let stream = AsyncStream<CGImage>.makeStream(of: CGImage.self)
		let producer = (self.sourceView as? VNCFrameBufferProducer) ?? self.framebuffer
		let checkIfImageIsChanged = producer.checkIfImageIsChanged

		producer.startFramebufferUpdate(continuation: stream.continuation)

		self.updateBufferTask = Task {
			await withTaskCancellationHandler(operation: {
				for await image in stream.stream {
					await self.updateFramebufferRequest(cgImage: image, checkIfImageIsChanged: checkIfImageIsChanged)
				}

				producer.stopFramebufferUpdate()
			}, onCancel: {
				stream.continuation.finish()
			})
		}
	}

	private func stopFramebufferUpdates() {
		self.isRunning = false
		self.updateBufferTask?.cancel()
		self.updateBufferTask = nil
	}
	
	private func sendFrameBufferUpdate(connections: [VNCConnection], tiles: [VNCFramebuffer.VNCFramebufferTile], newSizePending: Bool) async {

		await withTaskGroup(of: Void.self) { group in
			let width = self.framebuffer.width
			let height = self.framebuffer.height
			
			connections.forEach { connection in
				group.addTask {
					await connection.sendFramebufferUpdate(tiles: tiles, width: width, height: height, newSizePending: newSizePending)
				}
			}

			await group.waitForAll()
		}
	}

	private func updateFramebufferRequest(cgImage: CGImage, checkIfImageIsChanged: Bool) async {
		let changedTiles = self.framebuffer.convertImageToTiles(cgImage: cgImage)
		let connections = self.activeConnections.filter {
			$0.sendFramebufferContinous
		}

		if changedTiles.tiles.isEmpty || connections.isEmpty {
			return
		}

		await self.sendFrameBufferUpdate(connections: connections, tiles: changedTiles.tiles, newSizePending: changedTiles.newSize)
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
	func vncConnectionResizeDesktop(_ connection: VNCConnection, screens: [VNCScreenDesktop]) {
		if let delegate = self.delegate {
			DispatchQueue.main.async {
				delegate.vncServer(self, clientDidResizeDesktop: screens)
			}
		}
	}

	func vncConnectionDidDisconnect(_ connection: VNCConnection, clientAddress: String) {
		connectionQueue.async(flags: .barrier) {
			self.logger.debug("Client at \(clientAddress) disconnected")

			self.connections.removeAll {
				return $0 === connection
			}
		}

		if let delegate = self.delegate {
			DispatchQueue.main.async {
				delegate.vncServer(self, clientDidDisconnect: clientAddress)
			}
		}
	}

	func vncConnection(_ connection: VNCConnection, didReceiveError error: Error) {
		#if DEBUG
			self.logger.debug("Client at \(connection) didReceiveError: \(error)")
		#endif

		if let delegate = self.delegate {
			DispatchQueue.main.async {
				delegate.vncServer(self, didReceiveError: error)
			}
		}
	}
}

// MARK: - VNCInputDelegate

extension VNCServer: VNCInputDelegate {
	func vncConnection(_ connection: VNCConnection, didReceiveKeyEvent key: UInt32, isDown: Bool) {
		guard allowRemoteInput else { return }

		if let delegate = self.delegate {
			DispatchQueue.main.async {
				delegate.vncServer(self, didReceiveKeyEvent: key, isDown: isDown)
			}
		}
	}

	func vncConnection(_ connection: VNCConnection, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8) {
		guard allowRemoteInput else { return }

		if let delegate = self.delegate {
			DispatchQueue.main.async {
				delegate.vncServer(self, didReceiveMouseEvent: x, y: Int(buttonMask), buttonMask: buttonMask)
			}
		}
	}
}
