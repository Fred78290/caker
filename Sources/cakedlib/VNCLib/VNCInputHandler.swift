import AppKit
import Carbon
import Foundation

extension NSView {
	func postEnterExitEvent(type: NSEvent.EventType, at viewPoint: NSPoint, modifierFlags: NSEvent.ModifierFlags, trackingNumber: Int) -> NSEvent? {
			return NSEvent.enterExitEvent(
				with: type,
				location: viewPoint,
				modifierFlags: modifierFlags,
				timestamp: ProcessInfo.processInfo.systemUptime,
				windowNumber: self.window?.windowNumber ?? 0,
				context: nil,
				eventNumber: Date.now.nanosecond,
				trackingNumber: trackingNumber,
				userData: nil
			)
	}

	func postMouseEvent(type: NSEvent.EventType, at viewPoint: NSPoint, modifierFlags: NSEvent.ModifierFlags) -> NSEvent? {
		return NSEvent.mouseEvent(
			with: type,
			location: viewPoint,
			modifierFlags: modifierFlags,
			timestamp: ProcessInfo.processInfo.systemUptime,
			windowNumber: self.window?.windowNumber ?? 0,
			context: nil,
			eventNumber: Date.now.nanosecond,
			clickCount: type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown ? 1 : 0,
			pressure: type.rawValue >= NSEvent.EventType.leftMouseDown.rawValue && type.rawValue <= NSEvent.EventType.otherMouseDragged.rawValue ? 1.0 : 0.0
		)
	}

	func postScrollEvent(deltaX: Int32, deltaY: Int32, at viewPoint: NSPoint, modifierFlags: NSEvent.ModifierFlags) -> NSEvent? {
		guard let event = CGEvent(scrollWheelEvent2Source: CGEventSource(stateID: .privateState), units: .pixel, wheelCount: 1, wheel1: deltaX, wheel2: deltaY, wheel3: 0) else {
			return nil
		}

		event.flags = modifierFlags.cgEventFlag
		event.location = CGPoint(x: viewPoint.x, y: viewPoint.y)
		event.timestamp = CGEventTimestamp(ProcessInfo.processInfo.systemUptime)
		event.setIntegerValueField(.mouseEventDeltaX, value: Int64(deltaX))
		event.setIntegerValueField(.mouseEventDeltaY, value: Int64(deltaY))

		return NSEvent(cgEvent: event)
	}
}

public class VNCInputHandler {
	private enum CurrentButton: Int {
		case none = 0
		case leftButton = 1
		case rightButton = 2
		case middleButton = 3
	}

	private enum ButtonState: Int {
		case none = 0
		case up = 1
		case down = 2
	}

	private weak var targetView: NSView!
	private var mouseButtonState: UInt8 = 0
	private var isDragging: Bool = false
	private var lastMousePosition = NSPoint.zero
	private let keyMapper = newKeyMapper()
	private var postEvent: Bool = false
	private var keyCode: UInt16 = 0
	private var modifiers: NSEvent.ModifierFlags = []
	private var characters: String = ""
	private var trackingNumber: Int = 0
	private let eventSource = CGEventSource(stateID: .privateState)

	// MARK: - First Responder
	@discardableResult
	private func ensureFirstResponder() -> Bool {
		guard let view = targetView else { return false }
		// If the view is not already first responder, ask the window to make it so
		if view.window?.firstResponder !== view {
			return view.window?.makeFirstResponder(view) ?? false
		}

		return false
	}

	init(targetView: NSView?) {
		self.targetView = targetView
	}

	// MARK: - Mouse Events

	func handlePointerEvent(x: Int, y: Int, buttonMask: UInt8) {
		guard let view = targetView else {
			return
		}
		// Ensure the view is first responder when pointer interaction begins
		ensureFirstResponder()

		// Convert VNC coordinates (origin top-left) to NSView (origin bottom-left)
		let viewBounds = view.bounds
		let nsPoint = NSPoint(x: CGFloat(x), y: viewBounds.height - CGFloat(y))
		let moved = nsPoint != lastMousePosition

		// Handle mouse buttons with move
		if handleMouseButtons(view, buttonMask: buttonMask, at: nsPoint, moved: moved) == false {
			if moved {
				// Handle mouse movement
				handleMouseMovement(view, to: nsPoint)
			}
		}

		lastMousePosition = nsPoint
	}

	private func prevDispatchEvent(_ event: NSEvent?, view: NSView, currentButton: CurrentButton, buttonState: ButtonState, moved: Bool) {
		if let event = event {
			if ensureFirstResponder() {
				view.window?.sendEvent(event)
			} else if event.type == .scrollWheel {
				view.scrollWheel(with: event)
			} else if moved {
				if buttonState == .down {
					if isDragging == false {
						switch currentButton {
						case .leftButton, .rightButton, .middleButton:
							isDragging = true
							view.mouseEntered(with: event)
						case .none:
							view.mouseMoved(with: event)
							break
						}
					} else {
						switch currentButton {
						case .leftButton:
							view.mouseDragged(with: event)
						case .rightButton:
							view.rightMouseDragged(with: event)
						case .middleButton:
							view.otherMouseDragged(with: event)
						case .none:
							view.mouseExited(with: event)
							break
						}
					}
				} else if buttonState == .up {
					if isDragging {
						isDragging = false

						switch currentButton {
						case .leftButton, .rightButton, .middleButton:
							view.mouseExited(with: event)
						case .none:
							view.mouseMoved(with: event)
							break
						}
					} else {
						view.mouseMoved(with: event)
					}
				}

			} else if buttonState == .down {
				switch currentButton {
				case .leftButton:
					view.mouseDown(with: event)
				case .rightButton:
					view.rightMouseDown(with: event)
				case .middleButton:
					view.otherMouseDown(with: event)
				case .none:
					break
				}
			} else if buttonState == .up {
				if isDragging {
					switch currentButton {
					case .leftButton:
						view.mouseUp(with: event)
					case .rightButton:
						view.rightMouseUp(with: event)
					case .middleButton:
						view.otherMouseUp(with: event)
					case .none:
						break
					}
				} else {
					switch currentButton {
					case .leftButton:
						view.mouseUp(with: event)
					case .rightButton:
						view.rightMouseUp(with: event)
					case .middleButton:
						view.otherMouseUp(with: event)
					case .none:
						break
					}
				}
			}
		}
	}

	private func dispatchEvent(_ event: NSEvent?, view: NSView) {
		if let event = event {
			if ensureFirstResponder() {
				view.window?.sendEvent(event)
			} else {
				switch event.type {
				case .scrollWheel:
					view.scrollWheel(with: event)
				case .mouseEntered:
					isDragging = true
					view.mouseEntered(with: event)
				case .mouseExited:
					isDragging = false
					view.mouseExited(with: event)

				case .leftMouseDragged:
					view.mouseDragged(with: event)
				case .rightMouseDragged:
					view.rightMouseDragged(with: event)
				case .otherMouseDragged:
					view.otherMouseDragged(with: event)

				case .leftMouseDown:
					view.mouseDown(with: event)
				case .rightMouseDown:
					view.rightMouseDown(with: event)
				case .otherMouseDown:
					view.otherMouseDown(with: event)

				case .leftMouseUp:
					view.mouseUp(with: event)
				case .rightMouseUp:
					view.rightMouseUp(with: event)
				case .otherMouseUp:
					view.otherMouseUp(with: event)
				default:
					break
				}
			}
		}
	}
	private func handleMouseButtons(_ view: NSView, buttonMask: UInt8, at viewPoint: NSPoint, moved: Bool) -> Bool {
		let previousState = mouseButtonState
		var buttonEvent = false

		mouseButtonState = buttonMask

		// Left button (bit 0)
		if (buttonMask & 0x01) != (previousState & 0x01) {
			buttonEvent = true

			if moved {
				if (buttonMask & 0x01) != 0 {
					dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				} else {
					dispatchEvent(view.postEnterExitEvent(type: .mouseExited, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				}
			} else {
				if (buttonMask & 0x01) != 0 {
					dispatchEvent(view.postMouseEvent(type: .leftMouseDown, at: viewPoint, modifierFlags: self.modifiers), view: view)
				} else {
					dispatchEvent(view.postMouseEvent(type: .leftMouseUp, at: viewPoint, modifierFlags: self.modifiers), view: view)
				}
			}
		} else if (buttonMask & 0x01) != 0 {
			buttonEvent = true

			if isDragging {
				dispatchEvent(view.postMouseEvent(type: .leftMouseDragged, at: viewPoint, modifierFlags: self.modifiers), view: view)
			} else {
				dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
			}
		}

		// Right button (bit 2)
		if (buttonMask & 0x04) != (previousState & 0x04) {
			buttonEvent = true

			if moved {
				if (buttonMask & 0x04) != 0 {
					dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				} else {
					dispatchEvent(view.postEnterExitEvent(type: .mouseExited, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				}
			} else {
				if (buttonMask & 0x04) != 0 {
					dispatchEvent(view.postMouseEvent(type: .rightMouseDown, at: viewPoint, modifierFlags: self.modifiers), view: view)
				} else {
					dispatchEvent(view.postMouseEvent(type: .rightMouseUp, at: viewPoint, modifierFlags: self.modifiers), view: view)
				}
			}
		} else if (buttonMask & 0x04) != 0 {
			buttonEvent = true

			if isDragging {
				dispatchEvent(view.postMouseEvent(type: .rightMouseDragged, at: viewPoint, modifierFlags: self.modifiers), view: view)
			} else {
				dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
			}
		}

		// Middle button (bit 1)
		if (buttonMask & 0x02) != (previousState & 0x02) {
			buttonEvent = true

			if moved {
				if (buttonMask & 0x02) != 0 {
					dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				} else {
					dispatchEvent(view.postEnterExitEvent(type: .mouseExited, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
				}
			} else {
				if (buttonMask & 0x02) != 0 {
					dispatchEvent(view.postMouseEvent(type: .otherMouseDown, at: viewPoint, modifierFlags: self.modifiers), view: view)
				} else {
					dispatchEvent(view.postMouseEvent(type: .otherMouseUp, at: viewPoint, modifierFlags: self.modifiers), view: view)
				}
			}
		} else if (buttonMask & 0x02) != 0 {
			buttonEvent = true

			if isDragging {
				dispatchEvent(view.postMouseEvent(type: .otherMouseDragged, at: viewPoint, modifierFlags: self.modifiers), view: view)
			} else {
				dispatchEvent(view.postEnterExitEvent(type: .mouseEntered, at: viewPoint, modifierFlags: self.modifiers, trackingNumber: self.trackingNumber), view: view)
			}
		}

		// Scroll wheel (bits 3 and 4)
		if (buttonMask & 0x08) != 0 {  // Scroll up
			dispatchEvent(view.postScrollEvent(deltaX: 0, deltaY: 1, at: viewPoint, modifierFlags: self.modifiers), view: view)
		}

		if (buttonMask & 0x10) != 0 {  // Scroll down
			dispatchEvent(view.postScrollEvent(deltaX: 0, deltaY: -1, at: viewPoint, modifierFlags: self.modifiers), view: view)
		}

		// Scroll wheel (bits 5 and 6)
		if (buttonMask & 0x20) != 0 {  // Scroll up
			dispatchEvent(view.postScrollEvent(deltaX: 1, deltaY: 0, at: viewPoint, modifierFlags: self.modifiers), view: view)
		}

		if (buttonMask & 0x40) != 0 {  // Scroll down
			dispatchEvent(view.postScrollEvent(deltaX: -1, deltaY: 0, at: viewPoint, modifierFlags: self.modifiers), view: view)
		}

		return buttonEvent
	}

	private func handleMouseMovement(_ view: NSView, to viewPoint: NSPoint) {
		if let event = view.postMouseEvent(type: .mouseMoved, at: viewPoint, modifierFlags: self.modifiers) {
			view.mouseMoved(with: event)
		}
	}

	// MARK: - Keyboard Events

	func handleKeyEvent(key: UInt32, isDown: Bool) {
		guard let view = targetView else { return }
		// Ensure the view is first responder before delivering key events
		var keySym = key

		if keySym == Keysyms.XK_ISO_Level3_Shift {
			keySym = Keysyms.XK_Meta_L
		}

		if keySym == Keysyms.XK_Super_L {
			keySym = Keysyms.XK_Alt_R
		}

		ensureFirstResponder()

		keyMapper.mapVNCKey(keySym, isDown: isDown) { keyCode, modifiers, characters, charactersIgnoringModifiers in
			guard let keyboardEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: isDown) else {
				return
			}

			self.modifiers = modifiers

			guard let event = NSEvent.keyEvent(with: keyboardEvent.type == .flagsChanged ? .flagsChanged : (isDown ? .keyDown : .keyUp), location: lastMousePosition, modifierFlags: self.modifiers, timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: self.targetView.window?.windowNumber ?? 0, context: nil, characters: characters ?? "", charactersIgnoringModifiers: charactersIgnoringModifiers ?? "", isARepeat: false, keyCode: keyCode) else {
				return
			}

			if event.type == .flagsChanged {
				view.flagsChanged(with: event)
			} else if isDown {
				view.keyDown(with: event)
			} else {
				view.keyUp(with: event)
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

