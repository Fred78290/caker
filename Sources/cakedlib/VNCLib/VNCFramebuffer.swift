import AppKit
import Foundation
import CryptoKit

public class VNCFramebuffer {
	public internal(set) var width: Int
	public internal(set) var height: Int
	public internal(set) var pixelData: Data
	public internal(set) var hasChanges = false
	public internal(set) var sizeChanged = false

    public internal(set) var currentChecksum: SHA256.Digest?
    internal var previousChecksum: SHA256.Digest? = nil

	internal weak var sourceView: NSView!
	internal var previousPixelData: Data?
	internal let updateQueue = DispatchQueue(label: "vnc.framebuffer.update")
	internal var bitmapInfo: CGBitmapInfo? = nil
	internal var bitsPerPixels: Int = 0

	public init(view: NSView) {
		self.sourceView = view
		self.width = Int(view.bounds.width)
		self.height = Int(view.bounds.height)
		self.pixelData = Data(count: width * height * 4)  // RGBA

		if let imageRepresentation = view.imageRepresentation(in: NSRect(x: 0, y: 0, width: 4, height: 4)) {
			if let cgImage = imageRepresentation.cgImage {
				self.bitsPerPixels = cgImage.bitsPerPixel
				self.bitmapInfo = cgImage.bitmapInfo;
			}
		}
	}

	public func renderStats() -> String {
		if let currentChecksum {
			let hexChecksum = currentChecksum.map { String(format: "%02x", $0) }.joined()
			
			return "Framebuffer - Size: \(width)x\(height), Has Changes: \(hasChanges), Size Changed: \(sizeChanged), Checksum: \(hexChecksum)"
		}

		return "Framebuffer - Size: \(width)x\(height), Has Changes: \(hasChanges), Size Changed: \(sizeChanged)"
	}

	public func averageRenderTime() -> TimeInterval {
		return 0
	}

	public func updateSize(width: Int, height: Int) {
		updateQueue.async {
			guard self.width != width || self.height != height else { return }

			self.width = width
			self.height = height
			self.pixelData = Data(count: width * height * 4)
			self.previousPixelData = nil
            self.previousChecksum = nil
            self.currentChecksum = nil
			self.sizeChanged = true
			self.hasChanges = true
		}
	}

	public func updateFromView() {
		let bounds = sourceView.bounds
		let newWidth = Int(bounds.width)
		let newHeight = Int(bounds.height)

		updateQueue.async {
			// Check if size has changed
			if self.width != newWidth || self.height != newHeight {
				self.updateSize(width: newWidth, height: newHeight)
			}

			// Capture content
			self.captureViewContent(view: self.sourceView, bounds: bounds)
		}
	}

	internal func captureViewContent(view: NSView, bounds: NSRect) {
		// Create image from view
		let imageRepresentation = DispatchQueue.main.sync {
			return view.imageRepresentation(in: bounds)
		}

		// Convert to pixel data
		if let imageRepresentation = imageRepresentation {
			convertBitmapToPixelData(bitmap: imageRepresentation)
		}
	}

	private func convertBitmapToPixelData(bitmap: NSBitmapImageRep) {
		if let cgImage = bitmap.cgImage {
			self.bitsPerPixels = cgImage.bitsPerPixel
			self.bitmapInfo = cgImage.bitmapInfo;

			if let provider = cgImage.dataProvider, let data = provider.data as NSData? {
				pixelData = data as Data
				previousPixelData = pixelData
				hasChanges = true
				return
			}
		}

		let bytesPerPixel = 4
		let bytesPerRow = width * bytesPerPixel

		self.currentChecksum = pixelData.withUnsafeMutableBytes { bytes in
			guard let pixels = bytes.bindMemory(to: UInt8.self).baseAddress else {
				return self.currentChecksum ?? SHA256.hash(data: Data((0..<16).map { _ in UInt8.random(in: 0...255) }))
			}
			
			var sha256 = SHA256()
			
			for y in 0..<height {
				for x in 0..<width {
					let color = bitmap.colorAt(x: x, y: y) ?? NSColor.black
					let srgbColor = color.usingColorSpace(.sRGB) ?? color
					let offset = (y * bytesPerRow) + (x * bytesPerPixel)
					
					pixels[offset + 0] = UInt8(srgbColor.redComponent * 255)  // R
					pixels[offset + 1] = UInt8(srgbColor.greenComponent * 255)  // G
					pixels[offset + 2] = UInt8(srgbColor.blueComponent * 255)  // B
					pixels[offset + 3] = UInt8(srgbColor.alphaComponent * 255)  // A
					
					let buffer = UnsafeRawBufferPointer(start: pixels + offset, count: 4)
					
					sha256.update(bufferPointer: buffer)
				}
			}
			
			return sha256.finalize()
		}
		
		// Check for changes using checksum comparison
		if previousChecksum != currentChecksum {
			hasChanges = true
			previousChecksum = currentChecksum
			previousPixelData = pixelData
		}
	}

	public func markAsProcessed() {
		updateQueue.async {
			self.hasChanges = false
			self.sizeChanged = false
		}
	}

	public func getPixelFormat() -> VNCPixelFormat {
		var pixelFormat = VNCPixelFormat()
		
		guard let bitmapInfo = self.bitmapInfo else {
			return pixelFormat
		}

		pixelFormat.bitsPerPixel = UInt8(self.bitsPerPixels)

		if bitmapInfo.byteOrder == .order32Little || bitmapInfo.byteOrder == .orderDefault {
			pixelFormat.depth = 24
			pixelFormat.redMax = UInt16(255).bigEndian
			pixelFormat.redMax = UInt16(255).bigEndian
			pixelFormat.blueMax = UInt16(255).bigEndian

			if bitmapInfo.alpha == .last {
				pixelFormat.redShift = 16
				pixelFormat.greenShift = 8
				pixelFormat.blueShift = 0
			} else if bitmapInfo.alpha == .first {
				pixelFormat.redShift = 24
				pixelFormat.greenShift = 16
				pixelFormat.blueShift = 8
			}
		} else if bitmapInfo.byteOrder == .order32Big {
			pixelFormat.depth = 24
			pixelFormat.redMax = UInt16(255).bigEndian
			pixelFormat.redMax = UInt16(255).bigEndian
			pixelFormat.blueMax = UInt16(255).bigEndian

			if bitmapInfo.alpha == .last {
				pixelFormat.redShift = 0
				pixelFormat.greenShift = 8
				pixelFormat.blueShift = 16
			} else if bitmapInfo.alpha == .first {
				pixelFormat.redShift = 8
				pixelFormat.greenShift = 16
				pixelFormat.blueShift = 24
			}
		} else if bitmapInfo.byteOrder == .order16Little {
			pixelFormat.depth = 12
			pixelFormat.redMax = UInt16(16).bigEndian
			pixelFormat.redMax = UInt16(16).bigEndian
			pixelFormat.blueMax = UInt16(16).bigEndian

			if bitmapInfo.alpha == .last {
				pixelFormat.redShift = 8
				pixelFormat.greenShift = 4
				pixelFormat.blueShift = 0
			} else if bitmapInfo.alpha == .first {
				pixelFormat.redShift = 12
				pixelFormat.greenShift = 8
				pixelFormat.blueShift = 4
			}
		} else if bitmapInfo.byteOrder == .order16Big {
			pixelFormat.depth = 16
			pixelFormat.redMax = UInt16(16).bigEndian
			pixelFormat.redMax = UInt16(16).bigEndian
			pixelFormat.blueMax = UInt16(16).bigEndian

			if bitmapInfo.alpha == .last {
				pixelFormat.redShift = 8
				pixelFormat.greenShift = 4
				pixelFormat.blueShift = 0
			} else if bitmapInfo.alpha == .first {
				pixelFormat.redShift = 12
				pixelFormat.greenShift = 8
				pixelFormat.blueShift = 4
			}
		}
		
		return pixelFormat
	}

	public func getCurrentState() -> (width: Int, height: Int, data: Data, hasChanges: Bool, sizeChanged: Bool, checksum: SHA256.Digest?) {
		return (width: width, height: height, data: pixelData, hasChanges: hasChanges, sizeChanged: sizeChanged, checksum: currentChecksum)
	}
}

