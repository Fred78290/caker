import Foundation
import AppKit
import Carbon

public class VNCInputHandler {
    private weak var targetView: NSView?
    private var mouseButtonState: UInt8 = 0
    private var lastMousePosition = NSPoint.zero
    private let keyMapper = VNCKeyMapper()
    
    init(targetView: NSView?) {
        self.targetView = targetView
    }
    
    // MARK: - Mouse Events
    
    func handlePointerEvent(x: Int, y: Int, buttonMask: UInt8) {
        guard let view = targetView, let window = view.window else { return }
        
        // Convert VNC coordinates (origin top-left) to NSView (origin bottom-left)
        let viewBounds = view.bounds
        let nsPoint = NSPoint(x: CGFloat(x), y: viewBounds.height - CGFloat(y))
        
        // Convert to window coordinates
        let windowPoint = view.convert(nsPoint, to: nil)
        
        // Convert to screen coordinates
        let screenPoint = window.convertToScreen(NSRect(origin: windowPoint, size: .zero)).origin
        
        // Handle mouse buttons
        handleMouseButtons(buttonMask: buttonMask, at: screenPoint)
        
        // Handle mouse movement
        if nsPoint != lastMousePosition {
            handleMouseMovement(to: screenPoint)
            lastMousePosition = nsPoint
        }
    }
    
    private func handleMouseButtons(buttonMask: UInt8, at screenPoint: NSPoint) {
        let previousState = mouseButtonState
        mouseButtonState = buttonMask
        
        // Left button (bit 0)
        if (buttonMask & 0x01) != (previousState & 0x01) {
            if (buttonMask & 0x01) != 0 {
                postMouseEvent(type: .leftMouseDown, at: screenPoint)
            } else {
                postMouseEvent(type: .leftMouseUp, at: screenPoint)
            }
        }
        
        // Right button (bit 2)
        if (buttonMask & 0x04) != (previousState & 0x04) {
            if (buttonMask & 0x04) != 0 {
                postMouseEvent(type: .rightMouseDown, at: screenPoint)
            } else {
                postMouseEvent(type: .rightMouseUp, at: screenPoint)
            }
        }
        
        // Middle button (bit 1)
        if (buttonMask & 0x02) != (previousState & 0x02) {
            if (buttonMask & 0x02) != 0 {
                postMouseEvent(type: .otherMouseDown, at: screenPoint)
            } else {
                postMouseEvent(type: .otherMouseUp, at: screenPoint)
            }
        }
        
        // Scroll wheel (bits 3 and 4)
        if (buttonMask & 0x08) != 0 { // Scroll up
            postScrollEvent(deltaY: 1, at: screenPoint)
        }
        if (buttonMask & 0x10) != 0 { // Scroll down
            postScrollEvent(deltaY: -1, at: screenPoint)
        }
    }
    
    private func handleMouseMovement(to screenPoint: NSPoint) {
        postMouseEvent(type: .mouseMoved, at: screenPoint)
    }
    
    private func postMouseEvent(type: NSEvent.EventType, at screenPoint: NSPoint) {
        guard let view = targetView, let window = view.window else { return }

		let windowPoint = window.convertFromScreen(NSRect(origin: screenPoint, size: .zero)).origin
        let viewPoint = view.convert(windowPoint, from: nil)
        
        let event = NSEvent.mouseEvent(
            with: type,
            location: windowPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown ? 1 : 0,
            pressure: type.rawValue >= NSEvent.EventType.leftMouseDown.rawValue && type.rawValue <= NSEvent.EventType.otherMouseDragged.rawValue ? 1.0 : 0.0
        )
        
        if let event = event {
            DispatchQueue.main.async {
                NSApp.sendEvent(event)
            }
        }
    }
    
    private func postScrollEvent(deltaY: CGFloat, at screenPoint: NSPoint) {
        guard let view = targetView, let window = view.window else { return }

		let windowPoint = window.convertFromScreen(NSRect(origin: screenPoint, size: .zero)).origin

		let event = NSEvent.mouseEvent(
            with: NSEvent.EventType.scrollWheel,
            location: windowPoint,
            modifierFlags: NSEvent.ModifierFlags(),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: NSGraphicsContext.current,
			eventNumber: 0,
			clickCount: Int(deltaY),
			pressure: 0
        )
        
        if let event = event {
            DispatchQueue.main.async {
                NSApp.sendEvent(event)
            }
        }
    }
    
    // MARK: - Keyboard Events
    
    func handleKeyEvent(key: UInt32, isDown: Bool) {
        guard let view = targetView, let window = view.window else { return }
        
        let (keyCode, modifiers, characters) = keyMapper.mapVNCKey(key)
        
        let eventType: NSEvent.EventType = isDown ? .keyDown : .keyUp
        
        let event = NSEvent.keyEvent(
            with: eventType,
            location: NSPoint.zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )
        
        if let event = event {
            DispatchQueue.main.async {
                NSApp.sendEvent(event)
            }
        }
    }
    
    // MARK: - Clipboard
    
    func handleClipboardText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
