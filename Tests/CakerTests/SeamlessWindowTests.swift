//
//  SeamlessWindowTests.swift
//  CakerTests
//

import AppKit
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
			.hello(version: SeamlessProtocol.version, name: "weston"),
			.windowCreate(SeamlessWindowInfo(id: 7, parentID: 3, kind: .popup, x: -12, y: 40, title: "Menü ☕", appID: "org.gnome.gedit")),
			.windowTitle(id: 7, title: "new title"),
			.windowAppID(id: 7, appID: "x"),
			.windowHints(id: 7, hints: SeamlessSizeHints(minWidth: 100, minHeight: 50, maxWidth: 0, maxHeight: 900)),
			.windowDestroy(id: 7),
			.cursor(id: 7, shape: "text"),
			.clipboard(text: "Texte copié ☕\nsur deux lignes"),
			.clipboard(text: ""),
			.clipboardItems([SeamlessClipboardItem(mime: "text/plain;charset=utf-8", data: Data("hé".utf8)), SeamlessClipboardItem(mime: "image/png", data: Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]))]),
		]

		for message in messages {
			XCTAssertEqual(try roundTrip(message), message)
		}
	}

	func testHostMessagesRoundTrip() throws {
		let messages: [SeamlessHostMessage] = [
			.helloAck(version: SeamlessProtocol.version, scale120: 240),
			.output(scale120: 180),
			.windowResize(id: 1, width: 800, height: 600),
			.windowClose(id: 1),
			.windowFocus(id: 1, focused: true),
			.pointerEnter(id: 1, x: 10.5, y: 20.25),
			.pointerLeave(id: 1),
			.pointerMotion(id: 1, x: -3, y: 4),
			.pointerButton(id: 1, button: SeamlessProtocol.buttonRight, pressed: false),
			.pointerAxis(id: 1, dx: 0, dy: -15, source: .continuous),
			.pointerAxis(id: 1, dx: 0.5, dy: 2, source: .wheel),
			.pointerAxis(id: 1, dx: 0, dy: 0, source: .stop),
			.key(code: 30, pressed: true),
			.clipboard(text: "from the Mac"),
			.clipboardItems([SeamlessClipboardItem(mime: "text/html", data: Data("<b>x</b>".utf8))]),
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

	func testEncodeEnforcesTheAggregatePixelLimitOfTheDecoder() throws {
		// Each rectangle fits the buffer and the per-rectangle limit, but three of them exceed twice `maxRectPixels`, which the decoder refuses.
		let width: UInt32 = 6000
		let height: UInt32 = 6666
		let pixels = Data(count: Int(width) * Int(height) * SeamlessProtocol.bytesPerPixel)  // One copy-on-write buffer shared by every rectangle.
		let rect = SeamlessFrameRect(rect: SeamlessRect(x: 0, y: 0, width: width, height: height), pixels: pixels)

		XCTAssertLessThanOrEqual(Int(width) * Int(height), SeamlessProtocol.maxRectPixels)
		XCTAssertGreaterThan(Int(width) * Int(height) * 3, SeamlessProtocol.maxRectPixels * 2)

		XCTAssertThrowsError(try SeamlessCodec.encode(.windowFrame(SeamlessFrame(windowID: 1, width: width, height: height, rects: [rect, rect, rect])), compress: false)) {
			XCTAssertEqual($0 as? SeamlessProtocolError, .invalidDimensions(width, height))
		}

		// Two of them stay within both limits and still round-trip through the decoder (compressed: raw they would exceed `maxFrameLength`).
		let ok = try SeamlessCodec.encode(.windowFrame(SeamlessFrame(windowID: 1, width: width, height: height, rects: [rect, rect])))
		let (type, payload) = splitFrame(ok)

		guard case .windowFrame(let decoded) = try SeamlessCodec.decodeGuest(type: type, payload: payload) else { return XCTFail("not a frame") }

		XCTAssertEqual(decoded.rects.count, 2)
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

	func testSurfaceRefusesEmptyRectsButAcceptsAnEmptyRectList() throws {
		let surface = SeamlessSurface()

		try surface.apply(SeamlessFrame(windowID: 1, width: 4, height: 4, rects: [frameRect(0, 0, 4, 4, [1, 1, 1, 255])]))

		// Same rule as the decoder: a rectangle needs a width and a height, and a refused frame must not resize the surface.
		for rect in [frameRect(0, 0, 0, 2, [2, 2, 2, 255]), frameRect(0, 0, 2, 0, [2, 2, 2, 255])] {
			XCTAssertThrowsError(try surface.apply(SeamlessFrame(windowID: 1, width: 8, height: 8, rects: [rect]))) {
				XCTAssertEqual($0 as? SeamlessProtocolError, SeamlessProtocolError.rectOutOfBounds)
			}
			XCTAssertEqual(surface.width, 4)
			XCTAssertEqual(surface.pixel(x: 0, y: 0), [1, 1, 1, 255])
		}

		// No rectangle at all is a valid frame (a pure resize).
		try surface.apply(SeamlessFrame(windowID: 1, width: 8, height: 8, rects: []))
		XCTAssertEqual(surface.width, 8)
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
		XCTAssertEqual(SeamlessKeyMap.evdev(forMacKeyCode: 10), 86)  // ISO key next to Left Shift
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
		private var storedSession: SeamlessSession?

		var session: SeamlessSession? {
			lock.lock()
			defer { lock.unlock() }
			return storedSession
		}

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
			self.storedSession = session
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

	/// Reads host messages until `count` were decoded or the peer closed (a read that returns 0).
	/// A read error other than EINTR, a timeout included, is thrown: it is not a closure.
	private func readHost(_ fd: Int32, count: Int) throws -> [SeamlessHostMessage] {
		var decoder = SeamlessFrameDecoder()
		var out: [SeamlessHostMessage] = []
		var buffer = [UInt8](repeating: 0, count: 4096)

		var timeout = timeval(tv_sec: 5, tv_usec: 0)
		setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

		while out.count < count {
			let n = Darwin.read(fd, &buffer, buffer.count)

			if n < 0 {
				if errno == EINTR { continue }

				throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
			}

			if n == 0 { break }

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

		var fd = try connect(path)
		defer { if fd >= 0 { Darwin.close(fd) } }

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
		fd = -1  // The descriptor number may be reused: the deferred close must not touch it.
		XCTAssertTrue(wait { recorder.log.last == "end" })
	}

	func testClipboardLimitsAndFormat() throws {
		// A text over the limit is not encoded (the sender checks first), and a guest can't send one either.
		XCTAssertThrowsError(try SeamlessCodec.encode(SeamlessHostMessage.clipboard(text: String(repeating: "a", count: SeamlessProtocol.maxClipboardBytes + 1))))
		XCTAssertNoThrow(try SeamlessCodec.encode(SeamlessHostMessage.clipboard(text: String(repeating: "a", count: SeamlessProtocol.maxClipboardBytes))))

		var oversize: [UInt8] = [0]
		withUnsafeBytes(of: UInt32(SeamlessProtocol.maxClipboardBytes + 1).littleEndian) { oversize.append(contentsOf: $0) }
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x09, payload: oversize))

		// An unknown format, a length that lies, and bytes left over.
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x09, payload: [7, 1, 0, 0, 0, 97]))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x09, payload: [0, 5, 0, 0, 0, 97]))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x09, payload: [0, 1, 0, 0, 0, 97, 98]))

		// Text with a broken UTF-8 sequence is still text: it must not end the session.
		XCTAssertEqual(try SeamlessCodec.decodeGuest(type: 0x09, payload: [0, 2, 0, 0, 0, 0xC3, 0x28]), .clipboard(text: "\u{FFFD}("))
	}

	func testClipboardOnlyGoesToAGuestThatHasIt() throws {
		let (server, recorder, path) = try makeServer()
		defer { server.stop() }

		let fd = try connect(path)
		defer { Darwin.close(fd) }

		write(fd, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.axisVersion, name: "scrolls")))
		XCTAssertEqual(try readHost(fd, count: 1), [.helloAck(version: SeamlessProtocol.axisVersion, scale120: 240)])
		XCTAssertTrue(wait { recorder.log == ["start scrolls"] })

		// Protocol 2 has no clipboard: the message would make the guest close the connection.
		recorder.session?.send(.clipboard(text: "no"))
		recorder.session?.send(.pointerMotion(id: 3, x: 1, y: 2))
		XCTAssertEqual(try readHost(fd, count: 1), [.pointerMotion(id: 3, x: 1, y: 2)])
	}

	func testClipboardReachesTheDelegateAndTheGuest() throws {
		let (server, recorder, path) = try makeServer()
		defer { server.stop() }

		let fd = try connect(path)
		defer { Darwin.close(fd) }

		write(fd, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "unit")))
		XCTAssertEqual(try readHost(fd, count: 1), [.helloAck(version: SeamlessProtocol.version, scale120: 240)])
		XCTAssertTrue(wait { recorder.log == ["start unit"] })

		write(fd, try SeamlessCodec.encode(SeamlessGuestMessage.clipboard(text: "from the guest")))
		XCTAssertTrue(wait { recorder.received == [.clipboard(text: "from the guest")] })

		recorder.session?.send(.clipboard(text: "from the Mac"))
		XCTAssertEqual(try readHost(fd, count: 1), [.clipboard(text: "from the Mac")])
	}

	private func item(_ mime: String, _ size: Int) -> SeamlessClipboardItem {
		SeamlessClipboardItem(mime: mime, data: Data(repeating: 7, count: size))
	}

	/// The payload of a clipboard items message, written by hand: what a guest sends.
	private func itemsPayload(_ items: [(mime: String, size: Int)], count: Int? = nil) -> [UInt8] {
		var payload: [UInt8] = []

		withUnsafeBytes(of: UInt16(count ?? items.count).littleEndian) { payload.append(contentsOf: $0) }

		for item in items {
			withUnsafeBytes(of: UInt16(item.mime.utf8.count).littleEndian) { payload.append(contentsOf: $0) }
			payload.append(contentsOf: Array(item.mime.utf8))
			withUnsafeBytes(of: UInt32(item.size).littleEndian) { payload.append(contentsOf: $0) }
			payload.append(contentsOf: [UInt8](repeating: 7, count: item.size))
		}

		return payload
	}

	func testClipboardItemsRoundTripAndLimits() throws {
		let items = [item("text/plain;charset=utf-8", 5), item("image/png", 64), item("text/html", 12)]

		// Both directions carry them, byte for byte, and the hand written layout is the one encoded.
		let guest = try SeamlessCodec.encode(SeamlessGuestMessage.clipboardItems(items))

		XCTAssertEqual(guest[4], 0x0A)
		XCTAssertEqual(Array(guest.dropFirst(5)), itemsPayload([("text/plain;charset=utf-8", 5), ("image/png", 64), ("text/html", 12)]))
		XCTAssertEqual(try SeamlessCodec.decodeGuest(type: 0x0A, payload: Array(guest.dropFirst(5))), .clipboardItems(items))

		let host = try SeamlessCodec.encode(SeamlessHostMessage.clipboardItems(items))

		XCTAssertEqual(host[4], 0x8D)
		XCTAssertEqual(try SeamlessCodec.decodeHost(type: 0x8D, payload: Array(host.dropFirst(5))), .clipboardItems(items))

		// The most data goes, one byte more does not, and the limit is on all the items together.
		XCTAssertNoThrow(try SeamlessCodec.encode(SeamlessHostMessage.clipboardItems([item("a/b", SeamlessProtocol.maxClipboardTotalBytes)])))
		XCTAssertThrowsError(try SeamlessCodec.encode(SeamlessHostMessage.clipboardItems([item("a/b", SeamlessProtocol.maxClipboardTotalBytes + 1)])))
		XCTAssertThrowsError(try SeamlessCodec.encode(SeamlessHostMessage.clipboardItems([item("a/b", SeamlessProtocol.maxClipboardTotalBytes / 2 + 1), item("c/d", SeamlessProtocol.maxClipboardTotalBytes / 2 + 1)])))

		// Not a list, too many items, a MIME type that is not one, twice the same type (any case), an empty item.
		XCTAssertThrowsError(try SeamlessCodec.encode(SeamlessHostMessage.clipboardItems([])))
		XCTAssertThrowsError(try SeamlessCodec.encode(SeamlessHostMessage.clipboardItems((0...SeamlessProtocol.maxClipboardItems).map { item("x/\($0)", 1) })))

		for mime in ["UTF8_STRING", "a/b/c", "text/", "/plain", "te xt/plain", "text/é", "a/"] {
			XCTAssertThrowsError(try SeamlessCodec.encode(SeamlessHostMessage.clipboardItems([item(mime, 1)])), mime)
		}

		XCTAssertThrowsError(try SeamlessCodec.encode(SeamlessHostMessage.clipboardItems([item("text/plain", 1), item("TEXT/Plain", 1)])))
		XCTAssertThrowsError(try SeamlessCodec.encode(SeamlessHostMessage.clipboardItems([item("text/plain", 0)])))

		// A guest that lies: a count that does not match, a total over the limit, bytes left over, a truncated item.
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x0A, payload: itemsPayload([("text/plain", 3)], count: 2)))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x0A, payload: itemsPayload([("text/plain", 3)], count: 0)))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x0A, payload: itemsPayload([("text/plain", 3)]) + [0]))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x0A, payload: Array(itemsPayload([("text/plain", 3)]).dropLast())))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x0A, payload: itemsPayload([("nomime", 3)])))
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x0A, payload: itemsPayload([("text/plain", 3), ("Text/PLAIN", 3)])))

		var oversize = itemsPayload([("a/b", 0)])

		oversize.removeLast(4)
		withUnsafeBytes(of: UInt32(SeamlessProtocol.maxClipboardTotalBytes + 1).littleEndian) { oversize.append(contentsOf: $0) }
		XCTAssertThrowsError(try SeamlessCodec.decodeGuest(type: 0x0A, payload: oversize))
	}

	/// A private pasteboard, so the test does not touch the user's clipboard.
	@MainActor
	private func scratchPasteboard() -> NSPasteboard {
		let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.aldunelabs.caker.test.\(UUID().uuidString)"))

		pasteboard.clearContents()

		return pasteboard
	}

	@MainActor
	func testPasteboardBecomesItems() throws {
		let pasteboard = scratchPasteboard()
		defer { pasteboard.releaseGlobally() }

		XCTAssertEqual(SeamlessWindowManager.clipboardItems(from: pasteboard), [])

		// Text first, as UTF-8, then what has a shared MIME type; one item per MIME type.
		let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
		let tiff = try XCTUnwrap(bitmap.representation(using: .tiff, properties: [:]))

		pasteboard.declareTypes([.tiff, .html, .string, NSPasteboard.PasteboardType("public.utf16-external-plain-text")], owner: nil)
		pasteboard.setData(tiff, forType: .tiff)
		pasteboard.setString("<b>héllo</b>", forType: .html)
		pasteboard.setString("héllo", forType: .string)
		pasteboard.setString("héllo", forType: NSPasteboard.PasteboardType("public.utf16-external-plain-text"))

		let items = SeamlessWindowManager.clipboardItems(from: pasteboard)

		XCTAssertEqual(items.first, SeamlessClipboardItem(mime: "text/plain;charset=utf-8", data: Data("héllo".utf8)))
		XCTAssertEqual(items.filter { $0.mime.hasPrefix("text/plain") }.count, 1)
		XCTAssertEqual(items.first { $0.mime == "text/html" }?.data, Data("<b>héllo</b>".utf8))

		// The TIFF goes as a PNG.
		let png = try XCTUnwrap(items.first { $0.mime == "image/png" })

		XCTAssertTrue(png.data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
		XCTAssertNil(items.first { $0.mime == "image/tiff" })
		XCTAssertEqual(NSBitmapImageRep(data: png.data)?.pixelsWide, 8)

		// A PNG on the pasteboard is sent as it is, and wins over the TIFF.
		let realPNG = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))

		pasteboard.clearContents()
		pasteboard.declareTypes([.tiff, .png], owner: nil)
		pasteboard.setData(tiff, forType: .tiff)
		pasteboard.setData(realPNG, forType: .png)
		XCTAssertEqual(SeamlessWindowManager.clipboardItems(from: pasteboard).first { $0.mime == "image/png" }?.data, realPNG)

		// What is not text, an image or a PDF is not shared: a file reference, an arbitrary type.
		pasteboard.clearContents()
		pasteboard.declareTypes([.fileURL, NSPasteboard.PasteboardType("com.example.private-thing")], owner: nil)
		pasteboard.setString("file:///etc/passwd", forType: .fileURL)
		pasteboard.setData(Data([1, 2, 3]), forType: NSPasteboard.PasteboardType("com.example.private-thing"))
		XCTAssertEqual(SeamlessWindowManager.clipboardItems(from: pasteboard), [])
	}

	@MainActor
	func testItemsBecomePasteboardEntries() throws {
		let entries = SeamlessWindowManager.pasteboardEntries(for: [
			item("text/plain;charset=utf-8", 3),
			item("text/plain", 4),  // the same pasteboard type: the first wins
			item("image/png", 5),
			item("text/html", 6),
			item("application/x-sh-unknown-thing", 7),  // no pasteboard type
			item("application/zip", 8),  // not shared
		])

		XCTAssertEqual(entries.map(\.type), [.string, .png, .html])
		XCTAssertEqual(entries.map(\.data.count), [3, 5, 6])
		XCTAssertEqual(SeamlessWindowManager.mimeType(forPasteboardType: .string), "text/plain;charset=utf-8")
		XCTAssertEqual(SeamlessWindowManager.mimeType(forPasteboardType: .png), "image/png")
		XCTAssertNil(SeamlessWindowManager.mimeType(forPasteboardType: .fileURL))
		XCTAssertEqual(SeamlessWindowManager.pasteboardType(forMIME: "TEXT/Plain;Charset=UTF-8"), .string)
	}

	func testClipboardItemsOnlyGoToAGuestThatHasThem() throws {
		let (server, recorder, path) = try makeServer()
		defer { server.stop() }

		let fd = try connect(path)
		defer { Darwin.close(fd) }

		// Protocol 3 has the text clipboard, not the items: the message would make that guest close the connection.
		write(fd, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.clipboardVersion, name: "text-only")))
		XCTAssertEqual(try readHost(fd, count: 1), [.helloAck(version: SeamlessProtocol.clipboardVersion, scale120: 240)])
		XCTAssertTrue(wait { recorder.log == ["start text-only"] })

		recorder.session?.send(.clipboardItems([item("image/png", 64)]))
		recorder.session?.send(.clipboard(text: "text goes"))
		XCTAssertEqual(try readHost(fd, count: 1), [.clipboard(text: "text goes")])
	}

	func testClipboardItemsReachTheDelegateAndTheGuest() throws {
		let (server, recorder, path) = try makeServer()
		defer { server.stop() }

		let fd = try connect(path)
		defer { Darwin.close(fd) }

		write(fd, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "unit")))
		XCTAssertEqual(try readHost(fd, count: 1), [.helloAck(version: SeamlessProtocol.version, scale120: 240)])
		XCTAssertTrue(wait { recorder.log == ["start unit"] })

		let fromGuest = [item("text/plain;charset=utf-8", 10), item("image/png", 4096)]

		write(fd, try SeamlessCodec.encode(SeamlessGuestMessage.clipboardItems(fromGuest)))
		XCTAssertTrue(wait { recorder.received == [.clipboardItems(fromGuest)] })

		let fromMac = [item("image/png", 8192), item("text/html", 20)]

		recorder.session?.send(.clipboardItems(fromMac))
		XCTAssertEqual(try readHost(fd, count: 1), [.clipboardItems(fromMac)])
	}

	func testGuestOnProtocolOneIsAcceptedWithoutScrolling() throws {
		let (server, recorder, path) = try makeServer()
		defer { server.stop() }

		let fd = try connect(path)
		defer { Darwin.close(fd) }

		write(fd, try SeamlessCodec.encode(.hello(version: 1, name: "old")))
		// The host answers with the guest's version, an older compositor refuses any other.
		XCTAssertEqual(try readHost(fd, count: 1), [.helloAck(version: 1, scale120: 240)])
		XCTAssertTrue(wait { recorder.log == ["start old"] })
		XCTAssertEqual(recorder.session?.negotiatedVersion, 1)

		// Scrolling is dropped, everything else still goes through.
		recorder.session?.send(.pointerAxis(id: 3, dx: 0, dy: 1, source: .wheel))
		recorder.session?.send(.pointerMotion(id: 3, x: 1, y: 2))
		XCTAssertEqual(try readHost(fd, count: 1), [.pointerMotion(id: 3, x: 1, y: 2)])
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

	func testReplacedSessionStartIsNotDeliveredAfterTheNewOnes() throws {
		let path = "/tmp/seamless-\(UUID().uuidString.prefix(8)).sock"
		let recorder = Recorder()
		let queue = DispatchQueue(label: "test.seamless.delegate.blocked")
		let server = SeamlessServer(socketPath: path, delegate: recorder, delegateQueue: queue)

		try server.start()
		defer { server.stop() }

		// Hold the delegate queue so both start callbacks are queued before either is delivered.
		let gate = DispatchSemaphore(value: 0)
		queue.async { gate.wait() }

		let first = try connect(path)
		defer { Darwin.close(first) }
		write(first, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "one")))
		_ = try readHost(first, count: 1)

		let second = try connect(path)
		defer { Darwin.close(second) }
		write(second, try SeamlessCodec.encode(.hello(version: SeamlessProtocol.version, name: "two")))
		_ = try readHost(second, count: 1)

		// The replaced connection was closed.
		XCTAssertEqual(try readHost(first, count: 1), [])
		gate.signal()

		XCTAssertTrue(wait { recorder.log == ["start two"] })
		// Nothing for the replaced session comes later: neither a start nor an end.
		Thread.sleep(forTimeInterval: 0.2)
		XCTAssertEqual(recorder.log, ["start two"])
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
		// The peer stays open: the session must end because the server closed it, not because the peer went away (the deferred close releases it).
		server.stop()

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

	func testListenerLockTellsContentionFromASetupFailure() throws {
		let path = "/tmp/seamless-\(UUID().uuidString.prefix(8)).sock"
		defer { unlink(path + ".lock") }

		guard case .acquired(let first) = SeamlessServer.tryAcquireListenerLock(for: path) else { return XCTFail("a free lock must be acquired") }

		if case .contended = SeamlessServer.tryAcquireListenerLock(for: path) {
		} else {
			XCTFail("a lock held by someone else is contention")
		}

		SeamlessServer.releaseListenerLock(first)

		// The directory does not exist: nobody shows the windows, the setup is what is wrong
		if case .failed = SeamlessServer.tryAcquireListenerLock(for: "/tmp/seamless-missing-\(UUID().uuidString.prefix(8))/guest.sock") {
		} else {
			XCTFail("a lock file that can't be opened is not contention")
		}
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
