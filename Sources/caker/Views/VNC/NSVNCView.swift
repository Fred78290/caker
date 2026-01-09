//
//  NSVNCView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 10/08/2025.
//

import AppKit
import Carbon
import Cocoa
import RoyalVNCKit

class NSVNCView: NSView {
	private let document: VirtualMachineDocument
	private let connection: VNCConnection
	private var accumulatedScrollDeltaX: CGFloat = 0
	private var accumulatedScrollDeltaY: CGFloat = 0
	private var scrollStep: CGFloat = 12
	private var lastModifierFlags: NSEvent.ModifierFlags = []
	private var displayLink: CADisplayLink?
	private var trackingArea: NSTrackingArea?
	private var previousHotKeyMode: UnsafeMutableRawPointer?
	private var didResizeFramebuffer: Bool = false
	private var liveViewResize: Bool = false

	private let checkVNCReconfigurationTimeoutPeriod: Double = 0.250
	private var checkVNCReconfigurationTimeoutAttempts: Int = 20
	private var cancelWaitVNCReconfiguration: DispatchWorkItem?

	var isLiveViewResize: Bool {
		return self.liveViewResize
	}

	private var framebufferSize: CGSize {
		self.connection.framebuffer!.cgSize
	}

	private var settings: VNCConnection.Settings {
		self.connection.settings
	}

	private var currentCursor: NSCursor {
		didSet {
			resetCursorRects()
		}
	}

	private var scaleRatio: CGFloat {
		let containerBounds = bounds
		let fbSize = framebufferSize

		guard containerBounds.width > 0, containerBounds.height > 0, fbSize.width > 0, fbSize.height > 0 else {
			return 1
		}

		let targetAspectRatio = containerBounds.width / containerBounds.height
		let fbAspectRatio = fbSize.width / fbSize.height
		let ratio: CGFloat

		if fbAspectRatio >= targetAspectRatio {
			ratio = containerBounds.width / framebufferSize.width
		} else {
			ratio = containerBounds.height / framebufferSize.height
		}

		// Only allow downscaling, no upscaling
		guard ratio < 1 else {
			return 1
		}

		return ratio
	}

	private var contentRect: CGRect {
		let containerBounds = bounds
		let scale = scaleRatio
		var rect = CGRect(x: 0, y: 0, width: framebufferSize.width * scale, height: framebufferSize.height * scale)

		if rect.size.width < containerBounds.size.width {
			rect.origin.x = (containerBounds.size.width - rect.size.width) / 2.0
		}

		if rect.size.height < containerBounds.size.height {
			rect.origin.y = (containerBounds.size.height - rect.size.height) / 2.0
		}

		return rect
	}

	public override var canBecomeKeyView: Bool {
		true
	}

	public override var acceptsFirstResponder: Bool {
		true
	}

	public init(frame frameRect: CGRect, document: VirtualMachineDocument) {
		self.document = document
		self.connection = document.connection
		self.currentCursor = VNCCursor.empty.nsCursor

		super.init(frame: frameRect)

		self.wantsLayer = true
		self.translatesAutoresizingMaskIntoConstraints = false
		self.autoresizingMask = [.width, .height]

		guard let layer = layer else {
			fatalError("CAFramebufferView failed to get layer")
		}

		// Set some properties that might(!) boost performance a bit
		layer.drawsAsynchronously = true
		layer.isOpaque = true
		layer.masksToBounds = false
		layer.allowsEdgeAntialiasing = false
		layer.backgroundColor = .clear

		layer.contentsScale = 1
		layer.contentsGravity = .center
		layer.contentsFormat = .RGBA8Uint

		layer.minificationFilter = .trilinear
		layer.magnificationFilter = .trilinear

		frameSizeDidChange(frameRect.size)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		removeDisplayLink()
		deregisterHotKeys()
	}

	public override func viewDidMoveToWindow() {
		addDisplayLink()
	}

	public override func viewWillStartLiveResize() {
		self.liveViewResize = true
		self.layer?.contentsGravity = .resize
		if let blurred = self.image().blurred() {
			self.updateImage(blurred.cgImage, animated: true, duration: 0.2)
		}
	}

	override func viewDidEndLiveResize() {
		self.liveViewResize = false
		self.startWaitVNCReconfiguration()
		self.document.setScreenSize(.init(size: self.bounds.size))
	}

	override func viewWillMove(toWindow newWindow: NSWindow?) {
		self.stopWaitVNCReconfiguration()
		super.viewWillMove(toWindow: newWindow)
	}

	func removeDisplayLink() {
		guard settings.useDisplayLink, let displayLink = self.displayLink else {
			return
		}

		displayLink.remove(from: .current, forMode: .default)

		self.displayLink = nil
	}

	func addDisplayLink() {
		guard settings.useDisplayLink else {
			return
		}

		removeDisplayLink()

		guard let window, let screen = window.screen ?? NSScreen.main else {
			return
		}

		let displayLink = screen.displayLink(target: self, selector: #selector(displayLinkDidUpdate))

		self.displayLink = displayLink

		displayLink.add(to: .current, forMode: .default)
	}

	public override func updateTrackingAreas() {
		if let trackingArea {
			removeTrackingArea(trackingArea)
		}

		let newTrackingArea = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved], owner: self, userInfo: nil)

		self.trackingArea = newTrackingArea
		self.addTrackingArea(newTrackingArea)
	}

	@discardableResult
	public override func becomeFirstResponder() -> Bool {
		if window?.isKeyWindow ?? false {
			registerHotKeys()
		}

		return true
	}

	public override func resignFirstResponder() -> Bool {
		deregisterHotKeys()

		return true
	}

	public override func resetCursorRects() {
		discardCursorRects()

		addCursorRect(visibleRect, cursor: currentCursor)
	}

	public override var frame: NSRect {
		get {
			super.frame
		}
		set {
			super.frame = newValue

			frameSizeDidChange(newValue.size)
		}
	}

	public override func mouseMoved(with event: NSEvent) {
		handleMouseMoved(with: event)
	}

	public override func mouseDown(with event: NSEvent) {
		handleMouseDown(with: event)
	}

	public override func mouseDragged(with event: NSEvent) {
		handleMouseDragged(with: event)
	}

	public override func mouseUp(with event: NSEvent) {
		handleMouseUp(with: event)
	}

	public override func rightMouseDown(with event: NSEvent) {
		handleRightMouseDown(with: event)
	}

	public override func rightMouseDragged(with event: NSEvent) {
		handleRightMouseDragged(with: event)
	}

	public override func rightMouseUp(with event: NSEvent) {
		handleRightMouseUp(with: event)
	}

	public override func otherMouseDown(with event: NSEvent) {
		handleOtherMouseDown(with: event)
	}

	public override func otherMouseUp(with event: NSEvent) {
		handleOtherMouseUp(with: event)
	}

	public override func otherMouseDragged(with event: NSEvent) {
		handleOtherMouseDragged(with: event)
	}

	public override func scrollWheel(with event: NSEvent) {
		handleScrollWheel(with: event)
	}

	public override func keyDown(with event: NSEvent) {
		handleKeyDown(with: event)
	}

	public override func keyUp(with event: NSEvent) {
		handleKeyUp(with: event)
	}

	public override func flagsChanged(with event: NSEvent) {
		handleFlagsChanged(with: event)
	}

	public override func performKeyEquivalent(with event: NSEvent) -> Bool {
		return handlePerformKeyEquivalent(with: event)
	}
}

extension NSVNCView {
	func connection(_ connection: VNCConnection, didResizeFramebuffer framebuffer: VNCFramebuffer) {
		self.didResizeFramebuffer = true
		self.stopWaitVNCReconfiguration()
	}

	func connection(_ connection: VNCConnection, didUpdateFramebuffer framebuffer: VNCFramebuffer, x: UInt16, y: UInt16, width: UInt16, height: UInt16) {
		// NOTE: If we ever take the updatedRegion into consideration, we will likely need to flip the coordinates on macOS
		guard !settings.useDisplayLink, displayLink == nil else {
			return
		}

		updateImage(framebuffer.cgImage, animated: didResizeFramebuffer)
	}

	func connection(_ connection: VNCConnection, didUpdateCursor cursor: VNCCursor) {
		DispatchQueue.main.async { [weak self] in
			self?.currentCursor = cursor.nsCursor
		}
	}
}

// MARK: - Positions
extension NSVNCView {
	fileprivate struct UInt16Point {
		let x: UInt16
		let y: UInt16

		init(x: UInt16, y: UInt16) {
			self.x = x
			self.y = y
		}

		init(_ point: CGPoint) {
			self.x = .init(point.x)
			self.y = .init(point.y)
		}
	}

	fileprivate func scaledContentRelativePosition(of event: NSEvent) -> UInt16Point? {
		let viewRelativePosition = viewRelativePosition(of: event)
		let contentRect = contentRect

		guard contentRect.contains(viewRelativePosition) else {
			return nil
		}

		let scaledPosition = CGPoint(x: (viewRelativePosition.x - contentRect.origin.x) / scaleRatio, y: (viewRelativePosition.y - contentRect.origin.y) / scaleRatio)
		let scaledPositionUInt16 = UInt16Point(scaledPosition)

		return scaledPositionUInt16
	}

	fileprivate func viewRelativePosition(of event: NSEvent) -> CGPoint {
		var position = convert(event.locationInWindow, from: nil)
		position.y = bounds.size.height - position.y

		return position
	}
}

// MARK: - Mouse Input
extension NSVNCView {
	func handleMouseMoved(with event: NSEvent) {
		if let position = scaledContentRelativePosition(of: event) {
			connection.mouseMove(x: position.x, y: position.y)
		}
	}

	func handleMouseDown(with event: NSEvent) {
		window?.makeFirstResponder(self)
		becomeFirstResponder()

		if let position = scaledContentRelativePosition(of: event) {
			connection.mouseButtonDown(.left, x: position.x, y: position.y)
		}
	}

	func handleMouseDragged(with event: NSEvent) {
		if let position = scaledContentRelativePosition(of: event) {
			connection.mouseButtonDown(.left, x: position.x, y: position.y)
		}
	}

	func handleMouseUp(with event: NSEvent) {
		if let position = scaledContentRelativePosition(of: event) {
			connection.mouseButtonUp(.left, x: position.x, y: position.y)
		}
	}

	func handleRightMouseDown(with event: NSEvent) {
		if let position = scaledContentRelativePosition(of: event) {
			connection.mouseButtonDown(.right, x: position.x, y: position.y)
		}
	}

	func handleRightMouseDragged(with event: NSEvent) {
		if let position = scaledContentRelativePosition(of: event) {
			connection.mouseButtonDown(.right, x: position.x, y: position.y)
		}
	}

	func handleRightMouseUp(with event: NSEvent) {
		if let position = scaledContentRelativePosition(of: event) {
			connection.mouseButtonUp(.right, x: position.x, y: position.y)
		}
	}

	func handleOtherMouseDown(with event: NSEvent) {
		if isMiddleButton(event: event), let position = scaledContentRelativePosition(of: event) {
			connection.mouseButtonDown(.middle, x: position.x, y: position.y)
		}
	}

	func handleOtherMouseDragged(with event: NSEvent) {
		if isMiddleButton(event: event), let position = scaledContentRelativePosition(of: event) {
			connection.mouseButtonDown(.middle, x: position.x, y: position.y)
		}
	}

	func handleOtherMouseUp(with event: NSEvent) {
		if isMiddleButton(event: event), let position = scaledContentRelativePosition(of: event) {
			connection.mouseButtonUp(.middle, x: position.x, y: position.y)
		}
	}

	func handleScrollWheel(with event: NSEvent) {
		if let position = scaledContentRelativePosition(of: event) {

			let scrollDelta = CGPoint(x: event.scrollingDeltaX, y: event.scrollingDeltaY)

			handleScrollWheel(scrollDelta: scrollDelta, hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas, mousePositionX: position.x, mousePositionY: position.y)
		}
	}

	func isMiddleButton(event: NSEvent) -> Bool {
		let isIt = event.buttonNumber == 2

		return isIt
	}
}

// MARK: - Keyboard Input
extension NSVNCView {
	func handleKey(event: NSEvent?) {
		if let event {
			if event.type == .keyDown {
				handleKeyDown(with: event)
			} else if event.type == .keyUp {
				handleKeyUp(with: event)
			}
		}
	}

	func handleKeyDown(with event: NSEvent?) {
		if let event {
			let keyCodes = keyCodesFrom(event: event)

			for keyCode in keyCodes {
				connection.keyDown(keyCode)
			}
		}
	}

	func handleKeyUp(with event: NSEvent?) {
		if let event {
			let keyCodes = keyCodesFrom(event: event)

			for keyCode in keyCodes {
				connection.keyUp(keyCode)
			}
		}
	}

	func handleFlagsChanged(with event: NSEvent) {
		let currentFlags = event.modifierFlags
		let lastFlags = lastModifierFlags
		let modifiers = KeyboardModifiers(currentFlags: currentFlags, lastFlags: lastFlags)

		lastModifierFlags = currentFlags

		let events = modifiers.events

		for event in events {
			handleKey(event: event)
		}
	}

	func handlePerformKeyEquivalent(with event: NSEvent) -> Bool {
		// swiftlint:disable:next control_statement
		guard settings.inputMode == .forwardKeyboardShortcutsEvenIfInUseLocally || settings.inputMode == .forwardAllKeyboardShortcutsAndHotKeys, let window, window.firstResponder == window || window.firstResponder == self else {
			return false
		}

		let flags = event.modifierFlags

		guard flags.contains(.shift) || flags.contains(.control) || flags.contains(.option) || flags.contains(.command) else {
			return false
		}

		handleKeyDown(with: event)
		handleKeyUp(with: event)

		return true
	}

	func keyCodesFrom(event: NSEvent) -> [VNCKeyCode] {
		let characters = event.charactersIgnoringModifiers
		let keyCode = CGKeyCode(event.keyCode)

		let keys = VNCKeyCode.keyCodesFrom(cgKeyCode: keyCode, characters: characters)

		if keys.isEmpty {
			connection.logger.logError("Ignoring unconvertable key press (Key Code: \(event.keyCode))")
		}

		return keys
	}
}

extension NSVNCView {
	fileprivate func frameSizeExceedsFramebufferSize(_ frameSize: CGSize) -> Bool {
		return frameSize.width >= framebufferSize.width && frameSize.height >= framebufferSize.height
	}

	fileprivate func handleScrollWheel(scrollDelta: CGPoint, hasPreciseScrollingDeltas: Bool, mousePositionX: UInt16, mousePositionY: UInt16) {
		if hasPreciseScrollingDeltas {
			handlePreciseScrollingDelta(scrollDelta, mousePositionX: mousePositionX, mousePositionY: mousePositionY)
		} else {
			handleImpreciseScrollingDelta(scrollDelta, mousePositionX: mousePositionX, mousePositionY: mousePositionY)
		}
	}

	fileprivate func handleImpreciseScrollingDelta(_ scrollDelta: CGPoint, mousePositionX: UInt16, mousePositionY: UInt16) {
		if scrollDelta.x < 0 {
			connection.mouseWheel(.right, x: mousePositionX, y: mousePositionY, steps: 1)
		} else if scrollDelta.x > 0 {
			connection.mouseWheel(.left, x: mousePositionX, y: mousePositionY, steps: 1)
		}

		if scrollDelta.y < 0 {
			connection.mouseWheel(.down, x: mousePositionX, y: mousePositionY, steps: 1)
		} else if scrollDelta.y > 0 {
			connection.mouseWheel(.up, x: mousePositionX, y: mousePositionY, steps: 1)
		}
	}

	fileprivate func handlePreciseScrollingDelta(_ scrollDelta: CGPoint, mousePositionX: UInt16, mousePositionY: UInt16) {
		accumulatedScrollDeltaX += scrollDelta.x
		accumulatedScrollDeltaY += scrollDelta.y

		if abs(accumulatedScrollDeltaX) >= scrollStep {
			while abs(accumulatedScrollDeltaX) >= scrollStep {
				if accumulatedScrollDeltaX < 0 {
					connection.mouseWheel(.right, x: mousePositionX, y: mousePositionY, steps: 1)

					accumulatedScrollDeltaX += scrollStep
				} else if accumulatedScrollDeltaX > 0 {
					connection.mouseWheel(.left, x: mousePositionX, y: mousePositionY, steps: 1)

					accumulatedScrollDeltaX -= scrollStep
				}
			}

			accumulatedScrollDeltaX = 0
		}

		if abs(accumulatedScrollDeltaY) >= scrollStep {
			while abs(accumulatedScrollDeltaY) >= scrollStep {
				if accumulatedScrollDeltaY < 0 {
					connection.mouseWheel(.down, x: mousePositionX, y: mousePositionY, steps: 1)

					accumulatedScrollDeltaY += scrollStep
				} else if accumulatedScrollDeltaY > 0 {
					connection.mouseWheel(.up, x: mousePositionX, y: mousePositionY, steps: 1)

					accumulatedScrollDeltaY -= scrollStep
				}
			}

			accumulatedScrollDeltaY = 0
		}
	}

	fileprivate func updateImage(_ image: CGImage?, animated: Bool, duration: CGFloat = 0.5) {
		if let layer {
			if animated {
				let transition = CATransition()

				transition.duration = duration
				transition.type = .fade

				CATransaction.setDisableActions(true)

				layer.contents = image
				layer.add(transition, forKey: nil)
			} else {
				layer.contents = image
			}
		}
	}

	fileprivate func updateImage(_ image: CGImage?, animated: Bool) {
		didResizeFramebuffer = false

		DispatchQueue.main.async { [weak self] in
			if let self {
				self.updateImage(image, animated: animated, duration: 0.5)
			}
		}
	}

	fileprivate func frameSizeDidChange(_ size: CGSize) {
		if self.liveViewResize == false {
			self.stopWaitVNCReconfiguration()

			if let layer = layer {
				if settings.isScalingEnabled {
					layer.contentsGravity = .resizeAspect
				} else if frameSizeExceedsFramebufferSize(size) {
					// Don't allow upscaling
					layer.contentsGravity = .center
				} else {
					// Allow downscaling
					layer.contentsGravity = .resizeAspect
				}
			}
		}
	}

	fileprivate func registerHotKeys() {
		if settings.inputMode == .forwardAllKeyboardShortcutsAndHotKeys {
			deregisterHotKeys()

			// This requires Accessibilty permissions which can be requested using `VNCAccessibilityUtils`
			self.previousHotKeyMode = PushSymbolicHotKeyMode(.init(kHIHotKeyModeAllDisabled))
		}
	}

	fileprivate func deregisterHotKeys() {
		if let previousHotKeyMode = previousHotKeyMode {
			PopSymbolicHotKeyMode(previousHotKeyMode)
		}

		self.previousHotKeyMode = nil
	}
}

extension NSVNCView {
	@objc func displayLinkDidUpdate() {
		updateImage(self.connection.framebuffer?.cgImage, animated: didResizeFramebuffer)
	}
}

extension NSVNCView {
	func startWaitVNCReconfiguration() {
		cancelWaitVNCReconfiguration?.cancel()
		checkVNCReconfigurationTimeoutAttempts = 20
		cancelWaitVNCReconfiguration = DispatchWorkItem { [weak self] in
			guard let self = self else {
				return
			}

			if checkVNCReconfigurationTimeoutAttempts > 0 {
				checkVNCReconfigurationTimeoutAttempts -= 1
				DispatchQueue.main.asyncAfter(deadline: .now() + checkVNCReconfigurationTimeoutPeriod, execute: cancelWaitVNCReconfiguration!)
			} else {
				cancelWaitVNCReconfiguration = nil
				self.frameSizeDidChange(self.bounds.size)
			}
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + checkVNCReconfigurationTimeoutPeriod, execute: cancelWaitVNCReconfiguration!)
	}

	func stopWaitVNCReconfiguration() {
		cancelWaitVNCReconfiguration?.cancel()
		cancelWaitVNCReconfiguration = nil
	}

}
