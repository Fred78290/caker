import CakeAgentLib
import Darwin
import Foundation

public protocol SeamlessServerDelegate: AnyObject, Sendable {
	/// The guest said hello with a compatible version; windows may follow.
	func seamlessServer(_ server: SeamlessServer, sessionDidStart session: SeamlessSession, guestName: String)
	func seamlessServer(_ server: SeamlessServer, session: SeamlessSession, didReceive message: SeamlessGuestMessage)
	/// The connection ended (guest gone, protocol error, or replaced): every window of the session must go.
	func seamlessServer(_ server: SeamlessServer, sessionDidEnd session: SeamlessSession)
}

/// One guest compositor connection.
public final class SeamlessSession: @unchecked Sendable {
	private let lock = NSLock()
	private let writeQueue = DispatchQueue(label: "com.aldunelabs.caker.seamless.write")
	private var fd: Int32
	private var closed = false
	private var protocolVersion = SeamlessProtocol.version

	init(fd: Int32) {
		self.fd = fd
	}

	/// The protocol version agreed with the guest, the lower of the two. Messages a version doesn't know are not sent.
	public var negotiatedVersion: UInt16 {
		lock.lock()
		defer { lock.unlock() }
		return protocolVersion
	}

	func negotiate(_ version: UInt16) {
		lock.lock()
		protocolVersion = version
		lock.unlock()
	}

	public var isClosed: Bool {
		lock.lock()
		defer { lock.unlock() }
		return closed
	}

	/// Queues a message, never blocks the caller (the main thread sends input through here).
	public func send(_ message: SeamlessHostMessage) {
		// A guest on protocol 1 has no scrolling: the message would make it close the connection.
		if case .pointerAxis = message, negotiatedVersion < SeamlessProtocol.axisVersion { return }

		guard let data = try? SeamlessCodec.encode(message) else { return }

		self.writeQueue.async { [self] in
			self.writeAll(data)
		}
	}

	private func writeAll(_ data: Data) {
		lock.lock()
		let descriptor = closed ? -1 : fd
		lock.unlock()

		guard descriptor >= 0 else { return }

		var failed = false

		data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
			var sent = 0

			while sent < raw.count {
				let n = Darwin.write(descriptor, raw.baseAddress! + sent, raw.count - sent)

				if n < 0 {
					if errno == EINTR { continue }
					failed = true
					return
				}

				sent += n
			}
		}

		if failed {
			self.close()
		}
	}

	/// Wakes the reader, which owns the descriptor and closes it.
	public func close() {
		lock.lock()
		defer { lock.unlock() }

		guard !closed else { return }

		closed = true
		Darwin.shutdown(fd, SHUT_RDWR)
	}

	fileprivate func closeDescriptor() {
		lock.lock()
		defer { lock.unlock() }

		closed = true

		if fd >= 0 {
			Darwin.close(fd)
			fd = -1
		}
	}

	fileprivate var descriptor: Int32 {
		lock.lock()
		defer { lock.unlock() }
		return fd
	}
}

/// Listens on a unix socket for the guest compositor. In a VM the socket is the target of a
/// `connect://vsock:5100/<path>` socket device, so the guest dials vsock and ends up here.
///
/// A new connection replaces the current one (the guest compositor restarted).
public final class SeamlessServer: @unchecked Sendable {
	public let socketPath: String
	private let delegateQueue: DispatchQueue
	private weak var delegate: SeamlessServerDelegate?
	private let lock = NSLock()
	private var listenSource: DispatchSourceRead?
	private var current: SeamlessSession?
	private var listenerLock: Int32 = -1
	private var scale: UInt32 = 120
	private let logger = Logger("SeamlessServer")

	/// Frames decoded but not yet applied by the delegate; the reader waits above this, so a guest that floods
	/// frames can't make the host buffer without bound.
	private static let maxFramesInFlight = 8

	public init(socketPath: String, delegate: SeamlessServerDelegate, delegateQueue: DispatchQueue = .main) {
		self.socketPath = socketPath
		self.delegate = delegate
		self.delegateQueue = delegateQueue
	}

	/// Output scale announced to the guest, 120 == 1x. Sent to the current session when it changes.
	public var outputScale120: UInt32 {
		get {
			lock.lock()
			defer { lock.unlock() }
			return scale
		}
		set {
			lock.lock()
			let changed = scale != newValue
			scale = newValue
			let session = current
			lock.unlock()

			if changed {
				session?.send(.output(scale120: newValue))
			}
		}
	}

	public func start() throws {
		guard let lockFD = Self.acquireListenerLock(for: socketPath) else {
			throw ServiceError("seamless: the windows of this VM are already shown by another process (\(socketPath))")
		}

		let listener = socket(AF_UNIX, SOCK_STREAM, 0)

		guard listener >= 0 else {
			Self.releaseListenerLock(lockFD)
			throw ServiceError("seamless: socket() failed: \(String(cString: strerror(errno)))")
		}

		var address = sockaddr_un()
		address.sun_family = sa_family_t(AF_UNIX)

		let capacity = MemoryLayout.size(ofValue: address.sun_path)
		let pathBytes = Array(socketPath.utf8CString)

		guard pathBytes.count <= capacity else {
			Darwin.close(listener)
			Self.releaseListenerLock(lockFD)
			throw ServiceError("seamless: socket path is too long: \(socketPath)")
		}

		withUnsafeMutableBytes(of: &address.sun_path) { dst in
			pathBytes.withUnsafeBytes { dst.copyMemory(from: $0) }
		}

		unlink(socketPath)

		let bound = withUnsafePointer(to: &address) {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
				Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
			}
		}

		guard bound == 0 else {
			let reason = String(cString: strerror(errno))
			Darwin.close(listener)
			Self.releaseListenerLock(lockFD)
			throw ServiceError("seamless: cannot bind \(socketPath): \(reason)")
		}

		// The guest controls what is shown on the desktop, so only this user may connect.
		chmod(socketPath, 0o600)

		guard Darwin.listen(listener, 4) == 0 else {
			let reason = String(cString: strerror(errno))
			Darwin.close(listener)
			unlink(socketPath)
			Self.releaseListenerLock(lockFD)
			throw ServiceError("seamless: listen failed: \(reason)")
		}

		_ = fcntl(listener, F_SETFL, fcntl(listener, F_GETFL) | O_NONBLOCK)

		let source = DispatchSource.makeReadSource(fileDescriptor: listener, queue: DispatchQueue(label: "com.aldunelabs.caker.seamless.accept"))

		source.setEventHandler { [weak self] in
			self?.acceptConnection(listener)
		}

		source.setCancelHandler {
			Darwin.close(listener)
		}

		lock.lock()
		listenSource = source
		listenerLock = lockFD
		lock.unlock()

		source.resume()
	}

	public func stop() {
		lock.lock()
		let source = listenSource
		let session = current
		let lockFD = listenerLock
		listenSource = nil
		current = nil
		listenerLock = -1
		lock.unlock()

		source?.cancel()
		session?.close()

		// Only the owner removes the socket: without the lock it belongs to someone else.
		if lockFD >= 0 {
			unlink(socketPath)
			Self.releaseListenerLock(lockFD)
		}
	}

	private func acceptConnection(_ listener: Int32) {
		let fd = Darwin.accept(listener, nil, nil)

		guard fd >= 0 else { return }

		self.attach(fd: fd)
	}

	/// Takes the right to listen on the seamless socket at `socketPath`: a lock on `<socketPath>.lock`, held while the
	/// listener lives (the kernel drops it when the process dies, so a crash leaves nothing stale). Returns nil when
	/// another process holds it: the windows of that guest are already shown by Caker.app, a `caked vmrun --ui` or a
	/// tunnel. Probing the socket by connecting would not do, the listener would take the probe for the guest.
	public static func acquireListenerLock(for socketPath: String) -> Int32? {
		let descriptor = open(socketPath + ".lock", O_CREAT | O_RDWR | O_CLOEXEC, 0o600)

		guard descriptor >= 0 else { return nil }

		guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
			Darwin.close(descriptor)
			return nil
		}

		return descriptor
	}

	public static func releaseListenerLock(_ descriptor: Int32) {
		flock(descriptor, LOCK_UN)
		Darwin.close(descriptor)
	}

	/// Serves a guest connection that is already established, instead of one accepted on the unix socket: a
	/// client that receives the guest's stream from elsewhere (a gRPC tunnel from another host) hands its end of
	/// it here. The server takes the descriptor over, and replaces the current session like a new connection does.
	public func attach(fd: Int32) {
		// BSD sockets inherit O_NONBLOCK from the (non blocking) listener, the reader thread wants blocking reads.
		_ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK)

		var one: Int32 = 1

		setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))

		let session = SeamlessSession(fd: fd)

		lock.lock()
		let previous = current
		current = session
		lock.unlock()

		previous?.close()

		let thread = Thread { [weak self] in
			self?.read(session)
		}

		thread.name = "seamless-reader"
		thread.start()
	}

	private func read(_ session: SeamlessSession) {
		var decoder = SeamlessFrameDecoder()
		var helloDone = false
		let inFlight = DispatchSemaphore(value: Self.maxFramesInFlight)
		let chunk = UnsafeMutableRawBufferPointer.allocate(byteCount: 256 * 1024, alignment: 16)

		defer {
			chunk.deallocate()
			session.closeDescriptor()

			lock.lock()

			if current === session {
				current = nil
			}

			lock.unlock()

			if helloDone {
				delegateQueue.async { [weak self] in
					guard let self, let delegate = self.delegate else { return }
					delegate.seamlessServer(self, sessionDidEnd: session)
				}
			}
		}

		while !session.isClosed {
			let n = Darwin.read(session.descriptor, chunk.baseAddress!, chunk.count)

			if n < 0 && errno == EINTR { continue }
			if n <= 0 { return }

			decoder.append(UnsafeRawBufferPointer(rebasing: chunk[0..<n]))

			do {
				while let (type, payload) = try decoder.next() {
					let message = try SeamlessCodec.decodeGuest(type: type, payload: payload)

					if !helloDone {
						guard case .hello(let version, let name) = message else {
							throw SeamlessProtocolError.invalidValue("the first message must be hello")
						}

						guard (SeamlessProtocol.minimumVersion...SeamlessProtocol.version).contains(version) else {
							throw SeamlessProtocolError.invalidValue("unsupported protocol version \(version)")
						}

						if version < SeamlessProtocol.version {
							logger.warn("Seamless guest \(name) speaks protocol \(version), the host \(SeamlessProtocol.version): mouse wheel scrolling is disabled until its agent is updated")
						}

						helloDone = true
						session.negotiate(version)
						session.send(.helloAck(version: version, scale120: outputScale120))
						delegateQueue.async { [weak self] in
							guard let self, let delegate = self.delegate else { return }
							delegate.seamlessServer(self, sessionDidStart: session, guestName: name)
						}
						continue
					}

					if case .hello = message {
						throw SeamlessProtocolError.invalidValue("duplicate hello")
					}

					var isFrame = false

					if case .windowFrame = message { isFrame = true }

					if isFrame { inFlight.wait() }

					delegateQueue.async { [weak self] in
						defer { if isFrame { inFlight.signal() } }

						guard let self, let delegate = self.delegate else { return }
						delegate.seamlessServer(self, session: session, didReceive: message)
					}
				}
			} catch {
				logger.warn("Seamless guest protocol error, closing the connection: \(error)")
				return
			}
		}
	}
}
