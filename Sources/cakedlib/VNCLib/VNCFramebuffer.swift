import AppKit
import CryptoKit
import Foundation
import Synchronization

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
	internal let pixelData: Mutex<Data>
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
		self.pixelData = .init(Data(count: width * height * 4))  // RGBA

		if let imageRepresentation = view.imageRepresentationSync(in: NSRect(x: 0, y: 0, width: 4, height: 4)) {
			if let cgImage = imageRepresentation.cgImage {
				self.bitsPerPixels = cgImage.bitsPerPixel
				self.bitmapInfo = cgImage.bitmapInfo
			}
		}
	}

	func updateSize(width: Int, height: Int) {
		guard self.width != width || self.height != height else { return }

		#if DEBUG
			if width == 0 || height == 0 {
				self.logger.debug("View size is zero, skipping frame capture.")
			}
		#endif

		self.pixelData.withLock {
			self.width = width
			self.height = height
			self.sizeChanged = true
			self.hasChanges = true
			$0 = Data(count: width * height * 4)
		}
	}

	@MainActor
	public func updateFromView() -> (imageRepresentation: NSBitmapImageRep?, sizeChanged: Bool) {
		let bounds = sourceView.bounds
		let newWidth = Int(bounds.width)
		let newHeight = Int(bounds.height)

		if newWidth == 0 || newHeight == 0 {
			#if DEBUG
				self.logger.debug("View size is zero, skipping frame capture.")
			#endif
			return (nil, false)
		}

		guard let imageRepresentation = sourceView.imageRepresentationSync(in: bounds) else {
			return (nil, false)
		}

		// Check if size has changed
		updateSize(width: newWidth, height: newHeight)

		return (imageRepresentation, self.hasChanges)
	}

	func convertBitmapToPixelData(bitmap: NSBitmapImageRep) -> Bool {
		var changed = self.sizeChanged

		guard let cgImage = bitmap.cgImage else {
			return false
		}

		if cgImage.bitmapInfo != self.bitmapInfo || cgImage.width != self.width || cgImage.height != self.height {
			changed = true
		}

		self.bitsPerPixels = cgImage.bitsPerPixel
		self.bitmapInfo = cgImage.bitmapInfo

		if let provider = cgImage.dataProvider, let imageSource = provider.data as Data? {
			var pixelData = Data(count: width * height * 4)

			if changed {
				imageSource.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
					pixelData.withUnsafeMutableBytes { (dstRaw: UnsafeMutableRawBufferPointer) in
						guard let sp = srcRaw.bindMemory(to: UInt8.self).baseAddress, let dp = dstRaw.bindMemory(to: UInt8.self).baseAddress else { return }
						let rowWidth = self.width * 4

						for row in 0..<height {
							var srcPtr = sp.advanced(by: cgImage.bytesPerRow * row)
							var dstPtr = dp.advanced(by: rowWidth * row)

							var i = 0

							while i < rowWidth {
								let r = srcPtr[0]
								let g = srcPtr[1]
								let b = srcPtr[2]
								let a = srcPtr[3]

								dstPtr[0] = b  // B
								dstPtr[1] = g  // G
								dstPtr[2] = r  // R
								dstPtr[3] = a  // A

								srcPtr = srcPtr.advanced(by: 4)
								dstPtr = dstPtr.advanced(by: 4)

								i += 4
							}
						}
					}
				}
			} else {
				self.pixelData.withLock { $0 }.withUnsafeBytes { originalPixelsPtr in
					var originalPixelPtr = originalPixelsPtr.baseAddress!.assumingMemoryBound(to: UInt32.self)

					imageSource.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
						pixelData.withUnsafeMutableBytes { (dstRaw: UnsafeMutableRawBufferPointer) in
							guard let sp = srcRaw.bindMemory(to: UInt8.self).baseAddress, let dp = dstRaw.bindMemory(to: UInt8.self).baseAddress else { return }
							let rowWidth = self.width * 4

							for row in 0..<height {
								var srcPtr = sp.advanced(by: cgImage.bytesPerRow * row)
								var dstPtr = dp.advanced(by: rowWidth * row)

								var i = 0

								while i < rowWidth {
									let r = srcPtr[0]
									let g = srcPtr[1]
									let b = srcPtr[2]
									let a = srcPtr[3]

									dstPtr[0] = b  // B
									dstPtr[1] = g  // G
									dstPtr[2] = r  // R
									dstPtr[3] = a  // A

									dstPtr.withMemoryRebound(to: UInt32.self, capacity: 1) { ptr in
										if ptr.pointee != originalPixelPtr.pointee {
											changed = true
										}
									}

									originalPixelPtr = originalPixelPtr.advanced(by: 1)
									srcPtr = srcPtr.advanced(by: 4)
									dstPtr = dstPtr.advanced(by: 4)

									i += 4
								}
							}
						}
					}
				}
			}

			self.pixelData.withLock {
				self.hasChanges = true
				$0 = pixelData
			}
		}

		return changed
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

		if bitmapInfo.byteOrder == .orderDefault {
			pixelFormat.depth = 32
			pixelFormat.redMax = 255
			pixelFormat.redMax = 255
			pixelFormat.blueMax = 255
			pixelFormat.bigEndianFlag = VNCServer.littleEndian ? 0 : 1

			if bitmapInfo.alpha.isLast {
				pixelFormat.redShift = 16
				pixelFormat.greenShift = 8
				pixelFormat.blueShift = 0
			} else if bitmapInfo.alpha.isFirst {
				pixelFormat.redShift = 24
				pixelFormat.greenShift = 16
				pixelFormat.blueShift = 8
			}
		} else if bitmapInfo.byteOrder == .order32Little {
			pixelFormat.depth = 32
			pixelFormat.redMax = 255
			pixelFormat.redMax = 255
			pixelFormat.blueMax = 255
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
		} else if bitmapInfo.byteOrder == .order32Big {
			pixelFormat.depth = 32
			pixelFormat.redMax = 255
			pixelFormat.redMax = 255
			pixelFormat.blueMax = 255
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
			pixelFormat.redMax = 16
			pixelFormat.redMax = 16
			pixelFormat.blueMax = 16

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
			pixelFormat.redMax = 16
			pixelFormat.redMax = 16
			pixelFormat.blueMax = 16
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

	func setCurrentState(width: Int, height: Int, pixelData: Data, hasChanges: Bool, sizeChanged: Bool) {
		self.pixelData.withLock {
			self.width = width
			self.height = height
			self.hasChanges = hasChanges
			self.sizeChanged = sizeChanged
			$0 = pixelData
		}
	}

	@MainActor
	func getCurrentState() -> (width: Int, height: Int, data: Data, hasChanges: Bool, sizeChanged: Bool) {
		return (width: width, height: height, data: pixelData.withLock { $0 }, hasChanges: hasChanges, sizeChanged: sizeChanged)
	}
}
