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

extension CGEvent {
	var dumpEvent: String {
		var parts: [String] = []
		
		parts.append("CGEvent: {")
		parts.append("  flags: \(self.flags)")
		parts.append("  type: \(self.type)")
		parts.append("  location: \(self.location)")
		parts.append("  timestamp: \(self.timestamp)")
		
		parts.append("  CGEventFields: {")
		for field in CGEventField.allCases {
			let value = self.getDoubleValueField(field)
			
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
		
		return parts.joined(separator: ",\n")
	}
}

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
					bitmapFormat: .thirtyTwoBitLittleEndian,
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

#if XDEBUG
		var pixels = Data(count: self.allocationSize)

		pixels.withUnsafeMutableBytes { ptr in
			guard var baseAddress = ptr.bindMemory(to: UInt8.self).baseAddress else {
				return
			}
			
			for line in 0..<self.height {
				var pRow = baseAddress
				let idx = line < self.height / 2 ? 0 : 2
				let value: UInt8 = line < self.height / 2 ? 0x80 : 0x81
				baseAddress = baseAddress.advanced(by: self.bytesPerRow)

				for _ in 0..<Int(self.width) {
					pRow[idx] = value
					pRow[3] = 255

					pRow = pRow.advanced(by: 4)
				}
			}
		}

#else
		var pixels = Data(bytes: self.baseAddress, count: self.allocationSize)
#endif

		guard let provider = CGDataProvider(data: pixels as CFData) else {
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
