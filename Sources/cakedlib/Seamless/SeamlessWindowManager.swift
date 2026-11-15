import AppKit
import CakeAgentLib
import Foundation

// MARK: - View

/// Shows a guest window's pixels and turns host input into protocol messages.
final class SeamlessSurfaceView: NSView {
	var onPointer: ((SeamlessHostMessage) -> Void)?
	var onKey: ((UInt32, Bool) -> Void)?
	var windowID: UInt32 = 0

	var guestCursor: NSCursor = .arrow {
		didSet {
			self.window?.invalidateCursorRects(for: self)
		}
	}

	private var heldModifiers = Set<UInt16>()

	override var isFlipped: Bool { true }
	override var acceptsFirstResponder: Bool { true }
	override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		self.wantsLayer = true
		self.layer?.contentsGravity = .resize
		self.layer?.isOpaque = false
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

	func show(_ image: CGImage?) {
		self.layer?.contents = image
	}

	override func updateTrackingAreas() {
		for area in trackingAreas { removeTrackingArea(area) }

		addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil))
		super.updateTrackingAreas()
	}

	override func resetCursorRects() {
		addCursorRect(bounds, cursor: guestCursor)
	}

	private func location(of event: NSEvent) -> (Float, Float) {
		let p = convert(event.locationInWindow, from: nil)

		return (Float(p.x), Float(p.y))
	}

	override func mouseEntered(with event: NSEvent) {
		let (x, y) = location(of: event)
		onPointer?(.pointerEnter(id: windowID, x: x, y: y))
	}

	override func mouseExited(with event: NSEvent) {
		onPointer?(.pointerLeave(id: windowID))
	}

	override func mouseMoved(with event: NSEvent) { motion(event) }
	override func mouseDragged(with event: NSEvent) { motion(event) }
	override func rightMouseDragged(with event: NSEvent) { motion(event) }
	override func otherMouseDragged(with event: NSEvent) { motion(event) }

	private func motion(_ event: NSEvent) {
		let (x, y) = location(of: event)
		onPointer?(.pointerMotion(id: windowID, x: x, y: y))
	}

	private func button(_ event: NSEvent, pressed: Bool) {
		let code: UInt32

		switch event.buttonNumber {
		case 0: code = SeamlessProtocol.buttonLeft
		case 1: code = SeamlessProtocol.buttonRight
		case 2: code = SeamlessProtocol.buttonMiddle
		default: code = 0x113 + UInt32(min(event.buttonNumber - 3, 4))  // BTN_SIDE, BTN_EXTRA, ...
		}

		// Make sure the guest knows where the pointer is before it sees the click.
		motion(event)
		onPointer?(.pointerButton(id: windowID, button: code, pressed: pressed))
	}

	override func mouseDown(with event: NSEvent) {
		self.window?.makeFirstResponder(self)
		button(event, pressed: true)
	}

	override func mouseUp(with event: NSEvent) { button(event, pressed: false) }
	override func rightMouseDown(with event: NSEvent) { button(event, pressed: true) }
	override func rightMouseUp(with event: NSEvent) { button(event, pressed: false) }
	override func otherMouseDown(with event: NSEvent) { button(event, pressed: true) }
	override func otherMouseUp(with event: NSEvent) { button(event, pressed: false) }

	override func scrollWheel(with event: NSEvent) {
		// AppKit's natural scrolling already flips the sign the way a Wayland client expects it inverted.
		let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10

		onPointer?(.pointerAxis(id: windowID, dx: Float(-event.scrollingDeltaX * scale), dy: Float(-event.scrollingDeltaY * scale)))
	}

	override func keyDown(with event: NSEvent) {
		// The guest compositor generates its own repeats from the held key.
		guard !event.isARepeat, let code = SeamlessKeyMap.evdev(forMacKeyCode: event.keyCode) else { return }

		onKey?(code, true)
	}

	override func keyUp(with event: NSEvent) {
		guard let code = SeamlessKeyMap.evdev(forMacKeyCode: event.keyCode) else { return }

		onKey?(code, false)
	}

	override func flagsChanged(with event: NSEvent) {
		guard SeamlessKeyMap.modifierKeyCodes.contains(event.keyCode), let code = SeamlessKeyMap.evdev(forMacKeyCode: event.keyCode) else { return }

		// The flags are the combined state of both keys of a pair, so track each physical key by toggling.
		if event.keyCode == 57 {
			// Caps lock only reports a change: send a full press.
			onKey?(code, true)
			onKey?(code, false)
		} else if heldModifiers.contains(event.keyCode) {
			heldModifiers.remove(event.keyCode)
			onKey?(code, false)
		} else {
			heldModifiers.insert(event.keyCode)
			onKey?(code, true)
		}
	}

	override func resignFirstResponder() -> Bool {
		// Release what is still held, otherwise the guest sees a stuck modifier.
		for keyCode in heldModifiers {
			if let code = SeamlessKeyMap.evdev(forMacKeyCode: keyCode) { onKey?(code, false) }
		}

		heldModifiers.removeAll()

		return super.resignFirstResponder()
	}
}

// MARK: - Window

private final class SeamlessPanel: NSPanel {
	override var canBecomeKey: Bool { false }
	override var canBecomeMain: Bool { false }
}

/// One guest window shown as a native one.
@MainActor
final class SeamlessWindowController: NSObject, NSWindowDelegate {
	let info: SeamlessWindowInfo
	let surface = SeamlessSurface()
	let view = SeamlessSurfaceView(frame: .zero)
	let window: NSWindow
	private(set) var hasContent = false
	private var scale120: UInt32
	private var sendToGuest: (SeamlessHostMessage) -> Void
	private var guestDestroyed = false
	private weak var parent: SeamlessWindowController?

	init(info: SeamlessWindowInfo, parent: SeamlessWindowController?, titlePrefix: String, scale120: UInt32, send: @escaping (SeamlessHostMessage) -> Void) {
		self.info = info
		self.scale120 = scale120
		self.sendToGuest = send
		self.parent = parent

		let rect = NSRect(x: 0, y: 0, width: 320, height: 200)

		if info.kind == .popup {
			let panel = SeamlessPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)

			panel.level = .popUpMenu
			panel.isOpaque = false
			panel.backgroundColor = .clear
			panel.hasShadow = true
			panel.hidesOnDeactivate = false
			self.window = panel
		} else {
			self.window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: true)
		}

		super.init()

		self.view.windowID = info.id
		self.view.onPointer = { send($0) }
		self.view.onKey = { code, pressed in send(.key(code: code, pressed: pressed)) }
		self.window.contentView = self.view
		self.window.isReleasedWhenClosed = false
		self.window.delegate = self
		self.window.acceptsMouseMovedEvents = true
		self.window.title = titlePrefix + info.title
		self.titlePrefix = titlePrefix
	}

	private var titlePrefix = ""

	private func logicalSize(width: Int, height: Int) -> NSSize {
		let k = 120.0 / Double(max(scale120, 1))

		return NSSize(width: (Double(width) * k).rounded(), height: (Double(height) * k).rounded())
	}

	func setTitle(_ title: String) {
		self.window.title = titlePrefix + title
	}

	func setHints(_ hints: SeamlessSizeHints) {
		if hints.minWidth > 0 || hints.minHeight > 0 {
			window.contentMinSize = NSSize(width: CGFloat(hints.minWidth), height: CGFloat(hints.minHeight))
		}

		if hints.maxWidth > 0 || hints.maxHeight > 0 {
			window.contentMaxSize = NSSize(
				width: hints.maxWidth > 0 ? CGFloat(hints.maxWidth) : CGFloat.greatestFiniteMagnitude,
				height: hints.maxHeight > 0 ? CGFloat(hints.maxHeight) : CGFloat.greatestFiniteMagnitude)
		}
	}

	func setCursor(_ shape: String) {
		view.guestCursor = SeamlessCursors.cursor(named: shape)
	}

	func setScale(_ scale120: UInt32) {
		self.scale120 = scale120
	}

	func apply(_ frame: SeamlessFrame) throws {
		try surface.apply(frame)
		view.show(surface.makeImage())

		let size = logicalSize(width: surface.width, height: surface.height)

		if !hasContent {
			hasContent = true
			window.setContentSize(size)
			place()
			window.orderFront(nil)

			if info.kind == .toplevel {
				window.makeKeyAndOrderFront(nil)
			}
		} else if !window.inLiveResize, view.bounds.size != size {
			// The guest picked another size (an app resizing itself): follow it, keeping the top-left corner.
			let top = window.frame.maxY
			let left = window.frame.minX

			window.setContentSize(size)
			window.setFrameTopLeftPoint(NSPoint(x: left, y: top))
		}
	}

	/// Popups open at their offset from the parent's content, toplevels cascade.
	private func place() {
		if info.kind == .popup, let parentWindow = parent?.window {
			let content = parentWindow.contentLayoutRect
			let origin = parentWindow.convertToScreen(NSRect(x: content.minX, y: content.minY, width: content.width, height: content.height))
			let height = window.frame.height
			let x = origin.minX + CGFloat(info.x)
			let y = origin.maxY - CGFloat(info.y) - height

			window.setFrameOrigin(NSPoint(x: x, y: y))
			parentWindow.addChildWindow(window, ordered: .above)
		} else {
			window.center()
		}
	}

	/// The guest destroyed the window: close without asking it again.
	func destroy() {
		guestDestroyed = true

		if let parentWindow = window.parent {
			parentWindow.removeChildWindow(window)
		}

		window.orderOut(nil)
		window.close()
	}

	// MARK: NSWindowDelegate

	func windowShouldClose(_ sender: NSWindow) -> Bool {
		if guestDestroyed { return true }

		// Let the application decide (unsaved changes...), it answers with windowDestroy.
		sendToGuest(.windowClose(id: info.id))

		return false
	}

	func windowDidResize(_ notification: Notification) {
		guard hasContent else { return }

		let size = view.bounds.size

		sendToGuest(.windowResize(id: info.id, width: UInt32(max(size.width.rounded(), 1)), height: UInt32(max(size.height.rounded(), 1))))
	}

	func windowDidBecomeKey(_ notification: Notification) {
		sendToGuest(.windowFocus(id: info.id, focused: true))
	}

	func windowDidResignKey(_ notification: Notification) {
		sendToGuest(.windowFocus(id: info.id, focused: false))
	}
}

enum SeamlessCursors {
	static func cursor(named name: String) -> NSCursor {
		switch name {
		case "text", "vertical-text": return .iBeam
		case "pointer": return .pointingHand
		case "crosshair": return .crosshair
		case "grab": return .openHand
		case "grabbing": return .closedHand
		case "not-allowed", "no-drop": return .operationNotAllowed
		case "ew-resize", "col-resize", "e-resize", "w-resize": return .resizeLeftRight
		case "ns-resize", "row-resize", "n-resize", "s-resize": return .resizeUpDown
		case "copy": return .dragCopy
		case "alias": return .dragLink
		case "context-menu": return .contextualMenu
		default: return .arrow
		}
	}
}

// MARK: - Manager

/// Owns the server and the native windows of one VM's guest compositor.
@MainActor
public final class SeamlessWindowManager: SeamlessServerDelegate {
	public static let maxWindows = 64

	private var server: SeamlessServer!
	private var session: SeamlessSession?
	private var windows: [UInt32: SeamlessWindowController] = [:]
	private let titlePrefix: String
	private let logger = Logger("SeamlessWindowManager")

	public var guestName: String?
	public var onSessionChange: ((Bool) -> Void)?

	/// - Parameters:
	///   - vmName: shown before every title, so a guest can't pass its windows off as a host application's.
	///   - socketPath: unix socket the guest's vsock connection is bridged to.
	public init(vmName: String, socketPath: String) {
		self.titlePrefix = "[\(vmName)] "
		self.server = SeamlessServer(socketPath: socketPath, delegate: self, delegateQueue: .main)
		self.server.outputScale120 = Self.currentScale120()
	}

	private static func currentScale120() -> UInt32 {
		UInt32(((NSScreen.main?.backingScaleFactor ?? 2) * 120).rounded())
	}

	public var socketPath: String { server.socketPath }
	public var windowCount: Int { windows.count }

	public func start() throws {
		try server.start()
	}

	public func stop() {
		server.stop()
		closeAllWindows()
	}

	private func closeAllWindows() {
		for controller in windows.values { controller.destroy() }

		windows.removeAll()
	}

	private func send(_ message: SeamlessHostMessage) {
		switch message {
		case .pointerMotion, .pointerAxis:
			break
		default:
			logger.trace("Seamless -> guest: \(message)")
		}

		session?.send(message)
	}

	// MARK: SeamlessServerDelegate

	public nonisolated func seamlessServer(_ server: SeamlessServer, sessionDidStart session: SeamlessSession, guestName: String) {
		MainActor.assumeIsolated {
			self.session = session
			self.guestName = guestName
			self.logger.info("Seamless: guest compositor \(guestName) connected")
			self.onSessionChange?(true)
		}
	}

	public nonisolated func seamlessServer(_ server: SeamlessServer, sessionDidEnd session: SeamlessSession) {
		MainActor.assumeIsolated {
			// A newer session may already have replaced it, keep that one's windows.
			guard self.session === session else { return }

			self.session = nil
			self.logger.info("Seamless: guest compositor disconnected")
			self.closeAllWindows()
			self.onSessionChange?(false)
		}
	}

	public nonisolated func seamlessServer(_ server: SeamlessServer, session: SeamlessSession, didReceive message: SeamlessGuestMessage) {
		MainActor.assumeIsolated {
			guard self.session === session else { return }

			self.handle(message)
		}
	}

	private func handle(_ message: SeamlessGuestMessage) {
		switch message {
		case .hello:
			break
		case .windowCreate(let info):
			guard windows[info.id] == nil, windows.count < Self.maxWindows else {
				logger.warn("Seamless: refusing window \(info.id) (duplicate or too many windows)")
				return
			}

			let parent = info.parentID != 0 ? windows[info.parentID] : nil

			if info.kind == .popup && parent == nil {
				logger.warn("Seamless: popup \(info.id) without a known parent")
				return
			}

			windows[info.id] = SeamlessWindowController(
				info: info, parent: parent, titlePrefix: titlePrefix, scale120: server.outputScale120,
				send: { [weak self] in self?.send($0) })
		case .windowTitle(let id, let title):
			windows[id]?.setTitle(title)
		case .windowAppID:
			break
		case .windowHints(let id, let hints):
			windows[id]?.setHints(hints)
		case .windowFrame(let frame):
			do {
				try windows[frame.windowID]?.apply(frame)
			} catch {
				logger.warn("Seamless: bad frame for window \(frame.windowID): \(error)")
			}
		case .windowDestroy(let id):
			if let controller = windows.removeValue(forKey: id) {
				controller.destroy()
			}
		case .cursor(let id, let shape):
			windows[id]?.setCursor(shape)
		}
	}
}
