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

extension NSEvent {
	open override var description: String {
		var parts: [String] = []

		parts.append("type=\(self.type.rawValue)")
		parts.append("subtype=\(self.subtype.rawValue)")
		parts.append("timestamp=\(self.timestamp)")
		parts.append("modifierFlags=\(self.modifierFlags)")
		parts.append("windowNumber=\(self.windowNumber)")
		if let window = self.window { parts.append("windowFrame=\(NSStringFromRect(window.frame))") }
		parts.append("locationInWindow=\(NSStringFromPoint(self.locationInWindow))")
		//if let chars = self.characters { parts.append("characters=\(chars)") }
		//if let charsIM = self.charactersIgnoringModifiers { parts.append("charactersIgnoringModifiers=\(charsIM)") }
		parts.append("keyCode=\(self.keyCode)")
		parts.append("isARepeat=\(self.isARepeat)")
		parts.append("buttonNumber=\(self.buttonNumber)")
		parts.append("clickCount=\(self.clickCount)")
		parts.append("pressure=\(self.pressure)")
		parts.append("deltaX=\(self.deltaX)")
		parts.append("deltaY=\(self.deltaY)")
		parts.append("deltaZ=\(self.deltaZ)")
		parts.append("scrollingDeltaX=\(self.scrollingDeltaX)")
		parts.append("scrollingDeltaY=\(self.scrollingDeltaY)")
		parts.append("hasPreciseScrollingDeltas=\(self.hasPreciseScrollingDeltas)")
		parts.append("phase=\(self.phase.rawValue)")
		parts.append("momentumPhase=\(self.momentumPhase)")
		parts.append("isDirectionInvertedFromDevice=\(self.isDirectionInvertedFromDevice)")

		if let cgEvent = self.cgEvent {
			parts.append("CGEvent{")
			parts.append("  flags=\(cgEvent.flags)")
			parts.append("  type=\(cgEvent.type)")
			parts.append("  location=\(cgEvent.location)")
			parts.append("  timestamp=\(cgEvent.timestamp)")

			parts.append("  CGEventField{")
				for field in CGEventField.allCases {
					let value = cgEvent.getDoubleValueField(field)

					if value != 0 {
						parts.append("    \(field)=\(value)")
					}
				}
			parts.append("  }")
			parts.append("}")
		}

		return "NSEvent{ " + parts.joined(separator: ", ") + " }"
	}
}

extension CGEventField: @retroactive CaseIterable {
    public static let allCases: [CGEventField] = [
		.mouseEventNumber,
		.mouseEventClickState,
		.mouseEventPressure,
		.mouseEventButtonNumber,
		.mouseEventDeltaX,
		.mouseEventDeltaY,
		.mouseEventInstantMouser,
		.mouseEventSubtype,
		.keyboardEventAutorepeat,
		.keyboardEventKeycode,
		.keyboardEventKeyboardType,
		.scrollWheelEventDeltaAxis1,
		.scrollWheelEventDeltaAxis2,
		.scrollWheelEventDeltaAxis3,
		.scrollWheelEventFixedPtDeltaAxis1,
		.scrollWheelEventFixedPtDeltaAxis2,
		.scrollWheelEventFixedPtDeltaAxis3,
		.scrollWheelEventPointDeltaAxis1,
		.scrollWheelEventPointDeltaAxis2,
		.scrollWheelEventPointDeltaAxis3,
		.scrollWheelEventScrollPhase,
		.scrollWheelEventScrollCount,
		.scrollWheelEventMomentumPhase,
		.scrollWheelEventInstantMouser,
		.tabletEventPointX,
		.tabletEventPointY,
		.tabletEventPointZ,
		.tabletEventPointButtons,
		.tabletEventPointPressure,
		.tabletEventTiltX,
		.tabletEventTiltY,
		.tabletEventRotation,
		.tabletEventTangentialPressure,
		.tabletEventDeviceID,
		.tabletEventVendor1,
		.tabletEventVendor2,
		.tabletEventVendor3,
		.tabletProximityEventVendorID,
		.tabletProximityEventTabletID,
		.tabletProximityEventPointerID,
		.tabletProximityEventDeviceID,
		.tabletProximityEventSystemTabletID,
		.tabletProximityEventVendorPointerType,
		.tabletProximityEventVendorPointerSerialNumber,
		.tabletProximityEventVendorUniqueID,
		.tabletProximityEventCapabilityMask,
		.tabletProximityEventPointerType,
		.tabletProximityEventEnterProximity,
		.eventTargetProcessSerialNumber,
		.eventTargetUnixProcessID,
		.eventSourceUnixProcessID,
		.eventSourceUserData,
		.eventSourceUserID,
		.eventSourceGroupID,
		.eventSourceStateID,
		.scrollWheelEventIsContinuous,
		.mouseEventWindowUnderMousePointer,
		.mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
		.eventUnacceleratedPointerMovementX,
		.eventUnacceleratedPointerMovementY,
		.scrollWheelEventMomentumOptionPhase,
		.scrollWheelEventAcceleratedDeltaAxis1,
		.scrollWheelEventAcceleratedDeltaAxis2,
		.scrollWheelEventRawDeltaAxis1,
		.scrollWheelEventRawDeltaAxis2
	]
}

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
			}

			VNCVirtualMachineView.swizzled = true
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

#if DEBUG
extension VNCVirtualMachineView {
	public override func keyDown(with event: NSEvent) {
		Logger(self).debug("keyDown: keyCode=\(event.keyCode), modifiers=\(String(event.modifierFlags.rawValue, radix: 16)), characters='\(event.characters ?? "none")' charactersIgnoringModifiers='\(event.charactersIgnoringModifiers ?? "none")'")

		super.keyDown(with: event)
	}

	public override func flagsChanged(with event: NSEvent) {
		Logger(self).debug("flagsChanged: keyCode=\(event.keyCode), modifiers=\(String(event.modifierFlags.rawValue, radix: 16))")

		super.flagsChanged(with: event)
	}

	public override func scrollWheel(with event: NSEvent) {
		Logger(self).debug("scrollWheel: \(event.description)")

		super.scrollWheel(with: event)
	}

	private func debugDescription(for event: NSEvent) -> String {
	    var parts: [String] = []
	    parts.append("type=\(event.type.rawValue)")
	    parts.append("subtype=\(event.subtype.rawValue)")
	    parts.append("timestamp=\(event.timestamp)")
	    parts.append(String(format: "modifierFlags=0x%llx", event.modifierFlags.rawValue))
	    parts.append("windowNumber=\(event.windowNumber)")
	    if let window = event.window { parts.append("windowFrame=\(NSStringFromRect(window.frame))") }
	    parts.append("locationInWindow=\(NSStringFromPoint(event.locationInWindow))")
	    if let chars = event.characters { parts.append("characters=\(chars)") }
	    if let charsIM = event.charactersIgnoringModifiers { parts.append("charactersIgnoringModifiers=\(charsIM)") }
	    parts.append("keyCode=\(event.keyCode)")
	    parts.append("isARepeat=\(event.isARepeat)")
	    parts.append("buttonNumber=\(event.buttonNumber)")
	    parts.append("clickCount=\(event.clickCount)")
	    parts.append("pressure=\(event.pressure)")
	    parts.append("deltaX=\(event.deltaX)")
	    parts.append("deltaY=\(event.deltaY)")
	    parts.append("deltaZ=\(event.deltaZ)")
	    parts.append("scrollingDeltaX=\(event.scrollingDeltaX)")
	    parts.append("scrollingDeltaY=\(event.scrollingDeltaY)")
	    parts.append("hasPreciseScrollingDeltas=\(event.hasPreciseScrollingDeltas)")
	    parts.append("phase=\(event.phase.rawValue)")
	    parts.append("momentumPhase=\(event.momentumPhase.rawValue)")
	    parts.append("isDirectionInvertedFromDevice=\(event.isDirectionInvertedFromDevice)")
		
	    if let cgEvent = event.cgEvent {
	        let fields: [CGEventField] = [
	            .scrollWheelEventDeltaAxis1,
	            .scrollWheelEventDeltaAxis2,
	            .scrollWheelEventDeltaAxis3,
	            .scrollWheelEventFixedPtDeltaAxis1,
	            .scrollWheelEventFixedPtDeltaAxis2,
	            .scrollWheelEventFixedPtDeltaAxis3,
	            .scrollWheelEventPointDeltaAxis1,
	            .scrollWheelEventPointDeltaAxis2,
	            .scrollWheelEventPointDeltaAxis3,
	            .scrollWheelEventAcceleratedDeltaAxis1,
	            .scrollWheelEventAcceleratedDeltaAxis2,
	            .scrollWheelEventRawDeltaAxis1,
	            .scrollWheelEventRawDeltaAxis2,
	            .scrollWheelEventScrollPhase,
	            .scrollWheelEventScrollCount,
	            .scrollWheelEventMomentumPhase,
	            .scrollWheelEventInstantMouser,
	            .scrollWheelEventIsContinuous,
	            .scrollWheelEventMomentumOptionPhase
	        ]
	        var cgParts: [String] = []
	        for field in fields {
	            let value = cgEvent.getDoubleValueField(field)
	            if value != 0 {
	                cgParts.append("\(field)=\(value)")
	            }
	        }
	        if !cgParts.isEmpty { parts.append("cgEvent{ " + cgParts.joined(separator: ", ") + " }") }
	    }
	    return "NSEvent{ " + parts.joined(separator: ", ") + " }"
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

