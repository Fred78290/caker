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
	var dumpEvent: String {
		var parts: [String] = []

		parts.append("type: \(self.type)")
		parts.append("timestamp: \(self.timestamp)")
		parts.append("modifierFlags: \(String(self.modifierFlags.rawValue, radix: 16))")
		parts.append("windowNumber: \(self.windowNumber)")
		if let window = self.window { parts.append("windowFrame: \(NSStringFromRect(window.frame))") }

		parts.append("locationInWindow: \(NSStringFromPoint(self.locationInWindow))")

		switch self.type {
		case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
			parts.append("subtype: \(self.subtype)")
			parts.append("clickCount: \(self.clickCount)")
			parts.append("buttonNumber: \(self.buttonNumber)")
			parts.append("phase: \(self.phase.rawValue)")
			parts.append("momentumPhase: \(self.momentumPhase)")
			parts.append("isDirectionInvertedFromDevice: \(self.isDirectionInvertedFromDevice)")

			break

		case .mouseEntered, .mouseExited:
			parts.append("buttonNumber: \(self.buttonNumber)")
			parts.append("phase: \(self.phase.rawValue)")
			parts.append("momentumPhase: \(self.momentumPhase)")
			parts.append("isDirectionInvertedFromDevice: \(self.isDirectionInvertedFromDevice)")

			break

		case .keyDown, .keyUp:
			parts.append("isARepeat: \(self.isARepeat)")
			parts.append("keyCode: \(self.keyCode)")
			if let chars = self.characters {
				parts.append("characters: \(chars)")
			}
			if let charsIM = self.charactersIgnoringModifiers {
				parts.append("charactersIgnoringModifiers: \(charsIM)")
			}

		case .periodic, .cursorUpdate, .appKitDefined, .systemDefined, .applicationDefined:
			parts.append("subtype: \(self.subtype)")
			break

		case .scrollWheel, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
			parts.append("phase: \(self.phase.rawValue)")
			parts.append("momentumPhase: \(self.momentumPhase)")
			parts.append("isDirectionInvertedFromDevice: \(self.isDirectionInvertedFromDevice)")

			parts.append("hasPreciseScrollingDeltas: \(self.hasPreciseScrollingDeltas)")
			parts.append("buttonNumber: \(self.buttonNumber)")
			parts.append("deltaX: \(self.deltaX)")
			parts.append("deltaY: \(self.deltaY)")
			parts.append("deltaZ: \(self.deltaZ)")
			parts.append("scrollingDeltaX: \(self.scrollingDeltaX)")
			parts.append("scrollingDeltaY: \(self.scrollingDeltaY)")
			break

		case .flagsChanged:
			break
		case .tabletPoint, .tabletProximity:
			parts.append("deltaX: \(self.deltaX)")
			parts.append("deltaY: \(self.deltaY)")
			parts.append("deltaZ: \(self.deltaZ)")
			break
		case .magnify, .smartMagnify:
			break
		case .swipe, .rotate, .pressure, .directTouch:
			parts.append("pressure: \(self.pressure)")
			break
		case .gesture, .beginGesture, .endGesture:
			break
		case .quickLook:
			break
		case .changeMode:
			break
		case .mouseCancelled:
			parts.append("phase: \(self.phase.rawValue)")
			parts.append("momentumPhase: \(self.momentumPhase)")
			parts.append("isDirectionInvertedFromDevice: \(self.isDirectionInvertedFromDevice)")

			parts.append("buttonNumber: \(self.buttonNumber)")
			break
		default:
			break
		}

		if let cgEvent = self.cgEvent {
			parts.append("CGEvent: {")
			parts.append("  flags: \(cgEvent.flags)")
			parts.append("  type: \(cgEvent.type)")
			parts.append("  location: \(cgEvent.location)")
			parts.append("  timestamp: \(cgEvent.timestamp)")

			parts.append("  CGEventFields: {")
				for field in CGEventField.allCases {
					let value = cgEvent.getDoubleValueField(field)

					if value != 0 {
						if let field = CGEventField.names[field] {
							parts.append("    \(field): \(value)")
						} else {
							parts.append("    \(field): \(value)")
						}
					}
				}
			parts.append("  }")
			parts.append("}")
		}

		return "\nNSEvent: {\n  " + parts.joined(separator: ",\n  ") + "\n}"
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
	
	public static let names: [CGEventField:String] = [
		.mouseEventNumber: "mouseEventNumber",
		.mouseEventClickState: "mouseEventClickState",
		.mouseEventPressure: "mouseEventPressure",
		.mouseEventButtonNumber: "mouseEventButtonNumber",
		.mouseEventDeltaX: "mouseEventDeltaX",
		.mouseEventDeltaY: "mouseEventDeltaY",
		.mouseEventInstantMouser: "mouseEventInstantMouser",
		.mouseEventSubtype: "mouseEventSubtype",
		.keyboardEventAutorepeat: "keyboardEventAutorepeat",
		.keyboardEventKeycode: "keyboardEventKeycode",
		.keyboardEventKeyboardType: "keyboardEventKeyboardType",
		.scrollWheelEventDeltaAxis1: "scrollWheelEventDeltaAxis1",
		.scrollWheelEventDeltaAxis2: "scrollWheelEventDeltaAxis2",
		.scrollWheelEventDeltaAxis3: "scrollWheelEventDeltaAxis3",
		.scrollWheelEventFixedPtDeltaAxis1: "scrollWheelEventFixedPtDeltaAxis1",
		.scrollWheelEventFixedPtDeltaAxis2: "scrollWheelEventFixedPtDeltaAxis2",
		.scrollWheelEventFixedPtDeltaAxis3: "scrollWheelEventFixedPtDeltaAxis3",
		.scrollWheelEventPointDeltaAxis1: "scrollWheelEventPointDeltaAxis1",
		.scrollWheelEventPointDeltaAxis2: "scrollWheelEventPointDeltaAxis2",
		.scrollWheelEventPointDeltaAxis3: "scrollWheelEventPointDeltaAxis3",
		.scrollWheelEventScrollPhase: "scrollWheelEventScrollPhase",
		.scrollWheelEventScrollCount: "scrollWheelEventScrollCount",
		.scrollWheelEventMomentumPhase: "scrollWheelEventMomentumPhase",
		.scrollWheelEventInstantMouser: "scrollWheelEventInstantMouser",
		.tabletEventPointX: "tabletEventPointX",
		.tabletEventPointY: "tabletEventPointY",
		.tabletEventPointZ: "tabletEventPointZ",
		.tabletEventPointButtons: "tabletEventPointButtons",
		.tabletEventPointPressure: "tabletEventPointPressure",
		.tabletEventTiltX: "tabletEventTiltX",
		.tabletEventTiltY: "tabletEventTiltY",
		.tabletEventRotation: "tabletEventRotation",
		.tabletEventTangentialPressure: "tabletEventTangentialPressure",
		.tabletEventDeviceID: "tabletEventDeviceID",
		.tabletEventVendor1: "tabletEventVendor1",
		.tabletEventVendor2: "tabletEventVendor2",
		.tabletEventVendor3: "tabletEventVendor3",
		.tabletProximityEventVendorID: "tabletProximityEventVendorID",
		.tabletProximityEventTabletID: "tabletProximityEventTabletID",
		.tabletProximityEventPointerID: "tabletProximityEventPointerID",
		.tabletProximityEventDeviceID: "tabletProximityEventDeviceID",
		.tabletProximityEventSystemTabletID: "tabletProximityEventSystemTabletID",
		.tabletProximityEventVendorPointerType: "tabletProximityEventVendorPointerType",
		.tabletProximityEventVendorPointerSerialNumber: "tabletProximityEventVendorPointerSerialNumber",
		.tabletProximityEventVendorUniqueID: "tabletProximityEventVendorUniqueID",
		.tabletProximityEventCapabilityMask: "tabletProximityEventCapabilityMask",
		.tabletProximityEventPointerType: "tabletProximityEventPointerType",
		.tabletProximityEventEnterProximity: "tabletProximityEventEnterProximity",
		.eventTargetProcessSerialNumber: "eventTargetProcessSerialNumber",
		.eventTargetUnixProcessID: "eventTargetUnixProcessID",
		.eventSourceUnixProcessID: "eventSourceUnixProcessID",
		.eventSourceUserData: "eventSourceUserData",
		.eventSourceUserID: "eventSourceUserID",
		.eventSourceGroupID: "eventSourceGroupID",
		.eventSourceStateID: "eventSourceStateID",
		.scrollWheelEventIsContinuous: "scrollWheelEventIsContinuous",
		.mouseEventWindowUnderMousePointer: "mouseEventWindowUnderMousePointer",
		.mouseEventWindowUnderMousePointerThatCanHandleThisEvent: "mouseEventWindowUnderMousePointerThatCanHandleThisEvent",
		.eventUnacceleratedPointerMovementX: "eventUnacceleratedPointerMovementX",
		.eventUnacceleratedPointerMovementY: "eventUnacceleratedPointerMovementY",
		.scrollWheelEventMomentumOptionPhase: "scrollWheelEventMomentumOptionPhase",
		.scrollWheelEventAcceleratedDeltaAxis1: "scrollWheelEventAcceleratedDeltaAxis1",
		.scrollWheelEventAcceleratedDeltaAxis2: "scrollWheelEventAcceleratedDeltaAxis2",
		.scrollWheelEventRawDeltaAxis1: "scrollWheelEventRawDeltaAxis1",
		.scrollWheelEventRawDeltaAxis2: "scrollWheelEventRawDeltaAxis2",
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

