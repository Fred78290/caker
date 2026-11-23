import CoreGraphics
import Foundation

/// Host-side copy of one guest window's pixels. Not thread safe: owned by whoever shows the window (the main
/// thread), frames are decoded elsewhere and only the copy of the damaged rectangles happens here.
public final class SeamlessSurface {
	public private(set) var width = 0
	public private(set) var height = 0
	private var storage: UnsafeMutableRawPointer?

	public init() {}

	deinit {
		self.storage?.deallocate()
	}

	private var stride: Int { width * SeamlessProtocol.bytesPerPixel }

	/// Applies a decoded frame: a different buffer size reallocates (transparent), then each rectangle is copied.
	public func apply(_ frame: SeamlessFrame) throws {
		try SeamlessCodec.validate(width: frame.width, height: frame.height)

		let newWidth = Int(frame.width)
		let newHeight = Int(frame.height)

		// Validate everything before touching the buffer, so a bad frame leaves the surface as it was.
		for item in frame.rects {
			let r = item.rect

			// Same rules as `SeamlessCodec.decodeFrame`: an empty rectangle is invalid (an empty rectangle *list* is fine).
			guard r.width > 0, r.height > 0,
				UInt64(r.x) + UInt64(r.width) <= UInt64(newWidth), UInt64(r.y) + UInt64(r.height) <= UInt64(newHeight),
				item.pixels.count == Int(r.width) * Int(r.height) * SeamlessProtocol.bytesPerPixel
			else {
				throw SeamlessProtocolError.rectOutOfBounds
			}
		}

		if newWidth != width || newHeight != height {
			self.allocate(width: newWidth, height: newHeight)
		}

		guard let base = storage else { return }

		for item in frame.rects {
			let r = item.rect
			let rowBytes = Int(r.width) * SeamlessProtocol.bytesPerPixel

			item.pixels.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
				for row in 0..<Int(r.height) {
					let dst = base + (Int(r.y) + row) * stride + Int(r.x) * SeamlessProtocol.bytesPerPixel

					dst.copyMemory(from: src.baseAddress! + row * rowBytes, byteCount: rowBytes)
				}
			}
		}
	}

	private func allocate(width: Int, height: Int) {
		self.storage?.deallocate()

		let size = width * height * SeamlessProtocol.bytesPerPixel
		let memory = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)

		memory.initializeMemory(as: UInt8.self, repeating: 0, count: size)

		self.storage = memory
		self.width = width
		self.height = height
	}

	/// Immutable snapshot of the current content (`nil` before the first frame). The pixels are copied: the buffer is
	/// updated in place by later frames, and an image that aliased it would tear while the layer is composited.
	public func makeImage() -> CGImage? {
		guard let base = storage, width > 0, height > 0 else { return nil }

		let size = width * height * SeamlessProtocol.bytesPerPixel

		guard let provider = CGDataProvider(data: Data(bytes: base, count: size) as CFData) else { return nil }

		// BGRA premultiplied, the layout of wl_shm ARGB8888 on a little endian machine.
		return CGImage(
			width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * SeamlessProtocol.bytesPerPixel,
			space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
			provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
	}

	/// BGRA bytes of one pixel, for tests.
	public func pixel(x: Int, y: Int) -> [UInt8]? {
		guard let base = storage, x >= 0, y >= 0, x < width, y < height else { return nil }

		let p = (base + y * stride + x * SeamlessProtocol.bytesPerPixel).assumingMemoryBound(to: UInt8.self)

		return [p[0], p[1], p[2], p[3]]
	}
}
