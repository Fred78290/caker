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
	private var activeWrites = 0
	private var closePending = false
	private var superseded = false
	private var protocolVersion = SeamlessProtocol.version

	/// Encoded messages waiting for the writer. A guest that stops reading must not make the host buffer without bound.
	private struct Pending {
		var data: Data
		/// The window of a pointer motion: only that kind of message may be replaced by a newer one.
		var motionWindow: UInt32?
	}

	private var pending: [Pending] = []
	/// Bytes of `pending` plus the message being written, until it is written.
	private var pendingBytes = 0
	private var draining = false

	/// Room for the biggest clipboard (32 MiB) plus ordinary input queued behind it.
	static let maxPendingBytes = SeamlessProtocol.maxClipboardTotalBytes + 8 * 1024 * 1024
	static let maxPendingMessages = 4096

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
		// Likewise a guest older than the clipboard.
		if case .clipboard = message, negotiatedVersion < SeamlessProtocol.clipboardVersion { return }
		// And a guest older than the clipboard items.
		if case .clipboardItems = message, negotiatedVersion < SeamlessProtocol.clipboardItemsVersion { return }
		// And a guest older than the keyboard layout message.
		if case .keyboardLayout = message, negotiatedVersion < SeamlessProtocol.keyboardLayoutVersion { return }

		guard let data = try? SeamlessCodec.encode(message) else { return }

		var motionWindow: UInt32?

		if case .pointerMotion(let id, _, _) = message { motionWindow = id }

		lock.lock()

		guard !closed else {
			lock.unlock()
			return
		}

		// A motion queued right behind another motion of the same window supersedes it: nothing sits between them, so the
		// order of keys and buttons is untouched. Anything else is never dropped or reordered.
		if let motionWindow, let last = pending.indices.last, pending[last].motionWindow == motionWindow {
			pendingBytes += data.count - pending[last].data.count
			pending[last].data = data
			lock.unlock()
			return
		}

		guard pending.count < Self.maxPendingMessages, pendingBytes + data.count <= Self.maxPendingBytes else {
			// Sustained backpressure: the guest is not reading. Dropping a key release or a button transition would leave
			// input stuck down in the guest, so the connection goes instead.
			lock.unlock()
			self.close()
			return
		}

		pending.append(Pending(data: data, motionWindow: motionWindow))
		pendingBytes += data.count

		let startDrain = !draining

		draining = true
		lock.unlock()

		if startDrain {
			self.writeQueue.async { [self] in
				self.drain()
			}
		}
	}

	private func drain() {
		while true {
			lock.lock()

			guard !closed, !pending.isEmpty else {
				// Closed: what is queued will never be sent.
				pending.removeAll()
				pendingBytes = 0
				draining = false
				lock.unlock()
				return
			}

			let next = pending.removeFirst()

			lock.unlock()

			writeAll(next.data)

			lock.lock()
			pendingBytes = max(0, pendingBytes - next.data.count)
			lock.unlock()
		}
	}

	private func writeAll(_ data: Data) {
		lock.lock()
		let descriptor = closed ? -1 : fd

		if descriptor >= 0 {
			activeWrites += 1
		}

		lock.unlock()

		guard descriptor >= 0 else { return }

		// The descriptor is only closed once no write can use it: a number closed under a writer could be reused
		// by the replacement session, and the old session's bytes would go to it.
		defer {
			lock.lock()
			activeWrites -= 1

			if activeWrites == 0 && closePending && fd >= 0 {
				Darwin.close(fd)
				fd = -1
			}

			lock.unlock()
		}

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

	/// Replaced by a newer connection, or the server stopped: its delegate callbacks must no longer start anything.
	fileprivate func markSuperseded() {
		lock.lock()
		superseded = true
		lock.unlock()
	}

	fileprivate var isSuperseded: Bool {
		lock.lock()
		defer { lock.unlock() }
		return superseded
	}

	var pendingMessageCountForTesting: Int {
		lock.lock()
		defer { lock.unlock() }
		return pending.count
	}

	func closeDescriptorForTesting() { closeDescriptor() }

	fileprivate func closeDescriptor() {
		lock.lock()
		defer { lock.unlock() }

		closed = true

		guard fd >= 0 else { return }

		if activeWrites > 0 {
			// A writer is still in flight: wake it, the last one to leave closes the descriptor.
			Darwin.shutdown(fd, SHUT_RDWR)
			closePending = true
		} else {
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
	/// Serializes `start()` and `stop()`: the listener is published under `lock` only at the end of `start()`, so a `stop()`
	/// running in between would find nothing to tear down and leave a live listener, the socket file and the lock behind.
	private let lifecycleLock = NSLock()
	private var listenSource: DispatchSourceRead?
	private var current: SeamlessSession?
	private var listenerLock: Int32 = -1
	/// Changes whenever the listener starts or stops: an accept that was already running for an older one must not install a session.
	private var listenGeneration = 0
	private var scale: UInt32 = 120
	private let logger = Logger("SeamlessServer")

	/// Frames decoded but not yet applied by the delegate; the reader waits above this, so a guest that floods
	/// frames can't make the host buffer without bound.
	private static let maxFramesInFlight = 8

	/// The same for every other message (titles, hints, cursors...): small, but a flood of them would otherwise
	/// pile up on the main queue. Messages stay in order, the reader just waits.
	private static let maxControlMessagesInFlight = 256

	/// Bytes of decoded control payloads (clipboard images included) waiting for the delegate: the message count alone
	/// would let 256 clipboards of 32 MiB pile up. Room for the biggest clipboard plus ordinary messages behind it.
	static let maxControlBytesInFlight = SeamlessProtocol.maxClipboardTotalBytes + 8 * 1024 * 1024

	/// A byte budget the reader takes from before handing a payload to the delegate and the delegate gives back when done.
	/// Taking is in arrival order (the reader is the only taker), so messages are never reordered.
	final class ByteBudget: @unchecked Sendable {
		private let condition = NSCondition()
		private let limit: Int
		private var used = 0

		init(limit: Int) {
			self.limit = limit
		}

		var inUse: Int {
			condition.lock()
			defer { condition.unlock() }
			return used
		}

		/// Waits until `bytes` fit. A request bigger than the whole budget is admitted once nothing else is held, so it can't wait forever.
		func acquire(_ bytes: Int) {
			condition.lock()
			defer { condition.unlock() }

			while used > 0 && used + bytes > limit {
				condition.wait()
			}

			used += bytes
		}

		func release(_ bytes: Int) {
			condition.lock()
			used = max(0, used - bytes)
			condition.broadcast()
			condition.unlock()
		}
	}

	/// The outcome of taking the right to listen on a seamless socket.
	public enum ListenerLockResult {
		case acquired(Int32)
		/// Another process (Caker.app, a `caked vmrun --ui`, a tunnel) already shows the windows of this guest.
		case contended
		/// The lock file could not be opened or locked: nothing is shown by anyone, the setup is wrong.
		case failed(String)
	}

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
		lifecycleLock.lock()
		defer { lifecycleLock.unlock() }

		let lockFD: Int32

		switch Self.tryAcquireListenerLock(for: socketPath) {
		case .acquired(let descriptor):
			lockFD = descriptor
		case .contended:
			throw ServiceError(String(format: String(localized: "seamless: the windows of this VM are already shown by another process (%@)"), socketPath))
		case .failed(let reason):
			throw ServiceError(String(format: String(localized: "seamless: cannot take the listener lock of %@: %@"), socketPath, reason))
		}

		let listener = socket(AF_UNIX, SOCK_STREAM, 0)

		guard listener >= 0 else {
			Self.releaseListenerLock(lockFD)
			throw ServiceError(String(format: String(localized: "seamless: socket() failed: %@"), String(cString: strerror(errno))))
		}

		var address = sockaddr_un()
		address.sun_family = sa_family_t(AF_UNIX)

		let capacity = MemoryLayout.size(ofValue: address.sun_path)
		let pathBytes = Array(socketPath.utf8CString)

		guard pathBytes.count <= capacity else {
			Darwin.close(listener)
			Self.releaseListenerLock(lockFD)
			throw ServiceError(String(format: String(localized: "seamless: socket path is too long: %@"), socketPath))
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
			throw ServiceError(String(format: String(localized: "seamless: cannot bind %@: %@"), socketPath, reason))
		}

		// The guest controls what is shown on the desktop, so only this user may connect. Nothing accepts before
		// listen(), and a socket that stays open to others is never published.
		guard chmod(socketPath, 0o600) == 0 else {
			let reason = String(cString: strerror(errno))
			Darwin.close(listener)
			unlink(socketPath)
			Self.releaseListenerLock(lockFD)
			throw ServiceError(String(format: String(localized: "seamless: cannot restrict %@: %@"), socketPath, reason))
		}

		guard Darwin.listen(listener, 4) == 0 else {
			let reason = String(cString: strerror(errno))
			Darwin.close(listener)
			unlink(socketPath)
			Self.releaseListenerLock(lockFD)
			throw ServiceError(String(format: String(localized: "seamless: listen failed: %@"), reason))
		}

		_ = fcntl(listener, F_SETFL, fcntl(listener, F_GETFL) | O_NONBLOCK)

		let source = DispatchSource.makeReadSource(fileDescriptor: listener, queue: DispatchQueue(label: "com.aldunelabs.caker.seamless.accept"))

		lock.lock()
		listenGeneration += 1
		let generation = listenGeneration
		lock.unlock()

		source.setEventHandler { [weak self] in
			self?.acceptConnection(listener, generation: generation)
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
		lifecycleLock.lock()
		defer { lifecycleLock.unlock() }

		lock.lock()
		let source = listenSource
		let session = current
		let lockFD = listenerLock
		listenSource = nil
		current = nil
		listenerLock = -1
		listenGeneration += 1
		lock.unlock()

		source?.cancel()
		session?.markSuperseded()
		session?.close()

		// Only the owner removes the socket: without the lock it belongs to someone else.
		if lockFD >= 0 {
			unlink(socketPath)
			Self.releaseListenerLock(lockFD)
		}
	}

	private func acceptConnection(_ listener: Int32, generation: Int) {
		let fd = Darwin.accept(listener, nil, nil)

		guard fd >= 0 else { return }

		// Cancelling a dispatch source does not interrupt a handler that is running: check, under the lock that
		// installs the session, that this listener is still the current one.
		self.install(fd: fd, generation: generation)
	}

	/// Takes the right to listen on the seamless socket at `socketPath`: a lock on `<socketPath>.lock`, held while the
	/// listener lives (the kernel drops it when the process dies, so a crash leaves nothing stale). Returns nil when
	/// another process holds it: the windows of that guest are already shown by Caker.app, a `caked vmrun --ui` or a
	/// tunnel. Probing the socket by connecting would not do, the listener would take the probe for the guest.
	public static func acquireListenerLock(for socketPath: String) -> Int32? {
		if case .acquired(let descriptor) = tryAcquireListenerLock(for: socketPath) {
			return descriptor
		}

		return nil
	}

	/// Same as `acquireListenerLock(for:)`, but tells a lock held by another process apart from a lock file that
	/// can't be opened (a missing directory, a permission): only the first means "someone else shows the windows".
	public static func tryAcquireListenerLock(for socketPath: String) -> ListenerLockResult {
		let descriptor = open(socketPath + ".lock", O_CREAT | O_RDWR | O_CLOEXEC, 0o600)

		guard descriptor >= 0 else { return .failed(String(cString: strerror(errno))) }

		guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
			let code = errno

			Darwin.close(descriptor)

			return code == EWOULDBLOCK ? .contended : .failed(String(cString: strerror(code)))
		}

		return .acquired(descriptor)
	}

	public static func releaseListenerLock(_ descriptor: Int32) {
		flock(descriptor, LOCK_UN)
		Darwin.close(descriptor)
	}

	/// Serves a guest connection that is already established, instead of one accepted on the unix socket: a
	/// client that receives the guest's stream from elsewhere (a gRPC tunnel from another host) hands its end of
	/// it here. The server takes the descriptor over, and replaces the current session like a new connection does.
	public func attach(fd: Int32) {
		self.install(fd: fd, generation: nil)
	}

	/// `generation` is set for a connection accepted by the listener: it is dropped when that listener is no longer current.
	private func install(fd: Int32, generation: Int?) {
		// BSD sockets inherit O_NONBLOCK from the (non blocking) listener, the reader thread wants blocking reads.
		_ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK)

		var one: Int32 = 1

		setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))

		let session = SeamlessSession(fd: fd)

		lock.lock()

		if let generation, generation != listenGeneration {
			lock.unlock()
			Darwin.close(fd)
			return
		}

		let previous = current
		current = session
		lock.unlock()

		// Marked before the new reader exists: a start callback of the old session still queued must not run after the new one's.
		previous?.markSuperseded()
		previous?.close()

		let thread = Thread { [weak self] in
			self?.read(session)
		}

		thread.name = "seamless-reader"
		thread.start()
	}

	/// Whether `sessionDidStart` reached the delegate; only touched on the delegate queue, where start and end are delivered in order.
	private final class StartState: @unchecked Sendable {
		var delivered = false
	}

	private func read(_ session: SeamlessSession) {
		let startState = StartState()
		var decoder = SeamlessFrameDecoder()
		var helloDone = false
		let inFlight = DispatchSemaphore(value: Self.maxFramesInFlight)
		let controlInFlight = DispatchSemaphore(value: Self.maxControlMessagesInFlight)
		let controlBytes = ByteBudget(limit: Self.maxControlBytesInFlight)
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
					// A start that was dropped (session replaced) has no end either.
					guard startState.delivered, let self, let delegate = self.delegate else { return }
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
							logger.warn("Seamless guest \(name) speaks protocol \(version), the host \(SeamlessProtocol.version): \(version < SeamlessProtocol.axisVersion ? "mouse wheel scrolling and the clipboard are" : "the clipboard is") disabled until its agent is updated")
						}

						helloDone = true
						session.negotiate(version)
						session.send(.helloAck(version: version, scale120: outputScale120))
						delegateQueue.async { [weak self] in
							guard let self, let delegate = self.delegate else { return }

							// Replaced (or the server stopped) between the hello and this delivery: a start now would
							// install a dead session over the newer one the delegate may already have.
							guard !session.isSuperseded else { return }

							startState.delivered = true
							delegate.seamlessServer(self, sessionDidStart: session, guestName: name)
						}
						continue
					}

					if case .hello = message {
						throw SeamlessProtocolError.invalidValue("duplicate hello")
					}

					var isFrame = false

					if case .windowFrame = message { isFrame = true }

					let slots = isFrame ? inFlight : controlInFlight
					// Frames are bounded by their own small slot count; everything else also reserves its payload bytes.
					let reserved = isFrame ? 0 : payload.count + 64

					slots.wait()

					if reserved > 0 {
						controlBytes.acquire(reserved)
					}

					delegateQueue.async { [weak self] in
						defer {
							if reserved > 0 {
								controlBytes.release(reserved)
							}

							slots.signal()
						}

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
