import AppKit
import ArgumentParser
import CakeAgentLib
import Darwin
import Foundation
import Metal
import Network
import QuartzCore

public protocol VZVNCServer {
	var delegate: VNCServerDelegate? { get set }
	var urls: [URL] { get }
	/// Arms/disarms a `caked record` recording tap on every client connection's `VNCInputHandler` —
	/// see `VNCInputHandler.actionRecorder`. nil (the default) for ordinary provisioning/VNC-viewing
	/// sessions; `VirtualMachine.setActionRecorder(_:)` is the usual way to reach this.
	var actionRecorder: RecordedActionHandler? { get set }
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

public enum VNCFrameUpdateState {
	case frame(CGImage)
	case cursor(NSCursor)
	case cursorPosition(NSPoint)
}

public protocol VNCFrameBufferProducer {
	var cursor: NSCursor? { get }
	var cursorPosition: NSPoint? { get }
	var bitmapInfos: CGBitmapInfo { get }
	var cgImage: CGImage? { get }
	func startFramebufferUpdate(continuation: AsyncStream<VNCFrameUpdateState>.Continuation)
	func stopFramebufferUpdate()
}

open class VNCServer: NSObject, VZVNCServer, @unchecked Sendable {
	public weak var delegate: VNCServerDelegate?
	public private(set) var port: UInt16
	public private(set) var isRunning = false
	// Tracks "has start() been called and not yet stopped" — distinct from `isRunning`, which only
	// flips true once the NWListener's async stateUpdateHandler reports `.ready` (startFramebufferUpdates()).
	// stop() must tear down (cancel the listener, etc.) even if that `.ready` callback never fired yet —
	// gating on `isRunning` there let a VNCServer stopped before its listener came up skip teardown
	// entirely, leaking the still-active NWListener (and its bound socket) indefinitely.
	private var isStarted = false
	public var allowRemoteInput = true  // Controls if remote inputs are accepted
	public var password: String?  // VNC Auth password
	/// See `VZVNCServer.actionRecorder`. Setting this after clients are already connected also
	/// propagates to them, so `caked record` can arm it any time relative to the operator's own
	/// VNC client connecting.
	public var actionRecorder: RecordedActionHandler? {
		didSet {
			connectionQueue.async(flags: .barrier) {
				self.connections.forEach { $0.actionRecorder = self.actionRecorder }
			}
		}
	}

	private let logger = Logger("VNCServer")
	private var listener: NWListener!
	private var connections: [VNCConnection] = []
	private var framebuffer: VNCFramebuffer
	private let connectionQueue: DispatchQueue
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

	#if TRACE_DEINIT
		deinit {
			print("Deinitializing VNCServer")
		}
	#endif

	public init(_ sourceView: NSView, name: String, password: String? = nil, port: UInt16 = 0, allInet: Bool) throws {
		try newKeyMapper().setupKeyMapper()

		self.connectionQueue = DispatchQueue(label: "vnc.server.connections-\(name)", attributes: .concurrent)
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
			let addresses: [String: IP.V4] = VZSharedNetwork.addresses()

			return addresses.compactMap { interface in
				if let password = password {
					return URL(string: "vnc://:\(password)@\(interface.value.description):\(port)")
				} else {
					return URL(string: "vnc://\(interface.value.description):\(port)")
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
		guard !isStarted else { return }
		isStarted = true

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
		guard isStarted else { return }
		isStarted = false

		self.delegate?.willStop(self)

		listener?.cancel()
		listener = nil

		stopFramebufferUpdates()

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
		connection.actionRecorder = self.actionRecorder

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

		self.updateBufferTask = Task {
			let stream = AsyncStream<VNCFrameUpdateState>.makeStream(of: VNCFrameUpdateState.self)

			self.framebuffer.startFramebufferUpdate(continuation: stream.continuation)

			await withTaskCancellationHandler(
				operation: {
					for await update in stream.stream {
						switch update {
						case .frame(let image):
							await self.updateFramebufferRequest(cgImage: image)
						case .cursor(let cursor):
							await self.updateCursor(cursor: cursor)
						case .cursorPosition(let pos):
							await self.updateCursorPosition(cursorPosition: pos)
						}
					}

					self.framebuffer.stopFramebufferUpdate()

					self.isRunning = false
					self.updateBufferTask = nil
				},
				onCancel: {
					stream.continuation.finish()
				})
		}
	}

	private func stopFramebufferUpdates() {
		self.updateBufferTask?.cancel()
	}

	private func sendCursorUpdate(connections: [VNCConnection], cursor: VNCCursor) async {
		await withTaskGroup(of: Void.self) { group in
			connections.forEach { connection in
				group.addTask {
					await connection.sendCursorUpdate(cursor: cursor)
				}
			}

			await group.waitForAll()
		}
	}

	private func sendCursorPositionUpdate(connections: [VNCConnection], cursorPosition: VNCPoint) async {
		await withTaskGroup(of: Void.self) { group in
			connections.forEach { connection in
				group.addTask {
					try? await connection.sendCursorPosition(cursorPosition: cursorPosition)
				}
			}

			await group.waitForAll()
		}
	}

	private func sendFrameBufferUpdate(connections: [VNCConnection], tiles: [VNCFramebuffer.VNCFramebufferTile], newSizePending: Bool) async {
		var cursorPosition: VNCPoint? = nil

		if let pos = self.framebuffer.cursorPosition {
			cursorPosition = VNCPoint(pos)
		}

		await withTaskGroup(of: Void.self) { group in
			connections.forEach { connection in
				group.addTask {
					await connection.sendFramebufferUpdate(tiles: tiles, size: self.framebuffer.viewSize, cursorPosition: cursorPosition, newSizePending: newSizePending)
				}
			}

			await group.waitForAll()
		}
	}

	private func updateCursorPosition(cursorPosition: NSPoint) async {
		self.framebuffer.cursorPosition = cursorPosition

		await self.sendCursorPositionUpdate(connections: self.activeConnections, cursorPosition: VNCPoint(cursorPosition))
	}

	private func updateCursor(cursor: NSCursor) async {
		if let vncCursor = cursor.vncCursor {
			await self.sendCursorUpdate(connections: self.activeConnections, cursor: vncCursor)
		}
	}

	private func updateFramebufferRequest(cgImage: CGImage) async {
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
