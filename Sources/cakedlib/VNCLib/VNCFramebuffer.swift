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
	struct VNCFramebufferTile: Equatable {
		let bounds: CGRect
		let pixels: Data
		let sha256: SHA256.Digest?

		static func == (lhs: Self, rhs: Self) -> Bool {
			guard lhs.bounds == rhs.bounds else {
				return false
			}

			return lhs.sha256 == rhs.sha256
		}

		init(bounds: CGRect, pixels: Data, sha256: SHA256.Digest?) {
			self.bounds = bounds
			self.pixels = pixels
			self.sha256 = sha256
		}

		init(bounds: CGRect, pixels: Data) {
			self.init(bounds: bounds, pixels: pixels, sha256: SHA256.hash(data: pixels))
		}
	}

	public internal(set) var width: Int
	public internal(set) var height: Int
	internal let pixelData: Mutex<Data>
	internal var tiles: [VNCFramebufferTile]
	internal weak var sourceView: NSView!
	private let updateQueue = DispatchQueue(label: "vnc.framebuffer.update")
	internal var pixelFormat = VNCPixelFormat()
	private var bitmapInfo: CGBitmapInfo? = nil
	private var bitsPerPixels: Int = 0
	private let logger = Logger("VNCFramebuffer")
	private var timer: Timer? = nil

	public init(view: NSView) {
		var cgImage: CGImage? = nil

		self.sourceView = view
		self.width = Int(view.bounds.width)
		self.height = Int(view.bounds.height)

		if let producer = self.sourceView as? VNCFrameBufferProducer, let img = producer.cgImage {
			cgImage = img
		} else if let imageRepresentation = view.imageRepresentationSync(in: view.bounds) {
			cgImage = imageRepresentation.cgImage
		}

		if let cgImage = cgImage {
			self.bitsPerPixels = cgImage.bitsPerPixel
			self.bitmapInfo = cgImage.bitmapInfo
			
			self.pixelFormat = VNCPixelFormat(bitmapInfo: cgImage.bitmapInfo)
			self.pixelData = .init(Self.convertImageToPixels(cgImage: cgImage))  // RGBA
			self.tiles = Self.buildTiles(from: cgImage)  // RGBA
		} else {
			let pixels = Data(count: width * height * 4)

			self.pixelData = .init(pixels)  // RGBA
			self.tiles = Self.buildTiles(pixels, width: width, height: height, bytesPerRow: 4 * width, bytesPerPixel: 4)  // RGBA
		}
	}

	private func updateSize(width: Int, height: Int) -> Bool {
		guard self.width != width || self.height != height else { return false }

		#if DEBUG
			if width == 0 || height == 0 {
				self.logger.debug("View size is zero, skipping frame capture.")
			}
		#endif

		self.width = width
		self.height = height

		return true
	}

	@MainActor
	func updateFromView() -> (imageRepresentation: NSBitmapImageRep?, sizeChanged: Bool) {
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

	static func convertImageToPixels(cgImage: CGImage) -> Data {
		let bytesPerRow = cgImage.width * (cgImage.bitsPerPixel / 8)
		let bufferSize = bytesPerRow * cgImage.height
		var pixelData = Data(count: bufferSize)

		if let provider = cgImage.dataProvider, var imageSource = provider.data as? Data {
			imageSource.withUnsafeMutableBytes { srcRaw in
				pixelData.withUnsafeMutableBytes { dstRaw in
					guard var sp = srcRaw.bindMemory(to: UInt8.self).baseAddress, var dp = dstRaw.bindMemory(to: UInt8.self).baseAddress else {
						return
					}

					if cgImage.bytesPerRow == bytesPerRow {
						dp.update(from: sp, count: bufferSize)
					} else {
						for _ in 0..<cgImage.height {
							dp.update(from: sp, count: bytesPerRow)
							
							dp = dp.advanced(by: bytesPerRow)
							sp = sp.advanced(by: cgImage.bytesPerRow)
						}
					}
				}
			}
		}

		return pixelData
	}

	func convertImageToTiles(cgImage: CGImage) -> (tiles: [VNCFramebufferTile], newSize: Bool) {
		var sizeChanged: Bool = false

		return self.pixelData.withLock {
			let pixelData = Self.convertImageToPixels(cgImage: cgImage)
			let oldTiles = self.tiles

			self.bitsPerPixels = cgImage.bitsPerPixel
			self.bitmapInfo = cgImage.bitmapInfo
			self.pixelFormat = VNCPixelFormat(bitmapInfo: cgImage.bitmapInfo)
			self.tiles = Self.buildTiles(from: cgImage)

			$0 = pixelData

			sizeChanged = updateSize(width: cgImage.width, height: cgImage.height)

			if sizeChanged || oldTiles.count != self.tiles.count || self.tiles.isEmpty {
				return ([VNCFramebufferTile(bounds: .init(x: 0, y: 0, width: cgImage.width, height: cgImage.height), pixels: pixelData, sha256: nil)], sizeChanged)
			} else {
				var index = 0

				return (self.tiles.compactMap { tile in
					defer { index += 1 }

					if tile != oldTiles[index] {
						return tile
					}
					
					return nil
				}, sizeChanged)
			}
		}
	}

 
	/// Split the current framebuffer pixel data into 64x64 RGBA tiles.
    /// - Returns: Array of Data, each tile is 64x64 pixels in RGBA (4 bytes per pixel). Edge tiles are smaller if width/height are not multiples of 64.
	static func buildTiles(_ pixelData: Data, tileSize: Int = 64, width: Int, height: Int, bytesPerRow: Int, bytesPerPixel: Int) -> [VNCFramebufferTile] {
		let srcTileStep = bytesPerRow * tileSize
		let srcTileRowSize = bytesPerPixel * tileSize
		let tilesAcross = (width + tileSize - 1) / tileSize
		let tilesDown = (height + tileSize - 1) / tileSize
		var tiles: [VNCFramebufferTile] = []

		tiles.reserveCapacity(tilesAcross * tilesDown)

		pixelData.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
			guard let sp = srcRaw.bindMemory(to: UInt8.self).baseAddress else { return }

			var srcRowPtr = sp

			for tileY in 0..<tilesDown {
				let startY = tileY * tileSize
				let copyHeight = min(tileSize, height - startY)
				var startX = 0
				var tileSrcRowPtr = srcRowPtr

				for tileX in 0..<tilesAcross {
					let copyWidth = min(tileSize, width - startX)
					let rowSize = copyWidth * bytesPerPixel
					var srcRowPtr = tileSrcRowPtr

					if copyWidth > 0 && copyHeight > 0 {
						var tile = Data(count: rowSize * copyHeight)
						
						tile.withUnsafeMutableBytes { (dstRaw: UnsafeMutableRawBufferPointer) in
							guard var dstRowPtr = dstRaw.bindMemory(to: UInt8.self).baseAddress else { return }
										
							// Each line in tile
							for _ in 0..<copyHeight {
								dstRowPtr.update(from: srcRowPtr, count: rowSize)
								
								dstRowPtr = dstRowPtr.advanced(by: rowSize)
								srcRowPtr = srcRowPtr.advanced(by: bytesPerRow)
							}
						}
						
						tiles.append(.init(bounds: CGRect(x: startX, y: startY, width: copyWidth, height: copyHeight), pixels: tile))
					}

					// Next tile
					startX += tileSize
					tileSrcRowPtr = tileSrcRowPtr.advanced(by: srcTileRowSize) // tile * pixel size in byte
				}

				// Next band
				srcRowPtr = srcRowPtr.advanced(by: srcTileStep) // bytesPerRow * tileSize
			}
		}

		return tiles
    }

	/// Split a CGImage into 64x64 RGBA tiles using its provider data.
    /// - Returns: Array of Data, each tile is 64x64 pixels in RGBA (4 bytes per pixel). Edge tiles are smaller if width/height are not multiples of 64.
    static func buildTiles(from cgImage: CGImage, tileSize: Int = 64) -> [VNCFramebufferTile] {
        guard let provider = cgImage.dataProvider, let imageSource = provider.data as Data? else {
            return []
        }

		return Self.buildTiles(imageSource, tileSize: tileSize, width: cgImage.width, height: cgImage.height, bytesPerRow: cgImage.bytesPerRow, bytesPerPixel: cgImage.bitsPerPixel/8)
    }

	func convertToClient(_ pixelData: Data, clientFormat: VNCPixelFormat?) -> Data {
		if let clientFormat = clientFormat {
			return clientFormat.transform(pixelData)
		}

		return self.pixelFormat.transform(pixelData)
	}
}

// MARK: - VNCFrameBufferProducer
extension VNCFramebuffer: VNCFrameBufferProducer {
	public var checkIfImageIsChanged: Bool {
		true
	}

	public var bitmapInfos: CGBitmapInfo {
		guard let bitmapInof = self.cgImage?.bitmapInfo else {
			return .byteOrderDefault
		}

		return bitmapInof
	}
	
	public var cgImage: CGImage? {
		self.sourceView.image()?.cgImage
	}
	
	public func startFramebufferUpdate(continuation: AsyncStream<CGImage>.Continuation) {
		let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
			guard let self = self else {
				return
			}

			let bounds = self.sourceView.bounds

			guard bounds.width != 0 && bounds.height != 0 else {
				#if DEBUG
					self.logger.debug("View size is zero, skipping frame capture.")
				#endif
				return
			}

			guard let cgImage = self.cgImage else {
				guard let imageRepresentation = self.sourceView.imageRepresentationSync(in: bounds) else {
					return
				}

				if let cgImage = imageRepresentation.cgImage {
					continuation.yield(cgImage)
				}

				return
			}

			continuation.yield(cgImage)
		}

		RunLoop.main.add(timer, forMode: .common)

		self.timer = timer
	}
	
	public func stopFramebufferUpdate() {
		self.timer?.invalidate()
		self.timer = nil
	}
}

