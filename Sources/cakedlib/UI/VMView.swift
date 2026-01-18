//
//  VMView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import QuartzCore
import SwiftUI
import Virtualization
import CakeAgentLib
import Dynamic
import ObjectiveC.runtime

#if DEBUG
@objc protocol _VZFramebufferObserver {
	@objc func framebuffer(_ framebuffer: NSObject, didUpdateCursor cursor: UnsafePointer<UInt8>?)
	@objc func framebuffer(_ framebuffer: NSObject, didUpdateFrame frame: UnsafePointer<UInt8>?)
	@objc func framebuffer(_ framebuffer: NSObject, didUpdateGraphicsOrientation orientation: Int64)
	@objc func framebufferDidUpdateColorSpace(_ framebuffer: NSObject)
}

@objc protocol VZFramebufferObserver {
	@objc func framebuffer(_ framebufferView: NSView, didUpdateCursor cursor: UnsafePointer<UInt8>?)
	@objc func framebuffer(_ framebufferView: NSView, didUpdateFrame frame: UnsafePointer<UInt8>?)
	@objc func framebuffer(_ framebufferView: NSView, didUpdateGraphicsOrientation orientation: Int64)
	@objc func framebufferDidUpdateColorSpace(_ framebuffer: NSObject)
}

extension VZGraphicsDisplay {
	typealias TakeScreenshotCompletionBlock = @convention(block) (_ result: NSImage) -> Void

	func takeScreenshot(completionHandler: @escaping (NSImage) -> Void) {
		Dynamic(self)._takeScreenshot(withCompletionHandler: { value in
			completionHandler(value)
		} as TakeScreenshotCompletionBlock)
	}
}

open class VZFramebufferLayer: CALayer {
	// Intercept framebuffer contents changes (e.g., IOSurface) for observation/customization
	var image: NSImage? = nil
	
	open override var contents: Any? {
		get {
			super.contents
		}
		set {
			if let surface = newValue as? IOSurface {
				self.image = surface.image
			}
			
			// Forward to CALayer so the view renders normally
			super.contents = newValue
			
			// If you need to react (e.g., mark as needing display or notify observers), do it here
			// setNeedsDisplay() // Usually not needed for IOSurface-backed contents
		}
	}
}

extension NSView {
	func swizzleFramebufferObserver() {
		let protocols = self.protocolNames
		
		// Check if `self` conforms to the private framebuffer observer protocol using a safe cast
		if protocols.first(where: { $0 == "_VZFramebufferObserver" }) != nil {
			// Only attempt to swizzle if the selectors exist on this instance
			let hasCursorSel = self.responds(to: #selector(_VZFramebufferObserver.framebuffer(_:didUpdateCursor:)))
			let hasFrameSel = self.responds(to: #selector(_VZFramebufferObserver.framebuffer(_:didUpdateFrame:)))
			let hasOrientationSel = self.responds(to: #selector(_VZFramebufferObserver.framebuffer(_:didUpdateGraphicsOrientation:)))
			let hasColorSpaceSel = self.responds(to: #selector(_VZFramebufferObserver.framebufferDidUpdateColorSpace(_:)))
			
			if hasCursorSel {
				self.swizzleMethod(originalSelector: #selector(_VZFramebufferObserver.framebuffer(_:didUpdateCursor:)),
								   swizzledSelector: #selector(swizzled_framebuffer(_:didUpdateCursor:)))
			}
			
			if hasFrameSel {
				self.swizzleMethod(originalSelector: #selector(_VZFramebufferObserver.framebuffer(_:didUpdateFrame:)),
								   swizzledSelector: #selector(swizzled_framebuffer(_:didUpdateFrame:)))
			}
			
			if hasOrientationSel {
				self.swizzleMethod(originalSelector: #selector(_VZFramebufferObserver.framebuffer(_:didUpdateGraphicsOrientation:)),
								   swizzledSelector: #selector(swizzled_framebuffer(_:didUpdateGraphicsOrientation:)))
			}
			if hasColorSpaceSel {
				self.swizzleMethod(originalSelector: #selector(_VZFramebufferObserver.framebufferDidUpdateColorSpace(_:)),
								   swizzledSelector: #selector(swizzled_framebufferDidUpdateColorSpace(_:)))
			}
		}
	}

	@objc func swizzled_framebuffer(_ framebuffer: NSObject, didUpdateCursor cursor: UnsafePointer<UInt8>?) {
		self.swizzled_framebuffer(framebuffer, didUpdateCursor: cursor)

		if let observer = self.superview as? VZFramebufferObserver {
			observer.framebuffer(self, didUpdateCursor: cursor)
		}
	}

	@objc func swizzled_framebuffer(_ framebuffer: NSObject, didUpdateFrame frame: UnsafePointer<UInt8>?) {
		/*struct FrameBuffer {
			var a: UnsafePointer<UInt8>?
			var b: UnsafePointer<UInt8>?
			var c: UnsafePointer<UInt8>?
			var d: UnsafePointer<UInt8>?
			var e: UnsafePointer<UInt8>?
			var f: UnsafePointer<UInt8>?
		}

		frame?.withMemoryRebound(to: FrameBuffer.self, capacity: 1) { p in
			let ptr = p.pointee

			print("\(#function): \(ptr)")
		}*/

		self.swizzled_framebuffer(framebuffer, didUpdateFrame: frame)

		if let observer = self.superview as? VZFramebufferObserver {
			observer.framebuffer(self, didUpdateFrame: frame)
		}
	}

	@objc func swizzled_framebuffer(_ framebuffer: NSObject, didUpdateGraphicsOrientation orientation: Int64) {
		self.swizzled_framebuffer(framebuffer, didUpdateGraphicsOrientation: orientation)

		if let observer = self.superview as? VZFramebufferObserver {
			observer.framebuffer(self, didUpdateGraphicsOrientation: orientation)
		}
	}

	@objc func swizzled_framebufferDidUpdateColorSpace(_ framebuffer: NSObject) {
		self.swizzled_framebufferDidUpdateColorSpace(framebuffer)

		if let observer = self.superview as? VZFramebufferObserver {
			observer.framebufferDidUpdateColorSpace(framebuffer)
		}
	}
}
#endif

extension VZVirtualMachineView {
	public func takeScreenshot(completionHandler: @escaping (NSObject) -> Void) {
		self.graphicsDisplay?.takeScreenshot(completionHandler: completionHandler)
	}

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
	
	func contents() -> Data? {
		guard let surface = self.framebufferView?.layer?.contents as? IOSurface else {
			return nil
		}

		return surface.contents
	}

	override public func image() -> NSImage? {
		guard let layer = self.framebufferView?.layer as? VZFramebufferLayer else {
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
}

class ExVZVirtualMachineView: VZVirtualMachineView, VZFramebufferObserver {
	var onDisconnect: (() -> Void)?
	var contents: Data?

	static var swizzled = false

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)

		#if DEBUG
			if let framebufferView = self.framebufferView, !ExVZVirtualMachineView.swizzled {
				let newLayer = VZFramebufferLayer()
				framebufferView.layer?.removeFromSuperlayer()
				
				newLayer.delegate = framebufferView.layer?.delegate
				framebufferView.layer = newLayer
				framebufferView.swizzleFramebufferObserver()

				ExVZVirtualMachineView.swizzled = true
			}
		#endif
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func framebuffer(_ framebufferView: NSView, didUpdateCursor cursor: UnsafePointer<UInt8>?) {
	}
	
	func framebuffer(_ framebufferView: NSView, didUpdateFrame frame: UnsafePointer<UInt8>?) {
		if let surface = framebufferView.layer?.contents as? IOSurface {
			print(surface.description)
		}
	}
	
	func framebuffer(_ framebufferView: NSView, didUpdateGraphicsOrientation orientation: Int64) {
	}
	
	func framebufferDidUpdateColorSpace(_ framebufferView: NSObject) {
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

public struct VMView: NSViewRepresentable {
	public typealias NSViewType = VZVirtualMachineView

	public var virtualMachine: VirtualMachine
	public var params: VMRunHandler

	public static func createView(vm: VirtualMachine, frame: NSRect) -> VZVirtualMachineView {
		#if DEBUG
			let vzMachineView = ExVZVirtualMachineView(frame: frame)
		#else
			let vzMachineView = VZVirtualMachineView(frame: frame)
		#endif

		vzMachineView.virtualMachine = vm.virtualMachine
		vzMachineView.autoresizingMask = [.width, .height]
		vzMachineView.automaticallyReconfiguresDisplay = true
		vzMachineView.capturesSystemKeys = true
		//vzMachineView.showsHostCursor = false

		return vzMachineView
	}

	public init(_ vm: VirtualMachine, params: VMRunHandler) {
		self.params = params
		self.virtualMachine = vm
	}

	public func makeNSView(context: Context) -> VZVirtualMachineView {
		guard let vmView = self.virtualMachine.env.vzMachineView else {
			return NSViewType()
		}

		return vmView
	}

	public func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {
	}
}

