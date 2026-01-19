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

@objc protocol _VZFramebufferObserver {
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
			let hasFrameSel = self.responds(to: #selector(_VZFramebufferObserver.framebuffer(_:didUpdateFrame:)))

			if hasFrameSel {
				self.swizzleMethod(originalSelector: #selector(_VZFramebufferObserver.framebuffer(_:didUpdateFrame:)),
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

	#if false
	override public func image() -> NSImage? {
		guard let layer = self.framebufferView?.layer else {
			return nil
		}

		return layer.renderIntoImage()
	}

	override public func image(in bounds: NSRect) -> NSImage? {
		guard let surface = self.framebufferView?.layer?.contents as? IOSurface else {
			return nil
		}

		return surface.image(in: bounds)
	}
	#endif
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

	private var continuation: AsyncStream<CGImage>.Continuation? = nil

	public override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)

		if let framebufferView = self.framebufferView {
			let newLayer = VNCFramebufferLayer()
			framebufferView.layer?.removeFromSuperlayer()
			
			newLayer.delegate = framebufferView.layer?.delegate
			framebufferView.layer = newLayer

			if VNCVirtualMachineView.swizzled == false {
				framebufferView.swizzleFramebufferObserver()
			}
		}
	}

	public required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	#if DEBUG
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
	public var cgImage: CGImage? {
		self.framebufferView?.layer?.renderIntoImage()
	}
	
	public var bitmapInfos: CGBitmapInfo {
		CGBitmapInfo(alpha: CGImageAlphaInfo.noneSkipFirst, component: .integer, byteOrder: .order32Little)
	}

	public func startFramebufferUpdate(continuation: AsyncStream<CGImage>.Continuation) {
		self.continuation = continuation
	}
	
	public func stopFramebufferUpdate() {
		self.continuation = nil
	}
}

extension VNCVirtualMachineView: VNCFramebufferObserver {
	open func didUpdateFrame(_ framebufferView: NSView) {
		guard let continuation = self.continuation  else {
			return
		}

		guard let cgImage = framebufferView.layer?.renderIntoImage() else {
			return
		}

		continuation.yield(cgImage)
	}
}
