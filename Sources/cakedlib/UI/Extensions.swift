//
//  Extensions.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/01/2026.
//
import AppKit
import Foundation
import QuartzCore
import GRPCLib

class IOSurfaceNSBitmapImageRep: NSBitmapImageRep {
	let surface: UnsafeMutablePointer<UInt8>

	deinit {
		surface.deallocate()
	}

	init?(ioSurface: IOSurface) {
		let bytesPerRow = ioSurface.bytesPerRow
		let data = UnsafeMutablePointer<UInt8>.allocate(capacity: ioSurface.allocationSize)
		var planes: [UnsafeMutablePointer<UInt8>?] = [data]
		var srcPtr = ioSurface.baseAddress.bindMemory(to: UInt8.self, capacity: ioSurface.allocationSize)
		var dstPtr = data
		
		self.surface = data

		for _ in 0..<ioSurface.height {
			dstPtr.update(from: srcPtr, count: bytesPerRow)
			var count = 0

			while count < bytesPerRow {
				dstPtr[count + 3] = 255
				count += 4
			}

			srcPtr = srcPtr.advanced(by: bytesPerRow)
			dstPtr = dstPtr.advanced(by: bytesPerRow)
		}

		super.init(bitmapDataPlanes: &planes,
					pixelsWide: ioSurface.width,
					pixelsHigh: ioSurface.height,
					bitsPerSample: 8,
					samplesPerPixel: ioSurface.bytesPerElement,
					hasAlpha: true,
					isPlanar: false,
					colorSpaceName: .deviceRGB,
					bitmapFormat: .thirtyTwoBitBigEndian,
					bytesPerRow: ioSurface.bytesPerRow,
					bitsPerPixel: ioSurface.bytesPerElement * 8)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}


extension CALayer {
	func renderIntoImage() -> CGImage? {
        // Ensure we have a valid, non-zero size to render
        let width = Int(ceil(self.bounds.width))
        let height = Int(ceil(self.bounds.height))

		guard width > 0, height > 0 else {
			return nil
		}

        // Create an RGBA8 bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4

		// Align bytesPerRow to a multiple of 4 for safe bitmap alignment
        let rawBytesPerRow = width * bytesPerPixel
        let bytesPerRow = (rawBytesPerRow + 3) & ~3
        let dataSize = height * bytesPerRow
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: dataSize)

		defer { data.deallocate() }

        guard let ctx = CGContext(data: data,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }

        // Clear and flip the context to AppKit coordinates
        ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
        //ctx.translateBy(x: 0, y: CGFloat(height))
        //ctx.scaleBy(x: 1, y: -1)

        // Render the layer hierarchy into the context
        self.render(in: ctx)

        // Create CGImage and wrap in NSImage
        return ctx.makeImage()
	}
}

extension OSType {
	var string: String {
	    // OSType is a FourCharCode (UInt32). Interpret as four ASCII bytes in big-endian order.
	    let value = UInt32(self)
	    let bytes: [UInt8] = [
	        UInt8((value >> 24) & 0xFF),
	        UInt8((value >> 16) & 0xFF),
	        UInt8((value >> 8) & 0xFF),
	        UInt8(value & 0xFF)
	    ]
	    // Some OSType values may contain non-printable bytes; fall back to hex if decoding fails.
	    if let str = String(bytes: bytes, encoding: .macOSRoman) ?? String(bytes: bytes, encoding: .ascii) {
	        return str
	    } else {
	        return String(format: "0x%08X", value)
	    }
	}
}

extension IOSurface {
	public var bitmapRepresentation: NSBitmapImageRep? {
		IOSurfaceNSBitmapImageRep(ioSurface: self)
	}

	#if false
	open override var description: String {
		return """
\(self.className): \(self.width)x\(self.height)
  allocationSize: \(self.allocationSize)
  allowsPixelSizeCasting: \(self.allowsPixelSizeCasting)
  bytesPerRow: \(self.bytesPerRow)
  bytesPerElement: \(self.bytesPerElement)
  elementHeight: \(self.elementHeight)
  elementWidth: \(self.elementWidth)
  format: \(self.pixelFormat.string)
  inUse: \(self.isInUse)
  localUseCount: \(self.localUseCount)
  planeCount: \(self.planeCount)
  seed: \(self.seed)
  surfaceID: \(self.surfaceID)
  IOSurfaceGetSubsampling: \(IOSurfaceGetSubsampling(self))
  IOSurfaceGetBitDepthOfComponentOfPlane[0]: \(IOSurfaceGetBitDepthOfComponentOfPlane(self, 0, 0))
  IOSurfaceGetBitDepthOfComponentOfPlane[1]: \(IOSurfaceGetBitDepthOfComponentOfPlane(self, 0, 1))
  IOSurfaceGetBitDepthOfComponentOfPlane[2]: \(IOSurfaceGetBitDepthOfComponentOfPlane(self, 0, 2))
  IOSurfaceGetBitOffsetOfComponentOfPlane[0]: \(IOSurfaceGetBitOffsetOfComponentOfPlane(self, 0, 0))
  IOSurfaceGetBitOffsetOfComponentOfPlane[1]: \(IOSurfaceGetBitOffsetOfComponentOfPlane(self, 0, 1))
  IOSurfaceGetBitOffsetOfComponentOfPlane[2]: \(IOSurfaceGetBitOffsetOfComponentOfPlane(self, 0, 2))
  IOSurfaceGetTypeOfComponentOfPlane[0]: \(IOSurfaceGetTypeOfComponentOfPlane(self, 0, 0))
  IOSurfaceGetTypeOfComponentOfPlane[1]: \(IOSurfaceGetTypeOfComponentOfPlane(self, 0, 1))
  IOSurfaceGetTypeOfComponentOfPlane[2]: \(IOSurfaceGetTypeOfComponentOfPlane(self, 0, 2))
  IOSurfaceComponentRange[0]: \(IOSurfaceGetRangeOfComponentOfPlane(self, 0, 0))
  IOSurfaceComponentRange[1]: \(IOSurfaceGetRangeOfComponentOfPlane(self, 0, 1))
  IOSurfaceComponentRange[2]: \(IOSurfaceGetRangeOfComponentOfPlane(self, 0, 2))

  attachments: \(self.allAttachments())
"""
	}
	#endif

	public var cgImage: CGImage? {
		guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
			return nil
		}

		guard let provider = CGDataProvider(data: Data(bytes: self.baseAddress, count: self.allocationSize) as CFData) else {
			return nil
		}

		let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue))

		return CGImage(
			width: self.width,
			height: self.height,
			bitsPerComponent: 8,
			bitsPerPixel: self.bytesPerElement * 8,
			bytesPerRow: self.bytesPerRow,
			space: colorSpace,
			bitmapInfo: bitmapInfo,
			provider: provider,
			decode: nil,
			shouldInterpolate: true,
			intent: .defaultIntent
		)
	}

	func write(path: String) {
		let data = Data(bytes: self.baseAddress, count: self.allocationSize)

		try? data.write(to: URL(fileURLWithPath: path.expandingTildeInPath), options: [.atomic])
	}

	var contents: Data {
		let bytesPerRow = Int(self.width) * self.bytesPerElement
		var pixels = Data(count: Int(self.height) * bytesPerRow)

		pixels.withUnsafeMutableBytes { ptr in
			guard var dstPtr = ptr.bindMemory(to: UInt8.self).baseAddress else {
				return
			}

			var srcPtr = self.baseAddress.bindMemory(to: UInt8.self, capacity: Int(self.height) * self.bytesPerRow)

			for _ in 0..<Int(self.height) {
				dstPtr.update(from: srcPtr, count: bytesPerRow)

				var count = 0

				while count < bytesPerRow {
					dstPtr[count + 3] = 255
					count += 4
				}

				srcPtr = srcPtr.advanced(by: self.bytesPerRow)
				dstPtr = dstPtr.advanced(by: bytesPerRow)
			}
		}

		return pixels
	}

	public var image: NSImage? {
		guard let cgImage = self.cgImage else {
			return nil
		}

		return NSImage(cgImage: cgImage, size: .init(width: cgImage.width, height: cgImage.height))
	}

	public func image(in bounds: NSRect) -> NSImage? {
		guard let cgImage = self.cgImage else {
			return nil
		}

		guard let croppedCgImage = cgImage.cropping(to: bounds) else {
			return nil
		}

		return NSImage(cgImage: croppedCgImage, size: .init(width: croppedCgImage.width, height: croppedCgImage.height))
	}
}
