import AppKit
import CryptoKit
import Foundation
import Synchronization
import CakeAgentLib

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
	internal weak var sourceView: NSView!
	internal let updateQueue = DispatchQueue(label: "vnc.framebuffer.update")
	internal var pixelFormat = VNCPixelFormat()
	internal var bitmapInfo: CGBitmapInfo? = nil
	internal var bitsPerPixels: Int = 0
	internal let logger = Logger("VNCFramebuffer")

	public init(view: NSView) {
		var cgImage: CGImage? = nil

		self.sourceView = view
		self.width = Int(view.bounds.width)
		self.height = Int(view.bounds.height)
		self.pixelData = .init(Data(count: width * height * 4))  // RGBA

		if let producer = self.sourceView as? VNCFrameBufferProducer, let img = producer.cgImage {
			cgImage = img
		} else if let imageRepresentation = view.imageRepresentationSync(in: NSRect(x: 0, y: 0, width: 4, height: 4)) {
			cgImage = imageRepresentation.cgImage
		}

		if let cgImage = cgImage {
			self.bitsPerPixels = cgImage.bitsPerPixel
			self.bitmapInfo = cgImage.bitmapInfo
			
			self.pixelFormat = VNCPixelFormat(bitmapInfo: cgImage.bitmapInfo)
		}
	}

	public func updateSize(width: Int, height: Int) -> Bool {
		guard self.width != width || self.height != height else { return false }

		#if DEBUG
			if width == 0 || height == 0 {
				self.logger.debug("View size is zero, skipping frame capture.")
			}
		#endif

		self.pixelData.withLock {
			self.width = width
			self.height = height
			$0 = Data(count: width * height * 4)
		}

		return true
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

		return (imageRepresentation, updateSize(width: newWidth, height: newHeight))
	}

	func convertImageToPixelData(cgImage: CGImage) {
		let bytesPerRow = width * 4
		let bufferSize = bytesPerRow * height
		var pixelData = Data(count: bufferSize)

		self.bitsPerPixels = cgImage.bitsPerPixel
		self.bitmapInfo = cgImage.bitmapInfo
		self.pixelFormat = VNCPixelFormat(bitmapInfo: cgImage.bitmapInfo)

		if let provider = cgImage.dataProvider, let imageSource = provider.data as Data? {
			imageSource.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
				pixelData.withUnsafeMutableBytes { (dstRaw: UnsafeMutableRawBufferPointer) in
					guard var sp = srcRaw.bindMemory(to: UInt8.self).baseAddress, var dp = dstRaw.bindMemory(to: UInt8.self).baseAddress else {
						return
					}

					if self.bitmapInfo?.byteOrder == .order32Big {
						for _ in 0..<height {
							var srcPtr = dp
							var dstPtr = sp

							for i in 0..<self.width {
								dstPtr[0] = srcPtr[2]  // B
								dstPtr[1] = srcPtr[1]  // G
								dstPtr[2] = srcPtr[0]  // R
								dstPtr[3] = srcPtr[3]  // A

								srcPtr = srcPtr.advanced(by: 4)
								dstPtr = dstPtr.advanced(by: 4)
							}

							dp = dp.advanced(by: bytesPerRow)
							sp = sp.advanced(by: cgImage.bytesPerRow)
						}
					} else {
						if cgImage.bytesPerRow == bytesPerRow {
							dp.update(from: sp, count: bufferSize)
						} else {
							for _ in 0..<height {
								dp.update(from: sp, count: bytesPerRow)
								
								dp = dp.advanced(by: bytesPerRow)
								sp = sp.advanced(by: cgImage.bytesPerRow)
							}
						}
					}
				}
			}
		}

		self.pixelData.withLock {
			$0 = pixelData
		}
	}

	func convertBitmapToPixelData(bitmap: NSBitmapImageRep) -> Bool {
		var changed = false

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
				self.pixelData.withLock {
					$0.withUnsafeBytes { originalPixelsPtr in
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
			}

			self.pixelData.withLock {
				$0 = pixelData
			}
		}

		return changed
	}

	func convertToClient(_ pixelData: Data, clientFormat: VNCPixelFormat?) -> Data {
		if let clientFormat = clientFormat {
			return clientFormat.transform(pixelData)
		}

		return self.pixelFormat.transform(pixelData)
	}
}
