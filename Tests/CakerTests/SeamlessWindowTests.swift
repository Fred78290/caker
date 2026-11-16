//
//  SeamlessWindowTests.swift
//  CakerTests
//

import Foundation
import XCTest

@testable import CakedLib

final class SeamlessWindowTests: XCTestCase {

	// MARK: - Helpers

	private func solid(_ w: Int, _ h: Int, _ bgra: [UInt8]) -> Data {
		var out = Data(capacity: w * h * 4)
		for _ in 0..<(w * h) { out.append(contentsOf: bgra) }
		return out
	}

	private func splitFrame(_ data: Data) -> (UInt8, [UInt8]) {
		let bytes = [UInt8](data)
		let length = Int(bytes[0]) | Int(bytes[1]) << 8 | Int(bytes[2]) << 16 | Int(bytes[3]) << 24

		XCTAssertEqual(length, bytes.count - 4)

		return (bytes[4], Array(bytes[5...]))
	}

	private func roundTrip(_ message: SeamlessGuestMessage) throws -> SeamlessGuestMessage {
		let (type, payload) = splitFrame(try SeamlessCodec.encode(message))
		return try SeamlessCodec.decodeGuest(type: type, payload: payload)
	}

	private func roundTrip(_ message: SeamlessHostMessage) throws -> SeamlessHostMessage {
		let (type, payload) = splitFrame(try SeamlessCodec.encode(message))
		return try SeamlessCodec.decodeHost(type: type, payload: payload)
	}

	private func frameRect(_ x: UInt32, _ y: UInt32, _ w: UInt32, _ h: UInt32, _ bgra: [UInt8]) -> SeamlessFrameRect {
		SeamlessFrameRect(rect: SeamlessRect(x: x, y: y, width: w, height: h), pixels: solid(Int(w), Int(h), bgra))
	}

	// MARK: - Codec

	func testGuestMessagesRoundTrip() throws {
		let messages: [SeamlessGuestMessage] = [
			.hello(version: 1, name: "weston"),
			.windowCreate(SeamlessWindowInfo(id: 7, parentID: 3, kind: .popup, x: -12, y: 40, title: "Menü ☕", appID: "org.gnome.gedit")),
			.windowTitle(id: 7, title: "new title"),
			.windowAppID(id: 7, appID: "x"),
			.windowHints(id: 7, hints: SeamlessSizeHints(minWidth: 100, minHeight: 50, maxWidth: 0, maxHeight: 900)),
			.windowDestroy(id: 7),
			.cursor(id: 7, shape: "text"),
		]

		for message in messages {
			XCTAssertEqual(try roundTrip(message), message)
		}
	}

	func testHostMessagesRoundTrip() throws {
		let messages: [SeamlessHostMessage] = [
			.helloAck(version: 1, scale120: 240),
			.output(scale120: 180),
			.windowResize(id: 1, width: 800, height: 600),
			.windowClose(id: 1),
			.windowFocus(id: 1, focused: true),
			.pointerEnter(id: 1, x: 10.5, y: 20.25),
			.pointerLeave(id: 1),
			.pointerMotion(id: 1, x: -3, y: 4),
			.pointerButton(id: 1, button: SeamlessProtocol.buttonRight, pressed: false),
			.pointerAxis(id: 1, dx: 0, dy: -15),
			.key(code: 30, pressed: true),
		]

		for message in messages {
			XCTAssertEqual(try roundTrip(message), message)
		}
	}

	func testFrameRoundTripRawAndCompressed() throws {
		let noisy = Data((0..<(16 * 16 * 4)).map { UInt8(truncatingIfNeeded: $0 &* 2654435761 >> 7) })
		let frame = SeamlessFrame(
			windowID: 9, width: 64, height: 48,
			rects: [
				frameRect(0, 0, 64, 48, [1, 2, 3, 255]),  // compresses well
				SeamlessFrameRect(rect: SeamlessRect(x: 8, y: 8, width: 16, height: 16), pixels: noisy),
				frameRect(60, 44, 4, 4, [9, 9, 9, 9]),  // too small to bother compressing
			])

		let compressed = try SeamlessCodec.encode(.windowFrame(frame), compress: true)
		let raw = try SeamlessCodec.encode(.windowFrame(frame), compress: false)

		XCTAssertLessThan(compressed.count, raw.count)
		XCTAssertEqual(try roundTrip(.windowFrame(frame)), .windowFrame(frame))

		let (type, payload) = splitFrame(raw)
		XCTAssertEqual(try SeamlessCodec.decodeGuest(type: type, payload: payload), .windowFrame(frame))
	}

	func testEncodeRejectsBadFrames() {
		XCTAssertThrowsError(try SeamlessCodec.encode(.windowFrame(SeamlessFrame(windowID: 1, width: 0, height: 10, rects: []))))
		XCTAssertThrowsError(try SeamlessCodec.encode(.windowFrame(SeamlessFrame(windowID: 1, width: 20000, height: 10, rects: []))))
		// Rectangle sticking out of the buffer.
		XCTAssertThrowsError(try SeamlessCodec.encode(.windowFrame(SeamlessFrame(windowID: 1, width: 10, height: 10, rects: [frameRect(8, 8, 4, 4, [0, 0, 0, 0])]))))
		// Pixel data that doesn't match the rectangle.
		XCTAssertThrowsError(
			try SeamlessCodec.encode(
				.windowFrame(SeamlessFrame(windowID: 1, width: 10, height: 10, rects: [SeamlessFrameRect(rect: SeamlessRect(x: 0, y: 0, width: 2, height: 2), pixels: Data(count: 3))]))))
		XCTAssertThrowsError(try SeamlessCodec.encode(.windowTitle(id: 1, title: String(repeating: "a", count: SeamlessProtocol.maxStringLength + 1))))
	}

	func testDecoderSplitsAStreamFedByteByByte() throws {
		let a = try SeamlessCodec.encode(.hello(version: 1, name: "a"))
		let b = try SeamlessCodec.encode(.windowDestroy(id: 5))
		var decoder = SeamlessFrameDecoder()
		var types: [UInt8] = []

		for byte in a + b {
			decoder.append(Data([byte]))

			while let (type, _) = try decoder.next() { types.append(type) }
		}

		XCTAssertEqual(types, [0x01, 0x07])
	}

	func testDecoderRejectsImpossibleLengths() {
		var empty = SeamlessFrameDecoder()
		empty.append(Data([0, 0, 0, 0]))
		XCTAssertThrowsError(try empty.next())

		var huge = SeamlessFrameDecoder()
		huge.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))
		XCTAssertThrowsError(try huge.next())
	}

	func testDecodeRejectsMalformedPayloads() throws {
		// Unknown type, host type sent as guest and the other way round.
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x7E, payload: []))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x81, payload: [1, 0, 120, 0, 0, 0]))
		XCTAssertThrowsError(try SeamlessCodec.decodeHost(type: 0x01, payload: []))

		// Truncated and trailing bytes.
		let (type, payload) = splitFrame(try SeamlessCodec.encode(.windowDestroy(id: 5)))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: type, payload: Array(payload.dropLast())))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: type, payload: payload + [0]))

		// Invalid UTF-8 in a title.
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x03, payload: [1, 0, 0, 0, 2, 0, 0xC3, 0x28]))

		// A NaN pointer position.
		var nan: [UInt8] = [1, 0, 0, 0]
		withUnsafeBytes(of: Float.nan.bitPattern.littleEndian) { nan.append(contentsOf: $0) }
		nan += [0, 0, 0, 0]
		XCTAssertThrowsError(try SeamlessCodec.decodeHost(type: 0x88, payload: nan))
	}

	func testDecodeRejectsFramesThatLieAboutTheirContent() throws {
		func frame(rect: (UInt32, UInt32, UInt32, UInt32), compression: UInt8, data: [UInt8], dims: (UInt32, UInt32) = (32, 32), count: UInt16 = 1) -> [UInt8] {
			var w = SeamlessWriter()
			w.u32(1)
			w.u32(dims.0)
			w.u32(dims.1)
			w.u8(0)
			w.u16(count)
			w.u32(rect.0)
			w.u32(rect.1)
			w.u32(rect.2)
			w.u32(rect.3)
			w.u8(compression)
			w.u32(UInt32(data.count))
			return [UInt8](w.data) + data
		}

		let good = frame(rect: (0, 0, 2, 2), compression: 0, data: [UInt8](repeating: 7, count: 16))
		XCTAssertNoThrow(try SeamlessCodec.decodeGuest(type: 0x06, payload: good))

		// Raw data of the wrong size.
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x06, payload: frame(rect: (0, 0, 2, 2), compression: 0, data: [UInt8](repeating: 7, count: 15))))
		// Rectangle outside of the buffer, zero sized, overflowing coordinates.
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x06, payload: frame(rect: (31, 0, 2, 2), compression: 0, data: [UInt8](repeating: 0, count: 16))))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x06, payload: frame(rect: (0, 0, 0, 2), compression: 0, data: [])))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x06, payload: frame(rect: (UInt32.max, 0, 2, 2), compression: 0, data: [UInt8](repeating: 0, count: 16))))
		// Unknown compression, and garbage that is not LZ4.
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x06, payload: frame(rect: (0, 0, 2, 2), compression: 9, data: [UInt8](repeating: 0, count: 16))))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x06, payload: frame(rect: (0, 0, 2, 2), compression: 1, data: [0xFF, 0xFF, 0xFF])))
		// More rectangles announced than carried.
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x06, payload: frame(rect: (0, 0, 2, 2), compression: 0, data: [UInt8](repeating: 7, count: 16), count: 2)))
		// Absurd buffer size.
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x06, payload: frame(rect: (0, 0, 2, 2), compression: 0, data: [UInt8](repeating: 7, count: 16), dims: (60000, 60000))))
	}

	func testLZ4DetectsAWrongDeclaredSize() throws {
		let source = solid(32, 32, [5, 6, 7, 255])
		let packed = try XCTUnwrap(SeamlessLZ4.compress(source))

		XCTAssertEqual(SeamlessLZ4.decompress(ArraySlice([UInt8](packed)), expected: source.count), source)
		// Output larger or smaller than announced is an error, not a silent truncation.
		XCTAssertNil(SeamlessLZ4.decompress(ArraySlice([UInt8](packed)), expected: source.count - 4))
		XCTAssertNil(SeamlessLZ4.decompress(ArraySlice([UInt8](packed)), expected: source.count + 4))
	}

	// MARK: - Surface

	func testSurfaceAppliesDamageAndResizes() throws {
		let surface = SeamlessSurface()

		XCTAssertNil(surface.makeImage())

		try surface.apply(SeamlessFrame(windowID: 1, width: 8, height: 6, rects: [frameRect(0, 0, 8, 6, [10, 20, 30, 255])]))
		XCTAssertEqual(surface.width, 8)
		XCTAssertEqual(surface.height, 6)
		XCTAssertEqual(surface.pixel(x: 7, y: 5), [10, 20, 30, 255])

		// Only the damaged rectangle changes.
		try surface.apply(SeamlessFrame(windowID: 1, width: 8, height: 6, rects: [frameRect(2, 1, 3, 2, [1, 2, 3, 255])]))
		XCTAssertEqual(surface.pixel(x: 2, y: 1), [1, 2, 3, 255])
		XCTAssertEqual(surface.pixel(x: 4, y: 2), [1, 2, 3, 255])
		XCTAssertEqual(surface.pixel(x: 5, y: 2), [10, 20, 30, 255])
		XCTAssertEqual(surface.pixel(x: 2, y: 3), [10, 20, 30, 255])
		XCTAssertNotNil(surface.makeImage())

		// A bigger buffer starts transparent.
		try surface.apply(SeamlessFrame(windowID: 1, width: 16, height: 12, rects: [frameRect(0, 0, 2, 2, [9, 9, 9, 255])]))
		XCTAssertEqual(surface.width, 16)
		XCTAssertEqual(surface.pixel(x: 0, y: 0), [9, 9, 9, 255])
		XCTAssertEqual(surface.pixel(x: 10, y: 10), [0, 0, 0, 0])
	}

	func testSurfaceRefusesBadFramesWithoutChangingItself() throws {
		let surface = SeamlessSurface()

		try surface.apply(SeamlessFrame(windowID: 1, width: 4, height: 4, rects: [frameRect(0, 0, 4, 4, [1, 1, 1, 255])]))

		XCTAssertThrowsError(try surface.apply(SeamlessFrame(windowID: 1, width: 4, height: 4, rects: [frameRect(0, 0, 2, 2, [2, 2, 2, 255]), frameRect(3, 3, 2, 2, [3, 3, 3, 255])])))
		XCTAssertEqual(surface.pixel(x: 0, y: 0), [1, 1, 1, 255])
		XCTAssertThrowsError(try surface.apply(SeamlessFrame(windowID: 1, width: 0, height: 4, rects: [])))
	}

	// MARK: - Key map

	func testKeyMapIsInjectiveAndKnowsTheCommonKeys() {
		var seen = Set<UInt32>()

		for code in UInt16(0)...UInt16(127) {
			if let evdev = SeamlessKeyMap.evdev(forMacKeyCode: code) {
				XCTAssertTrue(seen.insert(evdev).inserted, "two mac keys map to evdev \(evdev)")
			}
		}

		XCTAssertEqual(SeamlessKeyMap.evdev(forMacKeyCode: 0), 30)  // A
		XCTAssertEqual(SeamlessKeyMap.evdev(forMacKeyCode: 36), 28)  // Return
		XCTAssertEqual(SeamlessKeyMap.evdev(forMacKeyCode: 49), 57)  // Space
		XCTAssertEqual(SeamlessKeyMap.evdev(forMacKeyCode: 126), 103)  // Up
		XCTAssertEqual(SeamlessKeyMap.evdev(forMacKeyCode: 55), 125)  // Left command -> Super
		XCTAssertNil(SeamlessKeyMap.evdev(forMacKeyCode: 0x7F))
	}

	// MARK: - Server

	private final class Recorder: SeamlessServerDelegate, @unchecked Sendable {
		private let lock = NSLock()
		private var storage: [String] = []
		private var messages: [SeamlessGuestMessage] = []
		private(set) var session: SeamlessSession?

		var log: [String] {
			lock.lock()
			defer { lock.unlock() }
			return storage
		}

		var received: [SeamlessGuestMessage] {
			lock.lock()
			defer { lock.unlock() }
			return messages
		}

		func seamlessServer(_ server: SeamlessServer, sessionDidStart session: SeamlessSession, guestName: String) {
			lock.lock()
			self.session = session
			storage.append("start \(guestName)")
			lock.unlock()
		}

		func seamlessServer(_ server: SeamlessServer, session: SeamlessSession, didReceive message: SeamlessGuestMessage) {
			lock.lock()
			messages.append(message)
			lock.unlock()
		}

		func seamlessServer(_ server: SeamlessServer, sessionDidEnd session: SeamlessSession) {
			lock.lock()
			storage.append("end")
			lock.unlock()
		}
	}

	private func makeServer() throws -> (SeamlessServer, Recorder, String) {
		let path = "/tmp/seamless-\(UUID().uuidString.prefix(8)).sock"
		let recorder = Recorder()
		let server = SeamlessServer(socketPath: path, delegate: recorder, delegateQueue: DispatchQueue(label: "test.seamless.delegate"))

		server.outputScale120 = 240
		try server.start()

		return (server, recorder, path)
	}

	private func wait(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
		let deadline = Date().addingTimeInterval(timeout)

		while Date() < deadline {
			if condition() { return true }
			Thread.sleep(forTimeInterval: 0.01)
		}

		return condition()
	}

	private func connect(_ path: String) throws -> Int32 {
		let fd = socket(AF_UNIX, SOCK_STREAM, 0)
		var address = sockaddr_un()
		address.sun_family = sa_family_t(AF_UNIX)

		let bytes = Array(path.utf8CString)

		withUnsafeMutableBytes(of: &address.sun_path) { dst in bytes.withUnsafeBytes { dst.copyMemory(from: $0) } }

		let result = withUnsafePointer(to: &address) {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
		}

		XCTAssertEqual(result, 0)

		return fd
	}

	private func write(_ fd: Int32, _ data: Data) {
		data.withUnsafeBytes { _ = Darwin.write(fd, $0.baseAddress!, $0.count) }
	}

	/// Reads host messages until `count` were decoded or the peer closed.
	private func readHost(_ fd: Int32, count: Int) throws -> [SeamlessHostMessage] {
		var decoder = SeamlessFrameDecoder()
		var out: [SeamlessHostMessage] = []
		var buffer = [UInt8](repeating: 0, count: 4096)

		var timeout = timeval(tv_sec: 5, tv_usec: 0)
		setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

		while out.count < count {
			let n = Darwin.read(fd, &buffer, buffer.count)

			if n <= 0 { break }

			decoder.append(Data(buffer[0..<n]))

			while let (type, payload) = try decoder.next() {
				out.append(try SeamlessCodec.decodeHost(type: type, payload: payload))
			}
		}

		return out
	}

	func testServerHandshakeFramesAndHostInput() throws {
		let (server, recorder, path) = try makeServer()
		defer { server.stop() }

		let fd = try connect(path)
		defer { Darwin.close(fd) }

		write(fd, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "unit")))
		XCTAssertEqual(try readHost(fd, count: 1), [.helloAck(version: SeamlessProtocol.version, scale120: 240)])
		XCTAssertTrue(wait { recorder.log == ["start unit"] })

		let info = SeamlessWindowInfo(id: 3, title: "hello")
		let frame = SeamlessFrame(windowID: 3, width: 4, height: 4, rects: [frameRect(0, 0, 4, 4, [1, 2, 3, 255])])

		write(fd, try SeamlessCodec.encode(.windowCreate(info)))
		write(fd, try SeamlessCodec.encode(.windowFrame(frame)))
		XCTAssertTrue(wait { recorder.received.count == 2 })
		XCTAssertEqual(recorder.received, [.windowCreate(info), .windowFrame(frame)])

		// Host to guest, including a scale change on the live session.
		recorder.session?.send(.pointerMotion(id: 3, x: 1, y: 2))
		server.outputScale120 = 180
		XCTAssertEqual(try readHost(fd, count: 2), [.pointerMotion(id: 3, x: 1, y: 2), .output(scale120: 180)])

		// The guest going away ends the session.
		Darwin.close(fd)
		XCTAssertTrue(wait { recorder.log.last == "end" })
	}

	func testServerClosesOnProtocolViolations() throws {
		let (server, recorder, path) = try makeServer()
		defer { server.stop() }

		// Anything but hello first.
		let first = try connect(path)
		defer { Darwin.close(first) }
		write(first, try SeamlessCodec.encode(.windowDestroy(id: 1)))
		XCTAssertEqual(try readHost(first, count: 1), [])

		// Wrong version.
		let second = try connect(path)
		defer { Darwin.close(second) }
		write(second, try SeamlessCodec.encode(.hello(version: 99, name: "old")))
		XCTAssertEqual(try readHost(second, count: 1), [])

		// Garbage after a good hello.
		let third = try connect(path)
		defer { Darwin.close(third) }
		write(third, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "bad")))
		XCTAssertEqual(try readHost(third, count: 1).count, 1)
		write(third, Data([0xFF, 0xFF, 0xFF, 0x7F, 0x01]))
		XCTAssertTrue(wait { recorder.log == ["start bad", "end"] })
	}

	func testNewConnectionReplacesTheCurrentSession() throws {
		let (server, recorder, path) = try makeServer()
		defer { server.stop() }

		let first = try connect(path)
		defer { Darwin.close(first) }
		write(first, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "one")))
		_ = try readHost(first, count: 1)
		XCTAssertTrue(wait { recorder.log == ["start one"] })

		let second = try connect(path)
		defer { Darwin.close(second) }
		write(second, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "two")))
		_ = try readHost(second, count: 1)

		XCTAssertTrue(wait { recorder.log.contains("start two") })
		// The replaced connection was closed.
		XCTAssertEqual(try readHost(first, count: 1), [])
	}

	func testSocketIsPrivateToTheUser() throws {
		let (server, _, path) = try makeServer()
		defer { server.stop() }

		var info = stat()
		XCTAssertEqual(stat(path, &info), 0)
		XCTAssertEqual(info.st_mode & 0o777, 0o600)
	}

	/// A guest stream that arrives already connected (the tunnel's socketpair) is served like an accepted one.
	func testAttachedConnectionIsServedLikeAnAcceptedOne() throws {
		let recorder = Recorder()
		let server = SeamlessServer(socketPath: "", delegate: recorder, delegateQueue: DispatchQueue(label: "test.seamless.delegate"))
		var pair: [Int32] = [-1, -1]

		XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair), 0)
		defer { Darwin.close(pair[0]) }

		server.outputScale120 = 240
		server.attach(fd: pair[1])
		defer { server.stop() }

		write(pair[0], try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "tunnel")))
		XCTAssertEqual(try readHost(pair[0], count: 1), [.helloAck(version: SeamlessProtocol.version, scale120: 240)])
		XCTAssertTrue(wait { recorder.log == ["start tunnel"] })

		// A manager that listens on no socket has nothing to remove or unlock when it stops.
		server.stop()

		Darwin.close(pair[0])
		pair[0] = -1
		XCTAssertTrue(wait { recorder.log.last == "end" })
	}

	func testOnlyOneListenerOwnsTheSocketOfAGuest() throws {
		let path = "/tmp/seamless-\(UUID().uuidString.prefix(8)).sock"
		defer { unlink(path + ".lock") }

		let first = try XCTUnwrap(SeamlessServer.acquireListenerLock(for: path))

		XCTAssertNil(SeamlessServer.acquireListenerLock(for: path), "a second process must not listen on the same socket")

		SeamlessServer.releaseListenerLock(first)

		let again = try XCTUnwrap(SeamlessServer.acquireListenerLock(for: path), "the lock is free again once released")

		SeamlessServer.releaseListenerLock(again)
	}

	func testServerRefusesToListenWhereAnotherListenerOwnsTheSocket() throws {
		let (server, _, path) = try makeServer()
		defer { server.stop() }

		let other = SeamlessServer(socketPath: path, delegate: Recorder(), delegateQueue: DispatchQueue(label: "test.seamless.other"))

		XCTAssertThrowsError(try other.start())

		// The refused listener must leave the owner's socket alone, and the owner keeps working.
		other.stop()

		let fd = try connect(path)
		defer { Darwin.close(fd) }

		write(fd, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "still-there")))
		XCTAssertEqual(try readHost(fd, count: 1), [.helloAck(version: SeamlessProtocol.version, scale120: 240)])
	}

	func testDemoGuestRoundTripThroughTheServer() throws {
		let (server, recorder, path) = try makeServer()
		defer { server.stop() }

		let guest = SeamlessDemoGuest(socketPath: path, frameInterval: 0.02)

		try guest.connect()
		try guest.start()
		defer { guest.stop() }

		XCTAssertTrue(wait { recorder.log == ["start demo-guest"] })
		XCTAssertTrue(wait { recorder.received.contains { if case .windowCreate = $0 { return true } else { return false } } })
		XCTAssertTrue(wait { recorder.received.filter { if case .windowFrame = $0 { return true } else { return false } }.count >= 3 })

		// The first frame is the whole window at the scale the host announced (2x of 480x320).
		let frames = recorder.received.compactMap { message -> SeamlessFrame? in
			if case .windowFrame(let frame) = message { return frame }
			return nil
		}

		XCTAssertEqual(frames.first?.width, 960)
		XCTAssertEqual(frames.first?.height, 640)

		// Host input reaches the guest, a resize makes it redraw at the new size, a close request ends it.
		let session = try XCTUnwrap(recorder.session)

		session.send(.pointerButton(id: 1, button: SeamlessProtocol.buttonLeft, pressed: true))
		session.send(.key(code: 30, pressed: true))
		session.send(.windowResize(id: 1, width: 300, height: 200))
		XCTAssertTrue(wait { guest.receivedEvents.contains("key 30 true") })
		XCTAssertTrue(wait {
			recorder.received.contains { if case .windowFrame(let f) = $0 { return f.width == 600 && f.height == 400 } else { return false } }
		})

		session.send(.windowClose(id: 1))
		XCTAssertTrue(wait { recorder.received.contains(.windowDestroy(id: 1)) })
		XCTAssertTrue(wait { recorder.log.last == "end" })
	}
}
