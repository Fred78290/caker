import Darwin
import Foundation

/// A fake guest compositor: connects like the real one would (here straight to the unix socket instead of through
/// vsock), opens a window with an animated square, follows resize and close requests, draws a dot under the pointer
/// and opens a popup on right click. It is the reference client for the protocol, and what the tests and
/// `caked seamless-demo` use to exercise the host side without booting a VM.
public final class SeamlessDemoGuest: @unchecked Sendable {
	public struct Event: Equatable, Sendable {
		public var description: String
	}

	private let socketPath: String
	private let lock = NSLock()
	private var fd: Int32 = -1
	private var running = false
	private var scale120: UInt32 = 120
	private var width: UInt32 = 480  // logical
	private var height: UInt32 = 320
	private var pointer: (x: Float, y: Float)?
	private var popupOpen = false
	private var events: [String] = []

	private let windowID: UInt32 = 1
	private let popupID: UInt32 = 2
	private let frameInterval: TimeInterval

	public init(socketPath: String, frameInterval: TimeInterval = 1.0 / 30.0) {
		self.socketPath = socketPath
		self.frameInterval = frameInterval
	}

	public var receivedEvents: [String] {
		lock.lock()
		defer { lock.unlock() }
		return events
	}

	private func record(_ text: String) {
		lock.lock()
		events.append(text)
		lock.unlock()
	}

	public func connect() throws {
		let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)

		guard descriptor >= 0 else { throw ServiceError("demo guest: socket failed") }

		var address = sockaddr_un()
		address.sun_family = sa_family_t(AF_UNIX)

		let path = Array(socketPath.utf8CString)

		guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else {
			Darwin.close(descriptor)
			throw ServiceError("demo guest: socket path too long")
		}

		withUnsafeMutableBytes(of: &address.sun_path) { dst in
			path.withUnsafeBytes { dst.copyMemory(from: $0) }
		}

		let result = withUnsafePointer(to: &address) {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
				Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
			}
		}

		guard result == 0 else {
			let reason = String(cString: strerror(errno))
			Darwin.close(descriptor)
			throw ServiceError("demo guest: cannot connect to \(socketPath): \(reason)")
		}

		var one: Int32 = 1
		setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))

		lock.lock()
		fd = descriptor
		running = true
		lock.unlock()
	}

	/// Starts the reader and the animation, returns at once.
	public func start() throws {
		try send(.hello(version: SeamlessProtocol.version, name: "demo-guest"))

		let reader = Thread { [self] in self.readLoop() }

		reader.name = "seamless-demo-reader"
		reader.start()
	}

	public func stop() {
		lock.lock()
		let wasRunning = running
		running = false
		let descriptor = fd
		lock.unlock()

		if wasRunning && descriptor >= 0 {
			Darwin.shutdown(descriptor, SHUT_RDWR)
		}
	}

	private var isRunning: Bool {
		lock.lock()
		defer { lock.unlock() }
		return running
	}

	private func send(_ message: SeamlessGuestMessage) throws {
		let data = try SeamlessCodec.encode(message)

		lock.lock()
		defer { lock.unlock() }

		guard fd >= 0 else { return }

		try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
			var sent = 0

			while sent < raw.count {
				let n = Darwin.write(fd, raw.baseAddress! + sent, raw.count - sent)

				if n < 0 {
					if errno == EINTR { continue }
					throw ServiceError("demo guest: write failed")
				}

				sent += n
			}
		}
	}

	// MARK: Reading host messages

	private func readLoop() {
		var decoder = SeamlessFrameDecoder()
		let chunk = UnsafeMutableRawBufferPointer.allocate(byteCount: 64 * 1024, alignment: 16)

		defer {
			chunk.deallocate()
			stop()

			lock.lock()
			if fd >= 0 {
				Darwin.close(fd)
				fd = -1
			}
			lock.unlock()
		}

		while isRunning {
			let n = Darwin.read(fd, chunk.baseAddress!, chunk.count)

			if n < 0 && errno == EINTR { continue }
			if n <= 0 { return }

			decoder.append(UnsafeRawBufferPointer(rebasing: chunk[0..<n]))

			do {
				while let (type, payload) = try decoder.next() {
					handle(try SeamlessCodec.decodeHost(type: type, payload: payload))
				}
			} catch {
				record("protocol error: \(error)")
				return
			}
		}
	}

	private func handle(_ message: SeamlessHostMessage) {
		switch message {
		case .helloAck(_, let scale):
			lock.lock()
			scale120 = scale
			lock.unlock()
			record("helloAck scale=\(scale)")
			openWindow()
		case .output(let scale):
			lock.lock()
			scale120 = scale
			lock.unlock()
			record("output scale=\(scale)")
		case .windowResize(let id, let w, let h):
			record("resize \(id) \(w)x\(h)")

			if id == windowID {
				lock.lock()
				width = w
				height = h
				lock.unlock()
				try? sendFrame(full: true)
			}
		case .windowClose(let id):
			record("close \(id)")

			if id == windowID {
				try? send(.windowDestroy(id: windowID))
				stop()
			} else if id == popupID {
				closePopup()
			}
		case .windowFocus(let id, let focused):
			record("focus \(id) \(focused)")
		case .pointerEnter(let id, let x, let y):
			record("enter \(id) \(Int(x)),\(Int(y))")
		case .pointerLeave(let id):
			record("leave \(id)")
		case .pointerMotion(let id, let x, let y):
			if id == windowID {
				lock.lock()
				pointer = (x, y)
				lock.unlock()
			}

			record("motion \(id) \(Int(x)),\(Int(y))")
		case .pointerButton(let id, let button, let pressed):
			record("button \(id) \(String(button, radix: 16)) \(pressed)")

			if id == windowID, button == SeamlessProtocol.buttonRight, pressed {
				openPopup()
			} else if id == popupID, pressed {
				closePopup()
			} else if id == windowID, button == SeamlessProtocol.buttonLeft, pressed, popupOpen {
				closePopup()
			}
		case .pointerAxis(let id, let dx, let dy, let source):
			record("axis \(id) \(Int(dx)),\(Int(dy)) \(source)")
		case .key(let code, let pressed):
			record("key \(code) \(pressed)")
		}
	}

	// MARK: Drawing

	private func pixelSize() -> (Int, Int) {
		lock.lock()
		defer { lock.unlock() }

		let k = Double(scale120) / 120.0

		return (max(Int((Double(width) * k).rounded()), 1), max(Int((Double(height) * k).rounded()), 1))
	}

	private func openWindow() {
		try? send(.windowCreate(SeamlessWindowInfo(id: windowID, title: "Seamless demo", appID: "com.aldunelabs.caker.demo")))
		try? send(.windowHints(id: windowID, hints: SeamlessSizeHints(minWidth: 160, minHeight: 120)))
		try? send(.cursor(id: windowID, shape: "crosshair"))
		try? sendFrame(full: true)

		let animator = Thread { [self] in self.animate() }

		animator.name = "seamless-demo-animator"
		animator.start()
	}

	private var step = 0
	private var lastBox: SeamlessRect?

	private func animate() {
		while isRunning {
			Thread.sleep(forTimeInterval: frameInterval)
			step += 1
			try? sendFrame(full: false)
		}
	}

	private func background(x: Int, y: Int, w: Int, h: Int) -> [UInt8] {
		// A diagonal gradient; premultiplied opaque BGRA.
		let b = UInt8(truncatingIfNeeded: 40 + 160 * x / max(w, 1))
		let g = UInt8(truncatingIfNeeded: 40 + 160 * y / max(h, 1))

		return [b, g, 90, 255]
	}

	private func render(into buffer: inout [UInt8], w: Int, h: Int, rect: (x: Int, y: Int, w: Int, h: Int), box: (x: Int, y: Int, size: Int), dot: (Int, Int)?, dotRadius: Int) {
		for row in 0..<rect.h {
			for col in 0..<rect.w {
				let x = rect.x + col
				let y = rect.y + row
				var px = background(x: x, y: y, w: w, h: h)

				if x >= box.x && x < box.x + box.size && y >= box.y && y < box.y + box.size {
					px = [30, 200, 255, 255]
				}

				if let dot = dot {
					let dx = x - dot.0
					let dy = y - dot.1

					if dx * dx + dy * dy <= dotRadius * dotRadius { px = [255, 255, 255, 255] }
				}

				let o = (row * rect.w + col) * 4

				buffer[o] = px[0]
				buffer[o + 1] = px[1]
				buffer[o + 2] = px[2]
				buffer[o + 3] = px[3]
			}
		}
	}

	private func sendFrame(full: Bool) throws {
		let (w, h) = pixelSize()
		let size = max(min(w, h) / 5, 8)
		let span = max(w - size, 1)
		let t = step % (2 * span)
		let boxX = t < span ? t : 2 * span - t
		let boxY = (h - size) / 2
		let box = SeamlessRect(x: UInt32(boxX), y: UInt32(boxY), width: UInt32(size), height: UInt32(size))

		lock.lock()
		let k = Double(scale120) / 120.0
		let dot = pointer.map { (Int(Double($0.x) * k), Int(Double($0.y) * k)) }
		let previous = lastBox
		lastBox = box
		lock.unlock()

		let radius = max(Int(6 * k), 3)
		var rects: [(x: Int, y: Int, w: Int, h: Int)] = []

		if full || previous == nil {
			rects = [(0, 0, w, h)]
		} else if let previous = previous {
			// Damage: the box where it was and where it is, plus the pointer dot's area.
			for r in [previous, box] {
				rects.append((Int(r.x), Int(r.y), Int(r.width), Int(r.height)))
			}

			if let dot = dot {
				let x0 = max(dot.0 - radius - 2, 0)
				let y0 = max(dot.1 - radius - 2, 0)
				let x1 = min(dot.0 + radius + 2, w)
				let y1 = min(dot.1 + radius + 2, h)

				if x1 > x0 && y1 > y0 { rects.append((x0, y0, x1 - x0, y1 - y0)) }
			}
		}

		var items: [SeamlessFrameRect] = []

		for r in rects {
			let x0 = max(r.x, 0)
			let y0 = max(r.y, 0)
			let x1 = min(r.x + r.w, w)
			let y1 = min(r.y + r.h, h)

			guard x1 > x0, y1 > y0 else { continue }

			var buffer = [UInt8](repeating: 0, count: (x1 - x0) * (y1 - y0) * 4)

			render(into: &buffer, w: w, h: h, rect: (x0, y0, x1 - x0, y1 - y0), box: (boxX, boxY, size), dot: dot, dotRadius: radius)
			items.append(
				SeamlessFrameRect(rect: SeamlessRect(x: UInt32(x0), y: UInt32(y0), width: UInt32(x1 - x0), height: UInt32(y1 - y0)), pixels: Data(buffer)))
		}

		try send(.windowFrame(SeamlessFrame(windowID: windowID, width: UInt32(w), height: UInt32(h), rects: items)))
	}

	private func openPopup() {
		guard !popupOpen else { return }

		popupOpen = true

		let k = Double(scale120) / 120.0
		let (px, py) = lockedPointer()
		let w = Int(140 * k)
		let h = Int(90 * k)

		try? send(.windowCreate(SeamlessWindowInfo(id: popupID, parentID: windowID, kind: .popup, x: Int32(px), y: Int32(py), title: "popup")))

		var pixels = [UInt8](repeating: 0, count: w * h * 4)

		for i in 0..<(w * h) {
			pixels[i * 4] = 245
			pixels[i * 4 + 1] = 245
			pixels[i * 4 + 2] = 245
			pixels[i * 4 + 3] = 255
		}

		try? send(
			.windowFrame(
				SeamlessFrame(
					windowID: popupID, width: UInt32(w), height: UInt32(h),
					rects: [SeamlessFrameRect(rect: SeamlessRect(x: 0, y: 0, width: UInt32(w), height: UInt32(h)), pixels: Data(pixels))])))
	}

	private func lockedPointer() -> (Float, Float) {
		lock.lock()
		defer { lock.unlock() }
		return pointer ?? (20, 20)
	}

	private func closePopup() {
		guard popupOpen else { return }

		popupOpen = false
		try? send(.windowDestroy(id: popupID))
	}
}
