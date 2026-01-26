//
//  VNCVZVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 19/01/2026.
//
import Foundation
import Virtualization
import CakeAgentLib
import QuartzCore
import Dynamic
import ObjectiveC.runtime
import Synchronization

@objc protocol VZFramebufferObserver {
	@objc func framebuffer(_ framebuffer: NSObject, didUpdateCursor cursor: UnsafePointer<UInt8>?)
	@objc func framebuffer(_ framebuffer: NSObject, didUpdateFrame frame: UnsafePointer<UInt8>?)
	@objc func framebuffer(_ framebuffer: NSObject, didUpdateGraphicsOrientation orientation: Int64)
	@objc func framebufferDidUpdateColorSpace(_ framebuffer: NSObject)
}

extension NSView {
	func swizzleFramebufferObserver() {
		let protocols = self.protocolNames
		
		// Check if `self` conforms to the private framebuffer observer protocol using a safe cast
		if protocols.first(where: { $0 == "_VZFramebufferObserver" }) != nil {
			// Only attempt to swizzle if the selectors exist on this instance
			let hasFrameSel = self.responds(to: #selector(VZFramebufferObserver.framebuffer(_:didUpdateFrame:)))

			if hasFrameSel {
				self.swizzleMethod(originalSelector: #selector(VZFramebufferObserver.framebuffer(_:didUpdateFrame:)),
								   swizzledSelector: #selector(swizzled_framebuffer(_:didUpdateFrame:)))

				VNCVirtualMachineView.swizzled = true
			}
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
		
		let cname = property_getName(prop) // UnsafePointer<CChar>
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

#if DEBUG
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
	#endif

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

	private let continuation: Mutex<AsyncStream<CGImage>.Continuation?> = .init(nil)

	public override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)

		if let framebufferView = self.framebufferView {
			/*let newLayer = VNCFramebufferLayer()
			framebufferView.layer?.removeFromSuperlayer()
			
			newLayer.delegate = framebufferView.layer?.delegate
			framebufferView.layer = newLayer*/

			if VNCVirtualMachineView.swizzled == false {
				framebufferView.swizzleFramebufferObserver()
			}
		}
	}

	public required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	#if DEBUGKEYBOARD
		public override func keyDown(with event: NSEvent) {
			Logger(self).debug("keyDown: keyCode=\(event.keyCode), modifiers=\(String(event.modifierFlags.rawValue, radix: 16)), characters='\(event.characters ?? "none")' charactersIgnoringModifiers='\(event.charactersIgnoringModifiers ?? "none")'")

			super.keyDown(with: event)
		}

		public override func flagsChanged(with event: NSEvent) {
			Logger(self).debug("flagsChanged: keyCode=\(event.keyCode), modifiers=\(String(event.modifierFlags.rawValue, radix: 16))")

			super.flagsChanged(with: event)
		}

		public override func scrollWheel(with event: NSEvent) {
			Logger(self).debug("scrollWheel: deltaX=\(event.deltaX), deltaY=\(event.deltaY), deltaZ=\(event.deltaZ), modifiers=\(String(event.modifierFlags.rawValue, radix: 16))")

			super.scrollWheel(with: event)
		}
	#endif
}

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

	public func startFramebufferUpdate(continuation: AsyncStream<CGImage>.Continuation) {
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
	open func didUpdateFrame(_ framebufferView: NSView) {
		self.continuation.withLock {
			guard let continuation = $0  else {
				return
			}

			guard let cgImage = self.cgImage else {
				return
			}

			continuation.yield(cgImage)
		}
	}
}
