import CakeAgentLib
import Dynamic
//
//  VNCVZVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 19/01/2026.
//
import Foundation
import ObjectiveC.runtime
import QuartzCore
import Synchronization
import Virtualization

@objc protocol VZFramebufferObserver {
	@objc func framebuffer(_ framebuffer: NSObject, didUpdateCursor cursor: UnsafePointer<UInt8>?)
	@objc func framebuffer(_ framebuffer: NSObject, didUpdateFrame frame: UnsafePointer<UInt8>?)
	@objc func framebuffer(_ framebuffer: NSObject, didUpdateGraphicsOrientation orientation: Int64)
	@objc func framebufferDidUpdateColorSpace(_ framebuffer: NSObject)
}

extension NSView {
	@objc public var cursor: NSCursor? {
		return nil
	}

	func swizzleFramebufferObserver() {
		let protocols = self.protocolNames

		// Check if `self` conforms to the private framebuffer observer protocol using a safe cast
		if protocols.first(where: { $0 == "_VZFramebufferObserver" }) != nil {
			// Only attempt to swizzle if the selectors exist on this instance
			let hasFrameSel = self.responds(to: #selector(VZFramebufferObserver.framebuffer(_:didUpdateFrame:)))
			let hasUpdateCursorSel = self.responds(to: #selector(VZFramebufferObserver.framebuffer(_:didUpdateCursor:)))

			if hasFrameSel {
				self.swizzleMethod(
					originalSelector: #selector(VZFramebufferObserver.framebuffer(_:didUpdateFrame:)),
					swizzledSelector: #selector(swizzled_framebuffer(_:didUpdateFrame:)))
			}

			if hasUpdateCursorSel {
				self.swizzleMethod(
					originalSelector: #selector(VZFramebufferObserver.framebuffer(_:didUpdateCursor:)),
					swizzledSelector: #selector(swizzled_framebuffer(_:didUpdateCursor:)))
			}

			VNCVirtualMachineView.swizzled = true
		}
	}

	@objc func swizzled_framebuffer(_ framebuffer: NSObject, didUpdateCursor cursor: UnsafePointer<UInt8>?) {
		self.swizzled_framebuffer(framebuffer, didUpdateCursor: cursor)

		if let observer = self.superview as? VNCFramebufferObserver {
			observer.didUpdateCursor(self)
		}
	}

	@objc func swizzled_framebuffer(_ framebuffer: NSObject, didUpdateFrame frame: UnsafePointer<UInt8>?) {
		self.swizzled_framebuffer(framebuffer, didUpdateFrame: frame)

		if let observer = self.superview as? VNCFramebufferObserver {
			observer.didUpdateFrame(self)
		}
	}
}

extension VZVirtualMachineView {
	public var graphicsDisplay: VZGraphicsDisplay? {
		guard let prop = class_getProperty(type(of: self), "_graphicsDisplay") else {
			return nil
		}

		let cname = property_getName(prop)  // UnsafePointer<CChar>
		let name = String(cString: cname)

		// Often, the backing ivar is "_\(name)"
		guard let ivar = class_getInstanceVariable(type(of: self), name) else {
			return nil
		}

		guard let value = object_getIvar(self, ivar) as? VZGraphicsDisplay else {
			return nil
		}

		return value
	}

	public var framebuffer: NSObject? {
		guard let framebufferView = self.framebufferView else {
			return nil
		}

		guard let field = class_getInstanceVariable(type(of: framebufferView), "_framebuffer") else {
			return nil
		}

		guard let value = object_getIvar(framebufferView, field) as? NSObject else {
			return nil
		}

		return value
	}

	public var framebufferView: NSView? {
		guard let field = class_getInstanceVariable(type(of: self), "_framebufferView") else {
			return nil
		}

		guard let value = object_getIvar(self, field) as? NSView else {
			return nil
		}

		return value
	}

	public var guestIsUsingHostCursor: Bool {
		get {
			guard let field = class_getInstanceVariable(type(of: self), "_guestIsUsingHostCursor") else {
				return false
			}

			guard let value = object_getIvar(self, field) as? Bool else {
				return false
			}

			return value
		}
		set {
			guard let field = class_getInstanceVariable(type(of: self), "_guestIsUsingHostCursor") else {
				return
			}

			object_setIvar(self, field, newValue)
		}
	}

	public var showsHostCursor: Bool {
		get {
			guard let field = class_getInstanceVariable(type(of: self), "_showsHostCursor") else {
				return false
			}

			guard let value = object_getIvar(self, field) as? Bool else {
				return false
			}

			return value
		}
		set {
			guard let field = class_getInstanceVariable(type(of: self), "_showsHostCursor") else {
				return
			}

			object_setIvar(self, field, newValue)

			Dynamic(self.framebufferView).showsCursor = newValue
		}
	}

	override public var cursor: NSCursor? {
		return Dynamic(self.framebufferView).cursor
	}

	func surface() -> IOSurface? {
		guard let surface = self.framebufferView?.layer?.contents as? IOSurface else {
			return nil
		}

		return surface
	}

	func contents() -> Data? {
		guard let surface = self.framebufferView?.layer?.contents as? IOSurface else {
			return nil
		}

		return surface.contents
	}

	public func render(in bounds: NSRect) -> CGImage? {
		var renderLayer: CALayer

		guard let layer = self.layer else {
			return nil
		}

		guard let surface = self.surface() else {
			return nil
		}

		//guard let presented  = layer.presentation() else {
		//	return nil
		//}
		renderLayer = CALayer(layer: layer)
		//renderLayer = presented
		renderLayer.drawsAsynchronously = true
		renderLayer.isOpaque = true
		renderLayer.masksToBounds = false
		renderLayer.allowsEdgeAntialiasing = false
		renderLayer.backgroundColor = .clear

		renderLayer.contentsScale = 1
		renderLayer.contentsGravity = .center
		renderLayer.contentsFormat = .RGBA8Uint
		renderLayer.bounds = layer.bounds
		renderLayer.contents = surface.cgImage

		guard var cgImage = renderLayer.renderIntoImage() else {
			return nil
		}

		if self.bounds != bounds {
			guard let croppedImage = cgImage.cropping(to: bounds) else {
				return nil
			}

			cgImage = croppedImage
		}

		return cgImage
	}

	override public func image() -> NSImage? {
		self.image(in: self.bounds)
	}

	override public func image(in bounds: NSRect) -> NSImage? {
		guard let cgImage = self.render(in: bounds) else {
			return nil
		}

		return NSImage(cgImage: cgImage, size: .init(width: cgImage.width, height: cgImage.height))
	}
}

@objc protocol VNCFramebufferObserver {
	@objc func didUpdateCursor(_ framebufferView: NSView)
	@objc func didUpdateFrame(_ framebufferView: NSView)
}

open class VNCFramebufferLayer: CALayer {
	open override var contents: Any? {
		get {
			super.contents
		}
		set {
			if let surface = newValue as? IOSurface {
				super.contents = surface.cgImage
			} else {
				super.contents = newValue
			}
		}
	}
}

open class VNCVirtualMachineView: VZVirtualMachineView {
	static var swizzled = false

	private let continuation: Mutex<AsyncStream<VNCFrameUpdateState>.Continuation?> = .init(nil)

	public var suppressFrameUpdates: Bool {
		get {
			guard let view = self.framebufferView else {
				return false
			}

			return Dynamic(view).suppressFrameUpdates.asBool ?? false
		}
		set {
			if let view = self.framebufferView {
				Dynamic(view).suppressFrameUpdates = newValue
			}
		}
	}

	public override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)

		if let framebufferView = self.framebufferView {
			if VNCVirtualMachineView.swizzled == false {
				framebufferView.swizzleFramebufferObserver()
			}
		}
	}

	public required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

#if DEBUGEVENT
	extension VNCVirtualMachineView {
		public override func mouseDown(with event: NSEvent) {
			Logger(self).debug("mouseDown: \(event.dumpEvent)")

			super.mouseDown(with: event)
		}

		public override func mouseDragged(with event: NSEvent) {
			Logger(self).debug("mouseDragged: \(event.dumpEvent)")

			super.mouseDragged(with: event)
		}

		public override func mouseUp(with event: NSEvent) {
			Logger(self).debug("mouseUp: \(event.dumpEvent)")

			super.mouseUp(with: event)
		}

		public override func keyDown(with event: NSEvent) {
			Logger(self).debug("keyDown: \(event.dumpEvent)")

			super.keyDown(with: event)
		}

		public override func flagsChanged(with event: NSEvent) {
			Logger(self).debug("flagsChanged: \(event.dumpEvent)")

			super.flagsChanged(with: event)
		}

		public override func scrollWheel(with event: NSEvent) {
			Logger(self).debug("scrollWheel: \(event.dumpEvent)")

			super.scrollWheel(with: event)
		}
	}
#endif

extension VNCVirtualMachineView: VNCFrameBufferProducer {
	public var checkIfImageIsChanged: Bool {
		false
	}

	public var cgImage: CGImage? {
		return self.render(in: self.bounds)
	}

	public var bitmapInfos: CGBitmapInfo {
		CGBitmapInfo(alpha: CGImageAlphaInfo.noneSkipFirst, component: .integer, byteOrder: .order32Little)
	}

	public func startFramebufferUpdate(continuation: AsyncStream<VNCFrameUpdateState>.Continuation) {
		self.continuation.withLock {
			$0 = continuation
		}
	}

	public func stopFramebufferUpdate() {
		self.continuation.withLock {
			$0 = nil
		}
	}
}

extension VNCVirtualMachineView: VNCFramebufferObserver {
	open func didUpdateCursor(_ framebufferView: NSView) {
		self.continuation.withLock {
			guard let continuation = $0 else {
				return
			}

			guard let cursor = self.cursor else {
				return
			}

			continuation.yield(.cursor(cursor))
		}
	}

	open func didUpdateFrame(_ framebufferView: NSView) {
		self.continuation.withLock {
			guard let continuation = $0 else {
				return
			}

			guard let cgImage = self.cgImage else {
				return
			}

			continuation.yield(.frame(cgImage))
		}
	}
}

extension NSCursor {
	var vncCursor: VNCCursor? {
		let logger = Logger("NSCursor")

		guard let cursorImage = self.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
			logger.debug("Unable to convert cursor to CGImage")
			return nil
		}

		guard cursorImage.width > 0, cursorImage.height > 0 else {
			logger.debug("Cursor image is empty")
			return nil
		}

		// Extract tightly packed RGBA pixel data with top-left origin.
		guard let pixelData = extractPixelData(from: cursorImage) else {
			logger.debug("Unable to extract pixel data from cursor image")
			return nil
		}

		// Generate bitmask (1 bit per pixel indicating visibility)
		let maskData = generateCursorMask(from: pixelData, width: cursorImage.width, height: cursorImage.height)

		// Dimensions
		let width = UInt16(cursorImage.width)
		let height = UInt16(cursorImage.height)

		// NSCursor.hotSpot uses AppKit coordinates (origin at lower-left).
		let hs = self.hotSpot
		let hotX = UInt16(max(0, min(cursorImage.width - 1, Int(hs.x.rounded()))))
		let hotY = UInt16(max(0, min(cursorImage.height - 1, (cursorImage.height - 1) - Int(hs.y.rounded()))))

		return VNCCursor(
			header: VNCCursorHeader(
				hotX: hotX,
				hotY: hotY,
				width: width,
				height: height,
			),
			mask: maskData,
			data: pixelData
		)
	}

	private func extractPixelData(from cgImage: CGImage) -> Data? {
		let width = cgImage.width
		let height = cgImage.height
		let bytesPerPixel = 4

		// Create RGBA buffer from image
		var rgbaPixels = Data(count: width * height * bytesPerPixel)

		let success: Bool = rgbaPixels.withUnsafeMutableBytes { (mutablePtr: UnsafeMutableRawBufferPointer) in
			guard let baseAddress = mutablePtr.baseAddress else { return false }
			guard let context = CGContext(
					data: baseAddress,
					width: width,
					height: height,
					bitsPerComponent: 8,
					bytesPerRow: width * bytesPerPixel,
					space: CGColorSpaceCreateDeviceRGB(),
					bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {
				return false
			}

			context.translateBy(x: 0, y: CGFloat(height))
			context.scaleBy(x: 1, y: -1)
			context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
			return true
		}

		return success ? rgbaPixels : nil
	}

	private func generateCursorMask(from pixelData: Data, width: Int, height: Int) -> Data {
		// Bitmask: 1 bit per pixel, rounded to byte boundary per row
		let bytesPerRow = (width + 7) / 8
		var maskData = Data(count: bytesPerRow * height)
		let bytesPerPixel = 4

		// Set bits for pixels with alpha > 0
		for row in 0..<height {
			for col in 0..<width {
				let pixelIndex = (row * width + col) * bytesPerPixel
				guard pixelData.count > pixelIndex + 3 else {
					continue
				}
				let alphaValue = pixelData[pixelIndex + 3]

				if alphaValue > 127 {  // Threshold for visibility
					let maskByteIndex = row * bytesPerRow + col / 8
					let bitIndex = 7 - (col % 8)
					maskData[maskByteIndex] |= (1 << bitIndex)
				}
			}
		}

		return maskData
	}

}
