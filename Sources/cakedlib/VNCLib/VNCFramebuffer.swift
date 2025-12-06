import AppKit
import Foundation
import CryptoKit

extension CGImageAlphaInfo {
	var isFirst: Bool {
		return self == .first || self == .premultipliedFirst
	}

	var isLast: Bool {
		return self == .last || self == .premultipliedLast
	}
}

public class VNCFramebuffer {
	public internal(set) var width: Int
	public internal(set) var height: Int
	internal var pixelData: Data
	internal var hasChanges = false
	internal var sizeChanged = false
	internal weak var sourceView: NSView!
	internal let updateQueue = DispatchQueue(label: "vnc.framebuffer.update")
	internal var pixelFormat = VNCPixelFormat()
	internal var bitmapInfo: CGBitmapInfo? = nil
	internal var bitsPerPixels: Int = 0
	internal let logger = Logger("VNCFramebuffer")

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

	public func updateSize(width: Int, height: Int) {
		guard self.width != width || self.height != height else { return }

		if width == 0 || height == 0 {
			self.logger.debug("View size is zero, skipping frame capture.")
		}

		updateQueue.async {
			self.width = width
			self.height = height
			self.pixelData = Data(count: width * height * 4)
			self.sizeChanged = true
			self.hasChanges = true
		}
	}

	public func updateFromView() {
		let bounds = sourceView.bounds
		let newWidth = Int(bounds.width)
		let newHeight = Int(bounds.height)

		updateQueue.async {
			if newWidth == 0 || newHeight == 0 {
				self.logger.debug("View size is zero, skipping frame capture.")
			}

			// Check if size has changed
			if self.width != newWidth || self.height != newHeight {
				self.width = newWidth
				self.height = newHeight
				self.pixelData = Data(count: newWidth * newHeight * 4)
				self.sizeChanged = true
				self.hasChanges = true
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

			if let provider = cgImage.dataProvider, let imageSource = provider.data as Data? {
				var pixelData = Data(count: width*height*4)
				
				imageSource.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
					pixelData.withUnsafeMutableBytes { (dstRaw: UnsafeMutableRawBufferPointer) in
						guard let sp = srcRaw.bindMemory(to: UInt8.self).baseAddress, let dp = dstRaw.bindMemory(to: UInt8.self).baseAddress else { return }
						let rowWidth = self.width * 4

						for row in 0..<height {
							let srcPtr = sp.advanced(by: cgImage.bytesPerRow * row)
							let dstPtr = dp.advanced(by: (width * 4) * row)

							memcpy(dstPtr, srcPtr, rowWidth)
						}
					}
				}

				self.hasChanges = true
				self.pixelData = pixelData
			}
		}
	}

	@MainActor
	func markAsProcessed() {
		self.hasChanges = false
		self.sizeChanged = false
	}

	func getPixelFormat() -> VNCPixelFormat {
		guard let bitmapInfo = self.bitmapInfo else {
			return pixelFormat
		}

		pixelFormat.bitsPerPixel = UInt8(self.bitsPerPixels)

		if bitmapInfo.byteOrder == .order32Little {
			pixelFormat.depth = 24
			pixelFormat.redMax = UInt16(255).bigEndian
			pixelFormat.redMax = UInt16(255).bigEndian
			pixelFormat.blueMax = UInt16(255).bigEndian
			pixelFormat.bigEndianFlag = 0

			if bitmapInfo.alpha.isLast {
				pixelFormat.redShift = 16
				pixelFormat.greenShift = 8
				pixelFormat.blueShift = 0
			} else if bitmapInfo.alpha.isFirst {
				pixelFormat.redShift = 24
				pixelFormat.greenShift = 16
				pixelFormat.blueShift = 8
			}
		} else if bitmapInfo.byteOrder == .order32Big || bitmapInfo.byteOrder == .orderDefault {
			pixelFormat.depth = 24
			pixelFormat.redMax = UInt16(255).bigEndian
			pixelFormat.redMax = UInt16(255).bigEndian
			pixelFormat.blueMax = UInt16(255).bigEndian
			pixelFormat.bigEndianFlag = 1

			if bitmapInfo.alpha.isLast {
				pixelFormat.redShift = 0
				pixelFormat.greenShift = 8
				pixelFormat.blueShift = 16
			} else if bitmapInfo.alpha.isFirst {
				pixelFormat.redShift = 8
				pixelFormat.greenShift = 16
				pixelFormat.blueShift = 24
			}
		} else if bitmapInfo.byteOrder == .order16Little {
			pixelFormat.depth = 16
			pixelFormat.redMax = UInt16(16).bigEndian
			pixelFormat.redMax = UInt16(16).bigEndian
			pixelFormat.blueMax = UInt16(16).bigEndian

			if bitmapInfo.alpha.isLast {
				pixelFormat.redShift = 8
				pixelFormat.greenShift = 4
				pixelFormat.blueShift = 0
			} else if bitmapInfo.alpha.isFirst {
				pixelFormat.redShift = 12
				pixelFormat.greenShift = 8
				pixelFormat.blueShift = 4
			}
		} else if bitmapInfo.byteOrder == .order16Big {
			pixelFormat.depth = 16
			pixelFormat.redMax = UInt16(16).bigEndian
			pixelFormat.redMax = UInt16(16).bigEndian
			pixelFormat.blueMax = UInt16(16).bigEndian
			pixelFormat.bigEndianFlag = 1

			if bitmapInfo.alpha.isLast {
				pixelFormat.redShift = 8
				pixelFormat.greenShift = 4
				pixelFormat.blueShift = 0
			} else if bitmapInfo.alpha.isFirst {
				pixelFormat.redShift = 12
				pixelFormat.greenShift = 8
				pixelFormat.blueShift = 4
			}
		}
		
		return pixelFormat
	}

	func convertToClient(_ pixelData: Data, clientFormat: VNCPixelFormat?) -> Data {
		if let clientFormat = clientFormat {
			return clientFormat.transform(pixelData)
		}
		
		return self.pixelFormat.transform(pixelData)
	}

	@MainActor
	func setCurrentState(width: Int, height: Int, pixelData: Data, hasChanges: Bool, sizeChanged: Bool) {
		self.width = width
		self.height = height
		self.pixelData = pixelData
		self.hasChanges = hasChanges
		self.sizeChanged = sizeChanged
	}

	@MainActor
	func getCurrentState() -> (width: Int, height: Int, data: Data, hasChanges: Bool, sizeChanged: Bool) {
		return (width: width, height: height, data: pixelData, hasChanges: hasChanges, sizeChanged: sizeChanged)
	}
}

