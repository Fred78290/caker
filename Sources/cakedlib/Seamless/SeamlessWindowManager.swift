import AppKit
import CakeAgentLib
import Foundation
import UniformTypeIdentifiers

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
	private var heldKeys = Set<UInt32>()
	/// The Command keys held (54 right, 55 left). Command is what Mac users press for copy, paste, select all..., which a
	/// Linux application expects as Control: it is sent as Control once a key goes with it, and as the Super key (what
	/// it is on the guest's keyboard) only when it is pressed and released on its own.
	private var heldCommandKeys = Set<UInt16>()
	private var commandActsAsControl = false
	private var commandAloneKey: UInt16?
	/// Whether the guest currently sees the left Control key down. The physical left Control key (59) and the Control
	/// synthesized for Command share that one evdev key, so it is down while either holds it and released only once both let go.
	private var leftControlDown = false
	private static let evdevLeftControl: UInt32 = 29
	private static let physicalLeftControl: UInt16 = 59

	private func syncLeftControl() {
		let wanted = heldModifiers.contains(Self.physicalLeftControl) || commandActsAsControl

		guard wanted != leftControlDown else { return }

		leftControlDown = wanted
		onKey?(Self.evdevLeftControl, wanted)
	}

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
		// AppKit reports the direction the content moves (natural scrolling included), Wayland the direction of the scroll: opposite signs.
		let dx = Float(-event.scrollingDeltaX)
		let dy = Float(-event.scrollingDeltaY)

		guard event.hasPreciseScrollingDeltas else {
			// A mouse wheel: whole notches, the guest turns them into discrete steps.
			if dx != 0 || dy != 0 { onPointer?(.pointerAxis(id: windowID, dx: dx, dy: dy, source: .wheel)) }
			return
		}

		// A trackpad. The momentum after the fingers left is dropped: the stop below lets the guest's toolkit do its own kinetic scrolling.
		guard event.momentumPhase.isEmpty else { return }

		if dx != 0 || dy != 0 { onPointer?(.pointerAxis(id: windowID, dx: dx, dy: dy, source: .continuous)) }
		if event.phase.contains(.ended) || event.phase.contains(.cancelled) { onPointer?(.pointerAxis(id: windowID, dx: 0, dy: 0, source: .stop)) }
	}

	override func keyDown(with event: NSEvent) {
		// The guest compositor generates its own repeats from the held key.
		guard !event.isARepeat, let code = SeamlessKeyMap.evdev(forMacKeyCode: event.keyCode) else { return }

		if !heldCommandKeys.isEmpty {
			// Command + key: the guest sees Control + key, unless a Control key is already down.
			commandAloneKey = nil

			if !commandActsAsControl && !heldModifiers.contains(62) {
				commandActsAsControl = true
				syncLeftControl()
			}
		}

		heldKeys.insert(code)
		onKey?(code, true)
	}

	override func keyUp(with event: NSEvent) {
		guard let code = SeamlessKeyMap.evdev(forMacKeyCode: event.keyCode) else { return }

		heldKeys.remove(code)
		onKey?(code, false)
	}

	private func commandChanged(_ keyCode: UInt16, code: UInt32) {
		if heldCommandKeys.contains(keyCode) {
			heldCommandKeys.remove(keyCode)

			if heldCommandKeys.isEmpty {
				if commandActsAsControl {
					commandActsAsControl = false
					syncLeftControl()
				} else if let alone = commandAloneKey, let superCode = SeamlessKeyMap.evdev(forMacKeyCode: alone) {
					// Pressed and released with nothing between: the Super key, as it would have been before.
					onKey?(superCode, true)
					onKey?(superCode, false)
				}

				commandAloneKey = nil
			}
		} else {
			if heldCommandKeys.isEmpty {
				commandAloneKey = keyCode
			}

			heldCommandKeys.insert(keyCode)
		}
	}

	override func flagsChanged(with event: NSEvent) {
		guard SeamlessKeyMap.modifierKeyCodes.contains(event.keyCode), let code = SeamlessKeyMap.evdev(forMacKeyCode: event.keyCode) else { return }

		if event.keyCode == 54 || event.keyCode == 55 {
			commandChanged(event.keyCode, code: code)

			return
		}

		// The flags are the combined state of both keys of a pair, so track each physical key by toggling.
		if event.keyCode == Self.physicalLeftControl {
			// Shares its evdev key with the Control synthesized for Command: only report the combined state.
			if heldModifiers.contains(event.keyCode) {
				heldModifiers.remove(event.keyCode)
			} else {
				heldModifiers.insert(event.keyCode)
			}

			syncLeftControl()
		} else if event.keyCode == 57 {
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

	/// Releases what is still held, otherwise the guest sees a stuck key or modifier: a release that happens in
	/// another application never reaches this view, and the compositor would give the pressed keys to the next window.
	func releaseHeldKeys() {
		commandActsAsControl = false
		commandAloneKey = nil
		heldCommandKeys.removeAll()
		heldModifiers.remove(Self.physicalLeftControl)
		syncLeftControl()

		for keyCode in heldModifiers {
			if let code = SeamlessKeyMap.evdev(forMacKeyCode: keyCode) { onKey?(code, false) }
		}

		heldModifiers.removeAll()

		for code in heldKeys {
			onKey?(code, false)
		}

		heldKeys.removeAll()
	}

	override func resignFirstResponder() -> Bool {
		releaseHeldKeys()

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
	/// Called when the window becomes the key window, once the guest knows.
	var onFocus: (() -> Void)?

	private func logicalSize(width: Int, height: Int) -> NSSize {
		let k = 120.0 / Double(max(scale120, 1))

		return NSSize(width: (Double(width) * k).rounded(), height: (Double(height) * k).rounded())
	}

	func setTitle(_ title: String) {
		self.window.title = titlePrefix + title
	}

	func setHints(_ hints: SeamlessSizeHints) {
		// Every update applies: a guest that drops a limit sends zeros, which mean "unconstrained".
		window.contentMinSize = NSSize(width: CGFloat(hints.minWidth), height: CGFloat(hints.minHeight))
		window.contentMaxSize = NSSize(
			width: hints.maxWidth > 0 ? CGFloat(hints.maxWidth) : CGFloat.greatestFiniteMagnitude,
			height: hints.maxHeight > 0 ? CGFloat(hints.maxHeight) : CGFloat.greatestFiniteMagnitude)
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
		// After the focus: the guest hands the clipboard to the focused user's compositor.
		onFocus?()
	}

	func windowDidResignKey(_ notification: Notification) {
		// Before the focus loss, while the guest still sends them to this window. The window stays the first responder
		// when it loses key, so the view's own resignFirstResponder does not run.
		view.releaseHeldKeys()
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
	private let displayMode: VMRunHandler.DisplayMode
	private var applicationInited = false
	private var pasteboardChangeCount = NSPasteboard.general.changeCount
	private var clipboardTimer: Timer?

	/// A process that runs the VM without a UI (`vmrun --vnc`, what a background start uses) shows the guest's windows
	/// too: it has no application of its own, so the manager makes it an accessory one (no Dock icon, no menu bar),
	/// and `vmrun` runs its event loop. Caker.app, `vmrun --ui`/`--all` and `cakectl seamless` already have theirs.
	private var runsWithoutUI: Bool {
		self.displayMode == .none || self.displayMode == .vnc
	}

	public var guestName: String?
	public var onSessionChange: ((Bool) -> Void)?

	/// - Parameters:
	///   - vmName: shown before every title, so a guest can't pass its windows off as a host application's.
	///   - socketPath: unix socket the guest's vsock connection is bridged to.
	public init(vmName: String, displayMode: VMRunHandler.DisplayMode, socketPath: String) {
		self.titlePrefix = "[\(vmName)] "
		self.displayMode = displayMode
		self.server = SeamlessServer(socketPath: socketPath, delegate: self, delegateQueue: .main)
		self.server.outputScale120 = Self.currentScale120()
	}

	/// A manager that listens on no socket: the guest's stream comes from elsewhere and is handed over with
	/// `attach(fd:)`, like the one a gRPC tunnel brings from a `caked` on another host.
	public convenience init(vmName: String, displayMode: VMRunHandler.DisplayMode) {
		self.init(vmName: vmName, displayMode: displayMode, socketPath: "")
	}

	/// Serves the guest compositor connection on `fd`, an already established stream socket (the manager owns it).
	public func attach(fd: Int32) {
		self.prepareApplication()
		server.attach(fd: fd)
	}

	/// Windows need an `NSApplication` before the first one is made, and a guest can connect as soon as the VM runs.
	private func prepareApplication() {
		guard self.applicationInited == false else { return }

		self.applicationInited = true

		if self.runsWithoutUI {
			NSApplication.shared.setActivationPolicy(.accessory)
		}
	}

	/// An accessory application is never active by itself, so a window the guest opens would stay behind whatever
	/// else is in front: the user just started that application, bring it forward like any new window.
	private func activateForNewWindow() {
		guard self.runsWithoutUI else { return }

		NSApplication.shared.activate(ignoringOtherApps: true)
	}

	private static func currentScale120() -> UInt32 {
		UInt32(((NSScreen.main?.backingScaleFactor ?? 2) * 120).rounded())
	}

	public var socketPath: String { server.socketPath }
	public var windowCount: Int { windows.count }

	public func start() throws {
		self.prepareApplication()
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

	/// `session` is the one the window was created by: what the user does in a window never reaches another guest connection.
	private func send(_ message: SeamlessHostMessage, via session: SeamlessSession?) {
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
			// A new session while the previous one has not ended yet (its end callback comes later and finds it
			// replaced): its windows go now, so the new guest can reuse their ids and nothing of the old one is
			// left to receive the new guest's frames.
			if let previous = self.session, previous !== session {
				self.closeAllWindows()
			}

			self.session = session
			self.guestName = guestName
			self.startClipboardTimer()
			self.logger.info("Seamless: guest compositor \(guestName) connected")
			self.onSessionChange?(true)
		}
	}

	public nonisolated func seamlessServer(_ server: SeamlessServer, sessionDidEnd session: SeamlessSession) {
		MainActor.assumeIsolated {
			// A newer session may already have replaced it, keep that one's windows.
			guard self.session === session else { return }

			self.session = nil
			self.stopClipboardTimer()
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
		case .windowFrame(let frame):
			// Pixels: never print them.
			logger.trace("Seamless <- guest: frame for window \(frame.windowID)")
		default:
			logger.trace("Seamless <- guest: \(message)")
		}

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

			let controller = SeamlessWindowController(
				info: info, parent: parent, titlePrefix: titlePrefix, scale120: server.outputScale120,
				send: { [weak self, weak owner = self.session] in self?.send($0, via: owner) })
			controller.onFocus = { [weak self] in self?.syncClipboardToGuest() }
			windows[info.id] = controller

			// Nothing is shown yet: the first valid frame sizes, places and shows the window (and activates the app
			// when there is no UI), so a late or invalid first frame never leaves an empty window on screen.

		case .windowTitle(let id, let title):
			windows[id]?.setTitle(title)
		case .windowAppID:
			break
		case .windowHints(let id, let hints):
			windows[id]?.setHints(hints)
		case .windowFrame(let frame):
			do {
				let controller = windows[frame.windowID]
				let isFirstFrame = controller?.hasContent == false

				try controller?.apply(frame)

				if isFirstFrame, controller?.info.kind == .toplevel {
					self.activateForNewWindow()
				}
			} catch {
				logger.warn("Seamless: bad frame for window \(frame.windowID): \(error)")
			}
		case .windowDestroy(let id):
			if let controller = windows.removeValue(forKey: id) {
				controller.destroy()
			}
		case .cursor(let id, let shape):
			windows[id]?.setCursor(shape)
		case .clipboard(let text):
			self.setHostClipboard(text)
		case .clipboardItems(let items):
			self.setHostClipboard(items)
		}
	}

	// MARK: Clipboard

	/// Pasteboard types a password manager (or any application) puts on what it copies so that it isn't kept or shared.
	private static let privatePasteboardTypes = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"]

	/// Sets the host's clipboard to the guest's selection. The change count it gives is remembered: it is the guest's own text,
	/// not a change to send back.
	private func setHostClipboard(_ text: String) {
		let pasteboard = NSPasteboard.general

		guard !text.isEmpty, pasteboard.string(forType: .string) != text else { return }

		pasteboard.clearContents()

		if !pasteboard.setString(text, forType: .string) {
			self.logger.warn("Seamless: unable to set the clipboard of the host")
		}

		self.pasteboardChangeCount = pasteboard.changeCount
		self.logger.debug("Seamless: the guest's clipboard (\(text.utf8.count) bytes) is now the host's")
	}

	/// Sets the host's clipboard to what the guest's selection holds, like `setHostClipboard` does for text: every item whose
	/// MIME type maps to a pasteboard type the host shares (text, images, PDF), the others are left out.
	private func setHostClipboard(_ items: [SeamlessClipboardItem]) {
		let entries = Self.pasteboardEntries(for: items)

		guard !entries.isEmpty else { return }

		let pasteboard = NSPasteboard.general

		guard !entries.allSatisfy({ pasteboard.data(forType: $0.type) == $0.data }) else { return }

		pasteboard.clearContents()

		for entry in entries {
			let done = entry.type == .string ? pasteboard.setString(String(decoding: entry.data, as: UTF8.self), forType: .string) : pasteboard.setData(entry.data, forType: entry.type)

			if !done {
				self.logger.warn("Seamless: unable to set \(entry.type.rawValue) on the clipboard of the host")
			}
		}

		self.pasteboardChangeCount = pasteboard.changeCount
		self.logger.debug("Seamless: the guest's clipboard (\(entries.map { "\($0.type.rawValue) \($0.data.count)" }.joined(separator: ", "))) is now the host's")
	}

	/// A type the host shares in both directions: text, images and PDF. Not executables, archives, file references.
	private static func isSharedType(_ type: UTType) -> Bool {
		!type.isDynamic && (type.conforms(to: .text) || type.conforms(to: .image) || type.conforms(to: .pdf))
	}

	/// The MIME type of a pasteboard type, nil when it is not shared (or has no MIME type). Plain text is always UTF-8.
	static func mimeType(forPasteboardType type: NSPasteboard.PasteboardType) -> String? {
		if type == .string { return "text/plain;charset=utf-8" }
		guard let uttype = UTType(type.rawValue), Self.isSharedType(uttype), let mime = uttype.preferredMIMEType?.lowercased(), SeamlessClipboardItem.isValidMIME(mime) else { return nil }

		return mime
	}

	/// The pasteboard type for a MIME type (its parameters are ignored), nil when it is not shared.
	static func pasteboardType(forMIME mime: String) -> NSPasteboard.PasteboardType? {
		let base = mime.lowercased().split(separator: ";").first.map(String.init) ?? ""

		if base == "text/plain" { return .string }
		guard let uttype = UTType(mimeType: base), Self.isSharedType(uttype) else { return nil }

		return NSPasteboard.PasteboardType(uttype.identifier)
	}

	/// What goes on the pasteboard for the items of the guest: one entry per pasteboard type, the first item of a type wins.
	static func pasteboardEntries(for items: [SeamlessClipboardItem]) -> [(type: NSPasteboard.PasteboardType, data: Data)] {
		var entries: [(type: NSPasteboard.PasteboardType, data: Data)] = []

		for item in items where !item.data.isEmpty {
			guard let type = Self.pasteboardType(forMIME: item.mime), !entries.contains(where: { $0.type == type }) else { continue }

			entries.append((type, item.data))
		}

		return entries
	}

	/// The items of a pasteboard: its text first, then every other type that has a shared MIME type, one item per MIME type
	/// and within `maxClipboardItems` and `maxClipboardTotalBytes`. A TIFF (what most applications put there) is sent as a PNG,
	/// what the guest takes, unless the pasteboard has one.
	static func clipboardItems(from pasteboard: NSPasteboard) -> [SeamlessClipboardItem] {
		var items: [SeamlessClipboardItem] = []
		var seen = Set<String>()
		var total = 0

		func add(_ mime: String, _ data: Data) {
			let base = mime.split(separator: ";").first.map(String.init) ?? mime

			guard !data.isEmpty, items.count < SeamlessProtocol.maxClipboardItems, total + data.count <= SeamlessProtocol.maxClipboardTotalBytes, seen.insert(base).inserted else { return }

			items.append(SeamlessClipboardItem(mime: mime, data: data))
			total += data.count
		}

		if let text = pasteboard.string(forType: .string), !text.isEmpty {
			add("text/plain;charset=utf-8", Data(text.utf8))
		}

		var tiff: Data?

		for type in pasteboard.types ?? [] where type != .string {
			if type == .tiff {
				tiff = pasteboard.data(forType: .tiff)
			} else if let mime = Self.mimeType(forPasteboardType: type), !seen.contains(mime), let data = pasteboard.data(forType: type) {
				add(mime, data)
			}
		}

		if !seen.contains("image/png"), let tiff, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
			add("image/png", png)
		}

		return items
	}

	/// Sends the host's clipboard to the guest when it changed since it was last seen (either way): every shared type of it
	/// (only its text for a guest on protocol 3). Never what is marked private.
	func syncClipboardToGuest() {
		guard let session, session.negotiatedVersion >= SeamlessProtocol.clipboardVersion else { return }

		let pasteboard = NSPasteboard.general

		guard pasteboard.changeCount != self.pasteboardChangeCount else { return }

		self.pasteboardChangeCount = pasteboard.changeCount

		let types = Set((pasteboard.types ?? []).map(\.rawValue))

		guard types.isDisjoint(with: Self.privatePasteboardTypes) else { return }

		if session.negotiatedVersion >= SeamlessProtocol.clipboardItemsVersion {
			let items = Self.clipboardItems(from: pasteboard)

			if !items.isEmpty {
				self.send(.clipboardItems(items), via: session)
			}

			return
		}

		if let text = pasteboard.string(forType: .string), !text.isEmpty, text.utf8.count <= SeamlessProtocol.maxClipboardBytes {
			self.send(.clipboard(text: text), via: session)
		}
	}

	/// The clipboard follows the focus (a window becoming key), and changes made while the application is in front (in
	/// another window of it, or by a menu) are picked up here: there is no notification for the pasteboard.
	private func startClipboardTimer() {
		guard self.clipboardTimer == nil else { return }

		self.clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
			MainActor.assumeIsolated {
				guard let self, NSApplication.shared.isActive, NSApplication.shared.keyWindow != nil else { return }

				self.syncClipboardToGuest()
			}
		}
	}

	private func stopClipboardTimer() {
		self.clipboardTimer?.invalidate()
		self.clipboardTimer = nil
	}
}
