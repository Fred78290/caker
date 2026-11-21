import AppKit
import XCTest

@testable import CakedLib

@MainActor
final class WindowFitContentTests: XCTestCase {
	private func makeWindow(styleMask: NSWindow.StyleMask) -> (NSWindow, NSView) {
		let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 800, height: 600), styleMask: styleMask, backing: .buffered, defer: true)
		let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
		let view = NSView(frame: container.bounds)

		view.autoresizingMask = [.width, .height]
		container.addSubview(view)
		window.contentView = container

		return (window, view)
	}

	func testTheViewEndsExactlyTheWantedSize() {
		for styleMask: NSWindow.StyleMask in [[.titled, .closable, .resizable], [.titled, .closable, .resizable, .fullSizeContentView], [.borderless]] {
			let (window, view) = makeWindow(styleMask: styleMask)

			window.fitContent(of: view, to: CGSize(width: 1024, height: 700), animated: false)

			XCTAssertEqual(view.bounds.size, CGSize(width: 1024, height: 700), "\(styleMask)")
		}
	}

	func testFittingTwiceChangesNothing() {
		let (window, view) = makeWindow(styleMask: [.titled, .closable, .resizable])

		window.fitContent(of: view, to: CGSize(width: 1024, height: 700), animated: false)

		let frame = window.frame

		window.fitContent(of: view, to: CGSize(width: 1024, height: 700), animated: false)

		XCTAssertEqual(window.frame, frame)
	}

	func testTheTopLeftCornerStays() {
		let (window, view) = makeWindow(styleMask: [.titled, .closable, .resizable])
		let top = window.frame.maxY
		let left = window.frame.minX

		window.fitContent(of: view, to: CGSize(width: 900, height: 500), animated: false)

		XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
		XCTAssertEqual(window.frame.minX, left, accuracy: 0.5)
	}

	/// The formula this replaces: a frame computed from the content size plus the title bar height. The title bar
	/// is counted twice, so every round trip with a framebuffer that follows the window adds a title bar.
	func testTheTitleBarFormulaGrowsWhereFitContentDoesNot() {
		let (window, view) = makeWindow(styleMask: [.titled, .closable, .resizable])
		let wanted = CGSize(width: 1024, height: 700)

		for _ in 0..<3 {
			let titleBarHeight = window.frame.height - window.contentLayoutRect.height
			let frame = window.frameRect(forContentRect: NSRect(x: window.frame.minX, y: window.frame.minY, width: wanted.width, height: wanted.height + titleBarHeight))

			window.setFrame(frame, display: false)
		}

		XCTAssertGreaterThan(view.bounds.height, wanted.height, "the old formula should overshoot")

		window.fitContent(of: view, to: wanted, animated: false)

		XCTAssertEqual(view.bounds.size, wanted)
	}
}
