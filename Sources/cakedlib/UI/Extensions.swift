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

extension CALayer {
	func renderIntoImage() -> NSImage? {
        // Ensure we have a valid, non-zero size to render
        let width = Int(ceil(self.bounds.width))
        let height = Int(ceil(self.bounds.height))
        guard width > 0, height > 0 else { return nil }

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
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }

        // Clear and flip the context to AppKit coordinates
        ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
        //ctx.translateBy(x: 0, y: CGFloat(height))
        //ctx.scaleBy(x: 1, y: -1)

        // Render the layer hierarchy into the context
        self.render(in: ctx)

        // Create CGImage and wrap in NSImage
        guard let cgImage = ctx.makeImage() else { return nil }

		return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
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
  attachments: \(self.allAttachments())
"""
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
				srcPtr = srcPtr.advanced(by: self.bytesPerRow)
				dstPtr = dstPtr.advanced(by: bytesPerRow)
			}
		}

		return pixels
	}

	public var image: NSImage? {
		return image(in: .init(origin: .zero, size: .init(width: self.width, height: self.height)))
	}

	public func image(in bounds: NSRect) -> NSImage? {
		// Create a CIImage backed by the IOSurface
		let ciImage = CIImage(ioSurface: self)

		// Create a CIContext and generate a CGImage
		let context = CIContext(options: nil)

		// Determine the rect we want to capture: intersect requested bounds with the image extent
		let imageExtent = ciImage.extent
		let requestedRect = CGRect(origin: bounds.origin, size: bounds.size).integral
		let drawRect = requestedRect.isEmpty ? imageExtent : imageExtent.intersection(requestedRect)
		guard !drawRect.isEmpty else { return nil }

		guard let cgImage = context.createCGImage(ciImage, from: drawRect) else {
			return nil
		}

		// Wrap the CGImage in an NSImage matching the drawn rect size
		return NSImage(cgImage: cgImage, size: NSSize(width: drawRect.width, height: drawRect.height))
	}
}

