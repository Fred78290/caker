import Compression
import Foundation

// MARK: - Seamless window protocol
//
// Wire format of the "seamless windows" channel: a guest compositor (Weston/wlroots based, with XWayland)
// streams one pixel buffer per Wayland toplevel/popup to the host, which shows each of them in its own
// native window, and the host sends input back. Same idea as WSLg's RDP RAIL, without RDP.
//
// Transport: a vsock stream (guest connects to `SeamlessProtocol.defaultVsockPort`; Caker's existing
// `connect://vsock:PORT/path.sock` socket device bridges it to a host unix socket).
//
// Framing: every message is `u32 length` (counts the type byte and the payload) + `u8 type` + payload.
// All integers are little endian, floats are IEEE-754 binary32, strings are `u16 length` + UTF-8 bytes.
// Types 0x01...0x7F are sent by the guest, 0x81...0xFF by the host.
//
// The guest is not trusted: every length, dimension and rectangle is bounds checked, decoding never traps.

/// What a `pointerAxis` message carries (`wl_pointer.axis_source`).
public enum SeamlessAxisSource: UInt8, Sendable {
	/// Trackpad: `dx`/`dy` are logical pixels, the guest reports them as a finger scroll.
	case continuous = 0
	/// Mouse wheel: `dx`/`dy` are notches (1 == one click), the guest reports discrete steps.
	case wheel = 1
	/// The fingers left the trackpad: the guest sends `axis_stop` (`dx`/`dy` are ignored).
	case stop = 2
}

public enum SeamlessProtocol {
	public static let version: UInt16 = 2
	/// The oldest guest version the host still talks to: it answers with the guest's version and leaves out what that version lacks
	/// (version 1 has no scroll wheel, `pointerAxis` is never sent to it).
	public static let minimumVersion: UInt16 = 1
	/// First version with the `pointerAxis` source byte, so the first with scrolling.
	public static let axisVersion: UInt16 = 2
	/// vsock port the guest compositor connects to.
	public static let defaultVsockPort = 5100

	public static let maxFrameLength = 192 * 1024 * 1024
	public static let maxStringLength = 4096
	public static let maxRectsPerFrame = 1024
	public static let maxBufferDimension: UInt32 = 16384
	/// Largest rectangle (and buffer), in pixels.
	public static let maxRectPixels = 40_000_000
	public static let bytesPerPixel = 4

	/// BTN_LEFT / BTN_RIGHT / BTN_MIDDLE, the codes Wayland compositors expect.
	public static let buttonLeft: UInt32 = 0x110
	public static let buttonRight: UInt32 = 0x111
	public static let buttonMiddle: UInt32 = 0x112
}

public enum SeamlessProtocolError: Error, Equatable, CustomStringConvertible {
	case truncated
	case frameTooLarge(Int)
	case emptyFrame
	case unknownMessageType(UInt8)
	case stringTooLong(Int)
	case invalidUTF8
	case invalidValue(String)
	case invalidDimensions(UInt32, UInt32)
	case rectOutOfBounds
	case tooManyRects(Int)
	case unknownPixelFormat(UInt8)
	case unknownCompression(UInt8)
	case decompressionFailed
	case trailingBytes(Int)

	public var description: String {
		switch self {
		case .truncated: return "truncated message"
		case .frameTooLarge(let n): return "frame of \(n) bytes exceeds the limit"
		case .emptyFrame: return "empty frame"
		case .unknownMessageType(let t): return "unknown message type 0x\(String(t, radix: 16))"
		case .stringTooLong(let n): return "string of \(n) bytes exceeds the limit"
		case .invalidUTF8: return "invalid UTF-8 string"
		case .invalidValue(let what): return "invalid value: \(what)"
		case .invalidDimensions(let w, let h): return "invalid dimensions \(w)x\(h)"
		case .rectOutOfBounds: return "rectangle outside of the buffer"
		case .tooManyRects(let n): return "\(n) rectangles in one frame"
		case .unknownPixelFormat(let f): return "unknown pixel format \(f)"
		case .unknownCompression(let c): return "unknown compression \(c)"
		case .decompressionFailed: return "decompression failed"
		case .trailingBytes(let n): return "\(n) unexpected trailing bytes"
		}
	}
}

// MARK: - Model

public struct SeamlessRect: Equatable, Sendable {
	public var x: UInt32
	public var y: UInt32
	public var width: UInt32
	public var height: UInt32

	public init(x: UInt32, y: UInt32, width: UInt32, height: UInt32) {
		self.x = x
		self.y = y
		self.width = width
		self.height = height
	}
}

/// Pixels of one damaged rectangle: BGRA, premultiplied alpha (`wl_shm` ARGB8888 on a little endian machine),
/// tightly packed rows, so `pixels.count == width * height * 4`.
public struct SeamlessFrameRect: Equatable, Sendable {
	public var rect: SeamlessRect
	public var pixels: Data

	public init(rect: SeamlessRect, pixels: Data) {
		self.rect = rect
		self.pixels = pixels
	}
}

/// A window's content: the size of its whole buffer in pixels and the rectangles that changed.
public struct SeamlessFrame: Equatable, Sendable {
	public var windowID: UInt32
	public var width: UInt32
	public var height: UInt32
	public var rects: [SeamlessFrameRect]

	public init(windowID: UInt32, width: UInt32, height: UInt32, rects: [SeamlessFrameRect]) {
		self.windowID = windowID
		self.width = width
		self.height = height
		self.rects = rects
	}
}

public enum SeamlessWindowKind: UInt8, Sendable {
	case toplevel = 0
	case popup = 1
}

public struct SeamlessWindowInfo: Equatable, Sendable {
	public var id: UInt32
	/// 0 when there is none. A popup is positioned relative to its parent.
	public var parentID: UInt32
	public var kind: SeamlessWindowKind
	/// Popup offset from its parent's top-left corner, in logical units.
	public var x: Int32
	public var y: Int32
	public var title: String
	public var appID: String

	public init(id: UInt32, parentID: UInt32 = 0, kind: SeamlessWindowKind = .toplevel, x: Int32 = 0, y: Int32 = 0, title: String = "", appID: String = "") {
		self.id = id
		self.parentID = parentID
		self.kind = kind
		self.x = x
		self.y = y
		self.title = title
		self.appID = appID
	}
}

/// Size limits in logical units, 0 means unconstrained.
public struct SeamlessSizeHints: Equatable, Sendable {
	public var minWidth: UInt32
	public var minHeight: UInt32
	public var maxWidth: UInt32
	public var maxHeight: UInt32

	public init(minWidth: UInt32 = 0, minHeight: UInt32 = 0, maxWidth: UInt32 = 0, maxHeight: UInt32 = 0) {
		self.minWidth = minWidth
		self.minHeight = minHeight
		self.maxWidth = maxWidth
		self.maxHeight = maxHeight
	}
}

/// Guest -> host.
public enum SeamlessGuestMessage: Equatable, Sendable {
	case hello(version: UInt16, name: String)
	case windowCreate(SeamlessWindowInfo)
	case windowTitle(id: UInt32, title: String)
	case windowAppID(id: UInt32, appID: String)
	case windowHints(id: UInt32, hints: SeamlessSizeHints)
	case windowFrame(SeamlessFrame)
	case windowDestroy(id: UInt32)
	/// CSS cursor name (`default`, `text`, `pointer`, `crosshair`, `ew-resize`, ...), as in `wp_cursor_shape`.
	case cursor(id: UInt32, shape: String)
}

/// Host -> guest. Coordinates and sizes are logical (what Wayland calls surface coordinates), a buffer is
/// `logical * scale120 / 120` pixels.
public enum SeamlessHostMessage: Equatable, Sendable {
	case helloAck(version: UInt16, scale120: UInt32)
	/// The output scale changed (`wp_fractional_scale` units: 120 == 1x).
	case output(scale120: UInt32)
	case windowResize(id: UInt32, width: UInt32, height: UInt32)
	/// The user asked to close the window; the guest decides and sends `windowDestroy`.
	case windowClose(id: UInt32)
	case windowFocus(id: UInt32, focused: Bool)
	case pointerEnter(id: UInt32, x: Float, y: Float)
	case pointerLeave(id: UInt32)
	case pointerMotion(id: UInt32, x: Float, y: Float)
	case pointerButton(id: UInt32, button: UInt32, pressed: Bool)
	/// Scroll, positive `dy` scrolls content down like `wl_pointer.axis`. The unit of `dx`/`dy` depends on `source`.
	case pointerAxis(id: UInt32, dx: Float, dy: Float, source: SeamlessAxisSource)
	/// Linux evdev key code (`KEY_A` == 30), delivered to the focused window.
	case key(code: UInt32, pressed: Bool)
}

// MARK: - Primitives

struct SeamlessWriter {
	var data = Data()

	mutating func u8(_ v: UInt8) { data.append(v) }

	mutating func u16(_ v: UInt16) {
		withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
	}

	mutating func u32(_ v: UInt32) {
		withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
	}

	mutating func i32(_ v: Int32) { u32(UInt32(bitPattern: v)) }

	mutating func f32(_ v: Float) { u32(v.bitPattern) }

	mutating func string(_ s: String) throws {
		let utf8 = Array(s.utf8)

		guard utf8.count <= SeamlessProtocol.maxStringLength else {
			throw SeamlessProtocolError.stringTooLong(utf8.count)
		}

		u16(UInt16(utf8.count))
		data.append(contentsOf: utf8)
	}
}

struct SeamlessReader {
	let bytes: [UInt8]
	private(set) var offset = 0

	init(_ bytes: [UInt8]) { self.bytes = bytes }

	var remaining: Int { bytes.count - offset }

	private mutating func take(_ n: Int) throws -> Range<Int> {
		guard n >= 0, remaining >= n else { throw SeamlessProtocolError.truncated }
		defer { offset += n }
		return offset..<(offset + n)
	}

	mutating func u8() throws -> UInt8 { bytes[try take(1).lowerBound] }

	mutating func u16() throws -> UInt16 {
		let r = try take(2)
		return UInt16(bytes[r.lowerBound]) | UInt16(bytes[r.lowerBound + 1]) << 8
	}

	mutating func u32() throws -> UInt32 {
		let r = try take(4)
		var v: UInt32 = 0
		for i in 0..<4 { v |= UInt32(bytes[r.lowerBound + i]) << (8 * UInt32(i)) }
		return v
	}

	mutating func i32() throws -> Int32 { Int32(bitPattern: try u32()) }

	mutating func f32() throws -> Float {
		let v = Float(bitPattern: try u32())

		guard v.isFinite else { throw SeamlessProtocolError.invalidValue("non finite float") }

		return v
	}

	mutating func string() throws -> String {
		let n = Int(try u16())

		guard n <= SeamlessProtocol.maxStringLength else { throw SeamlessProtocolError.stringTooLong(n) }

		let r = try take(n)

		guard let s = String(bytes: bytes[r], encoding: .utf8) else { throw SeamlessProtocolError.invalidUTF8 }

		return s
	}

	mutating func slice(_ n: Int) throws -> ArraySlice<UInt8> { bytes[try take(n)] }

	func finish() throws {
		guard remaining == 0 else { throw SeamlessProtocolError.trailingBytes(remaining) }
	}
}

// MARK: - LZ4

enum SeamlessLZ4 {
	/// Raw LZ4 block (what liblz4's `LZ4_compress_default` produces), `nil` when it doesn't make the data smaller.
	static func compress(_ source: Data) -> Data? {
		guard source.count > 64 else { return nil }

		var out = Data(count: source.count)
		let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
			source.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
				compression_encode_buffer(
					dst.bindMemory(to: UInt8.self).baseAddress!, dst.count,
					src.bindMemory(to: UInt8.self).baseAddress!, src.count,
					nil, COMPRESSION_LZ4_RAW)
			}
		}

		guard written > 0, written < source.count else { return nil }

		out.removeSubrange(written...)

		return out
	}

	/// `compression_decode_buffer` truncates silently when the output doesn't fit, so ask for one byte more than
	/// expected: anything but exactly `expected` means the stream lied about its size.
	static func decompress(_ source: ArraySlice<UInt8>, expected: Int) -> Data? {
		guard expected > 0 else { return nil }

		var out = Data(count: expected + 1)
		let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
			source.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
				guard let s = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
				return compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, dst.count, s, src.count, nil, COMPRESSION_LZ4_RAW)
			}
		}

		guard written == expected else { return nil }

		out.removeLast()

		return out
	}
}

// MARK: - Codec

public enum SeamlessCodec {
	private enum GuestType: UInt8 {
		case hello = 0x01, windowCreate, windowTitle, windowAppID, windowHints, windowFrame, windowDestroy, cursor
	}

	private enum HostType: UInt8 {
		case helloAck = 0x81, output, windowResize, windowClose, windowFocus, pointerEnter, pointerLeave, pointerMotion, pointerButton, pointerAxis, key
	}

	private static let pixelFormatBGRA: UInt8 = 0
	private static let compressionNone: UInt8 = 0
	private static let compressionLZ4: UInt8 = 1

	private static func wrap(type: UInt8, _ payload: SeamlessWriter) throws -> Data {
		let length = payload.data.count + 1

		guard length <= SeamlessProtocol.maxFrameLength else { throw SeamlessProtocolError.frameTooLarge(length) }

		var out = SeamlessWriter()

		out.u32(UInt32(length))
		out.u8(type)
		out.data.append(payload.data)

		return out.data
	}

	public static func validate(width: UInt32, height: UInt32) throws {
		guard width > 0, height > 0, width <= SeamlessProtocol.maxBufferDimension, height <= SeamlessProtocol.maxBufferDimension,
			Int(width) * Int(height) <= SeamlessProtocol.maxRectPixels
		else {
			throw SeamlessProtocolError.invalidDimensions(width, height)
		}
	}

	// MARK: Encode

	/// - Parameter compress: LZ4 every rectangle that gets smaller.
	public static func encode(_ message: SeamlessGuestMessage, compress: Bool = true) throws -> Data {
		var w = SeamlessWriter()
		let type: GuestType

		switch message {
		case .hello(let version, let name):
			type = .hello
			w.u16(version)
			try w.string(name)
		case .windowCreate(let info):
			type = .windowCreate
			w.u32(info.id)
			w.u32(info.parentID)
			w.u8(info.kind.rawValue)
			w.i32(info.x)
			w.i32(info.y)
			try w.string(info.title)
			try w.string(info.appID)
		case .windowTitle(let id, let title):
			type = .windowTitle
			w.u32(id)
			try w.string(title)
		case .windowAppID(let id, let appID):
			type = .windowAppID
			w.u32(id)
			try w.string(appID)
		case .windowHints(let id, let hints):
			type = .windowHints
			w.u32(id)
			w.u32(hints.minWidth)
			w.u32(hints.minHeight)
			w.u32(hints.maxWidth)
			w.u32(hints.maxHeight)
		case .windowFrame(let frame):
			type = .windowFrame
			try validate(width: frame.width, height: frame.height)
			guard frame.rects.count <= SeamlessProtocol.maxRectsPerFrame else { throw SeamlessProtocolError.tooManyRects(frame.rects.count) }

			w.u32(frame.windowID)
			w.u32(frame.width)
			w.u32(frame.height)
			w.u8(pixelFormatBGRA)
			w.u16(UInt16(frame.rects.count))

			for item in frame.rects {
				let r = item.rect

				guard r.width > 0, r.height > 0, UInt64(r.x) + UInt64(r.width) <= UInt64(frame.width), UInt64(r.y) + UInt64(r.height) <= UInt64(frame.height) else {
					throw SeamlessProtocolError.rectOutOfBounds
				}

				guard item.pixels.count == Int(r.width) * Int(r.height) * SeamlessProtocol.bytesPerPixel else {
					throw SeamlessProtocolError.invalidValue("pixel count does not match the rectangle")
				}

				w.u32(r.x)
				w.u32(r.y)
				w.u32(r.width)
				w.u32(r.height)

				if compress, let packed = SeamlessLZ4.compress(item.pixels) {
					w.u8(compressionLZ4)
					w.u32(UInt32(packed.count))
					w.data.append(packed)
				} else {
					w.u8(compressionNone)
					w.u32(UInt32(item.pixels.count))
					w.data.append(item.pixels)
				}
			}
		case .windowDestroy(let id):
			type = .windowDestroy
			w.u32(id)
		case .cursor(let id, let shape):
			type = .cursor
			w.u32(id)
			try w.string(shape)
		}

		return try wrap(type: type.rawValue, w)
	}

	public static func encode(_ message: SeamlessHostMessage) throws -> Data {
		var w = SeamlessWriter()
		let type: HostType

		switch message {
		case .helloAck(let version, let scale):
			type = .helloAck
			w.u16(version)
			w.u32(scale)
		case .output(let scale):
			type = .output
			w.u32(scale)
		case .windowResize(let id, let width, let height):
			type = .windowResize
			w.u32(id)
			w.u32(width)
			w.u32(height)
		case .windowClose(let id):
			type = .windowClose
			w.u32(id)
		case .windowFocus(let id, let focused):
			type = .windowFocus
			w.u32(id)
			w.u8(focused ? 1 : 0)
		case .pointerEnter(let id, let x, let y):
			type = .pointerEnter
			w.u32(id)
			w.f32(x)
			w.f32(y)
		case .pointerLeave(let id):
			type = .pointerLeave
			w.u32(id)
		case .pointerMotion(let id, let x, let y):
			type = .pointerMotion
			w.u32(id)
			w.f32(x)
			w.f32(y)
		case .pointerButton(let id, let button, let pressed):
			type = .pointerButton
			w.u32(id)
			w.u32(button)
			w.u8(pressed ? 1 : 0)
		case .pointerAxis(let id, let dx, let dy, let source):
			type = .pointerAxis
			w.u32(id)
			w.f32(dx)
			w.f32(dy)
			w.u8(source.rawValue)
		case .key(let code, let pressed):
			type = .key
			w.u32(code)
			w.u8(pressed ? 1 : 0)
		}

		return try wrap(type: type.rawValue, w)
	}

	// MARK: Decode

	public static func decodeGuest(type: UInt8, payload: [UInt8]) throws -> SeamlessGuestMessage {
		guard let kind = GuestType(rawValue: type) else { throw SeamlessProtocolError.unknownMessageType(type) }

		var r = SeamlessReader(payload)
		let message: SeamlessGuestMessage

		switch kind {
		case .hello:
			message = .hello(version: try r.u16(), name: try r.string())
		case .windowCreate:
			let id = try r.u32()
			let parent = try r.u32()

			guard let windowKind = SeamlessWindowKind(rawValue: try r.u8()) else { throw SeamlessProtocolError.invalidValue("window kind") }

			message = .windowCreate(
				SeamlessWindowInfo(id: id, parentID: parent, kind: windowKind, x: try r.i32(), y: try r.i32(), title: try r.string(), appID: try r.string()))
		case .windowTitle:
			message = .windowTitle(id: try r.u32(), title: try r.string())
		case .windowAppID:
			message = .windowAppID(id: try r.u32(), appID: try r.string())
		case .windowHints:
			message = .windowHints(
				id: try r.u32(), hints: SeamlessSizeHints(minWidth: try r.u32(), minHeight: try r.u32(), maxWidth: try r.u32(), maxHeight: try r.u32()))
		case .windowFrame:
			message = .windowFrame(try decodeFrame(&r))
		case .windowDestroy:
			message = .windowDestroy(id: try r.u32())
		case .cursor:
			message = .cursor(id: try r.u32(), shape: try r.string())
		}

		try r.finish()

		return message
	}

	private static func decodeFrame(_ r: inout SeamlessReader) throws -> SeamlessFrame {
		let id = try r.u32()
		let width = try r.u32()
		let height = try r.u32()

		try validate(width: width, height: height)

		let format = try r.u8()

		guard format == pixelFormatBGRA else { throw SeamlessProtocolError.unknownPixelFormat(format) }

		let count = Int(try r.u16())

		guard count <= SeamlessProtocol.maxRectsPerFrame else { throw SeamlessProtocolError.tooManyRects(count) }

		var rects: [SeamlessFrameRect] = []
		var totalPixels = 0

		rects.reserveCapacity(count)

		for _ in 0..<count {
			let rect = SeamlessRect(x: try r.u32(), y: try r.u32(), width: try r.u32(), height: try r.u32())

			guard rect.width > 0, rect.height > 0, UInt64(rect.x) + UInt64(rect.width) <= UInt64(width), UInt64(rect.y) + UInt64(rect.height) <= UInt64(height) else {
				throw SeamlessProtocolError.rectOutOfBounds
			}

			let pixelCount = Int(rect.width) * Int(rect.height)

			// A frame may repeat rectangles but not inflate beyond what one buffer can hold several times over.
			totalPixels += pixelCount

			guard pixelCount <= SeamlessProtocol.maxRectPixels, totalPixels <= SeamlessProtocol.maxRectPixels * 2 else {
				throw SeamlessProtocolError.invalidDimensions(rect.width, rect.height)
			}

			let expected = pixelCount * SeamlessProtocol.bytesPerPixel
			let compression = try r.u8()
			let length = Int(try r.u32())
			let data = try r.slice(length)

			switch compression {
			case compressionNone:
				guard length == expected else { throw SeamlessProtocolError.invalidValue("raw rectangle size") }

				rects.append(SeamlessFrameRect(rect: rect, pixels: Data(data)))
			case compressionLZ4:
				guard let pixels = SeamlessLZ4.decompress(data, expected: expected) else { throw SeamlessProtocolError.decompressionFailed }

				rects.append(SeamlessFrameRect(rect: rect, pixels: pixels))
			default:
				throw SeamlessProtocolError.unknownCompression(compression)
			}
		}

		return SeamlessFrame(windowID: id, width: width, height: height, rects: rects)
	}

	public static func decodeHost(type: UInt8, payload: [UInt8]) throws -> SeamlessHostMessage {
		guard let kind = HostType(rawValue: type) else { throw SeamlessProtocolError.unknownMessageType(type) }

		var r = SeamlessReader(payload)
		let message: SeamlessHostMessage

		switch kind {
		case .helloAck:
			message = .helloAck(version: try r.u16(), scale120: try r.u32())
		case .output:
			message = .output(scale120: try r.u32())
		case .windowResize:
			message = .windowResize(id: try r.u32(), width: try r.u32(), height: try r.u32())
		case .windowClose:
			message = .windowClose(id: try r.u32())
		case .windowFocus:
			message = .windowFocus(id: try r.u32(), focused: try r.u8() != 0)
		case .pointerEnter:
			message = .pointerEnter(id: try r.u32(), x: try r.f32(), y: try r.f32())
		case .pointerLeave:
			message = .pointerLeave(id: try r.u32())
		case .pointerMotion:
			message = .pointerMotion(id: try r.u32(), x: try r.f32(), y: try r.f32())
		case .pointerButton:
			message = .pointerButton(id: try r.u32(), button: try r.u32(), pressed: try r.u8() != 0)
		case .pointerAxis:
			let id = try r.u32(), dx = try r.f32(), dy = try r.f32()
			let rawSource = try r.u8()

			guard let source = SeamlessAxisSource(rawValue: rawSource) else { throw SeamlessProtocolError.invalidValue("axis source \(rawSource)") }

			message = .pointerAxis(id: id, dx: dx, dy: dy, source: source)
		case .key:
			message = .key(code: try r.u32(), pressed: try r.u8() != 0)
		}

		try r.finish()

		return message
	}
}

// MARK: - Stream decoder

/// Splits a byte stream into `(type, payload)` messages; feed it whatever `read()` returned.
public struct SeamlessFrameDecoder {
	private var buffer: [UInt8] = []
	private var head = 0

	public init() {}

	public mutating func append(_ bytes: UnsafeRawBufferPointer) {
		buffer.append(contentsOf: bytes.bindMemory(to: UInt8.self))
	}

	public mutating func append(_ data: Data) {
		buffer.append(contentsOf: data)
	}

	/// Next complete message, `nil` when more bytes are needed. Throws on a length that can never be valid, after
	/// which the stream is unusable and the connection must be closed.
	public mutating func next() throws -> (type: UInt8, payload: [UInt8])? {
		let available = buffer.count - head

		guard available >= 4 else { return nil }

		let length =
			Int(buffer[head]) | Int(buffer[head + 1]) << 8 | Int(buffer[head + 2]) << 16 | Int(buffer[head + 3]) << 24

		guard length >= 1 else { throw SeamlessProtocolError.emptyFrame }
		guard length <= SeamlessProtocol.maxFrameLength else { throw SeamlessProtocolError.frameTooLarge(length) }
		guard available >= 4 + length else { return nil }

		let type = buffer[head + 4]
		let payload = Array(buffer[(head + 5)..<(head + 4 + length)])

		head += 4 + length

		if head == buffer.count {
			buffer.removeAll(keepingCapacity: true)
			head = 0
		} else if head > 1 << 20 && head > buffer.count / 2 {
			buffer.removeSubrange(0..<head)
			head = 0
		}

		return (type, payload)
	}
}
