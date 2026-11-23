import Foundation
import XCTest

@testable import CakedLib

final class DesktopSizeNegotiatorTests: XCTestCase {
	private let now = Date(timeIntervalSince1970: 1_000)

	func testNothingIsAskedWhenTheFramebufferAlreadyHasTheSize() {
		var negotiator = DesktopSizeNegotiator()

		XCTAssertNil(negotiator.request(CGSize(width: 1024, height: 768), framebuffer: CGSize(width: 1024, height: 768), now: now))
		XCTAssertFalse(negotiator.isWaiting(now: now))
	}

	func testASizeIsAskedOnlyOnce() {
		var negotiator = DesktopSizeNegotiator()
		let target = CGSize(width: 1280, height: 720)
		let framebuffer = CGSize(width: 1024, height: 768)

		XCTAssertEqual(negotiator.request(target, framebuffer: framebuffer, now: now), target)

		// The server answers with another size (it clamped): asking again would start the loop
		negotiator.framebufferDidChange(to: CGSize(width: 1280, height: 700))

		XCTAssertNil(negotiator.request(target, framebuffer: CGSize(width: 1280, height: 700), now: now.addingTimeInterval(5)))
	}

	func testASizeCanBeAskedAgainOnceTheFramebufferLeftTheNegotiatedResult() {
		var negotiator = DesktopSizeNegotiator()
		let target = CGSize(width: 1280, height: 720)

		XCTAssertEqual(negotiator.request(target, framebuffer: CGSize(width: 1024, height: 768), now: now), target)
		negotiator.framebufferDidChange(to: target)

		// The guest moves the framebuffer away, the user then wants the earlier size back
		negotiator.framebufferDidChange(to: CGSize(width: 800, height: 600))

		XCTAssertEqual(negotiator.request(target, framebuffer: CGSize(width: 800, height: 600), now: now.addingTimeInterval(5)), target)
	}

	func testASizeCanBeAskedAgainWhenTheFramebufferMovedWithoutNotice() {
		var negotiator = DesktopSizeNegotiator()
		let target = CGSize(width: 1280, height: 720)

		XCTAssertEqual(negotiator.request(target, framebuffer: CGSize(width: 1024, height: 768), now: now), target)
		negotiator.framebufferDidChange(to: CGSize(width: 1280, height: 700))

		XCTAssertNil(negotiator.request(target, framebuffer: CGSize(width: 1280, height: 700), now: now.addingTimeInterval(5)))
		XCTAssertEqual(negotiator.request(target, framebuffer: CGSize(width: 640, height: 480), now: now.addingTimeInterval(6)), target)
	}

	func testOnlyOneRequestWaitsForItsAnswer() {
		var negotiator = DesktopSizeNegotiator()
		let framebuffer = CGSize(width: 1024, height: 768)

		XCTAssertNotNil(negotiator.request(CGSize(width: 1100, height: 700), framebuffer: framebuffer, now: now))
		XCTAssertNil(negotiator.request(CGSize(width: 1200, height: 700), framebuffer: framebuffer, now: now.addingTimeInterval(0.5)))
		XCTAssertTrue(negotiator.isWaiting(now: now.addingTimeInterval(0.5)))

		negotiator.framebufferDidChange(to: CGSize(width: 1100, height: 700))

		XCTAssertEqual(negotiator.request(CGSize(width: 1200, height: 700), framebuffer: CGSize(width: 1100, height: 700), now: now.addingTimeInterval(0.6)), CGSize(width: 1200, height: 700))
	}

	func testALostRequestExpires() {
		var negotiator = DesktopSizeNegotiator()
		let framebuffer = CGSize(width: 1024, height: 768)

		XCTAssertNotNil(negotiator.request(CGSize(width: 1100, height: 700), framebuffer: framebuffer, now: now))
		XCTAssertNil(negotiator.request(CGSize(width: 1200, height: 700), framebuffer: framebuffer, now: now.addingTimeInterval(1)))
		XCTAssertNotNil(negotiator.request(CGSize(width: 1200, height: 700), framebuffer: framebuffer, now: now.addingTimeInterval(DesktopSizeNegotiator.answerTimeout + 0.1)))
	}

	func testASizeThatWasNotSentIsNotRecordedAsRequested() {
		var negotiator = DesktopSizeNegotiator()

		// The target is the framebuffer: nothing is sent, so nothing is recorded...
		XCTAssertNil(negotiator.request(CGSize(width: 1024, height: 768), framebuffer: CGSize(width: 1024, height: 768), now: now))
		XCTAssertNil(negotiator.lastRequested)

		// ...and when the guest later leaves that size, asking for it is possible
		XCTAssertEqual(negotiator.request(CGSize(width: 1024, height: 768), framebuffer: CGSize(width: 800, height: 600), now: now), CGSize(width: 1024, height: 768))
	}

	func testARequestStillWaitingKeepsWaitingWhenTheTargetReturnsToTheFramebuffer() {
		var negotiator = DesktopSizeNegotiator()
		let framebuffer = CGSize(width: 1024, height: 768)

		XCTAssertNotNil(negotiator.request(CGSize(width: 1100, height: 700), framebuffer: framebuffer, now: now))
		XCTAssertNil(negotiator.request(framebuffer, framebuffer: framebuffer, now: now.addingTimeInterval(0.3)))

		// Still one request waiting for its answer: no second one
		XCTAssertNil(negotiator.request(CGSize(width: 1200, height: 700), framebuffer: framebuffer, now: now.addingTimeInterval(0.5)))
		XCTAssertTrue(negotiator.isWaiting(now: now.addingTimeInterval(0.5)))
	}

	func testATargetEqualToTheFramebufferWhileWaitingIsAskedOnceTheAnswerMovedTheFramebuffer() {
		var negotiator = DesktopSizeNegotiator()
		let framebuffer = CGSize(width: 1024, height: 768)
		let answer = CGSize(width: 1100, height: 700)

		XCTAssertEqual(negotiator.request(answer, framebuffer: framebuffer, now: now), answer)

		// The user brings the view back to the framebuffer's size while the request waits: nothing is sent, the request keeps waiting
		XCTAssertNil(negotiator.request(framebuffer, framebuffer: framebuffer, now: now.addingTimeInterval(0.3)))
		XCTAssertTrue(negotiator.isWaiting(now: now.addingTimeInterval(0.3)))

		// The answer arrives: the retained target differs from the new framebuffer and is asked
		negotiator.framebufferDidChange(to: answer)

		XCTAssertFalse(negotiator.isWaiting(now: now.addingTimeInterval(0.4)))
		XCTAssertEqual(negotiator.request(framebuffer, framebuffer: answer, now: now.addingTimeInterval(0.4)), framebuffer)
	}

	func testSizesAreNormalized() {
		XCTAssertEqual(DesktopSizeNegotiator.normalized(CGSize(width: 1000.7, height: 600.2)), CGSize(width: 1000, height: 600))
		XCTAssertNil(DesktopSizeNegotiator.normalized(.zero))
		XCTAssertNil(DesktopSizeNegotiator.normalized(CGSize(width: 0.5, height: 100)))
		XCTAssertNil(DesktopSizeNegotiator.normalized(CGSize(width: CGFloat.nan, height: 100)))
		XCTAssertNil(DesktopSizeNegotiator.normalized(CGSize(width: 70_000, height: 100)))
	}

	/// A window that follows the framebuffer, a framebuffer that follows the window: whatever the window adds around
	/// its view and however the server clamps or rounds the size, it must stop.
	func testWindowAndFramebufferSettle() {
		for server in [Server.exact, .clamped, .roundedToFour, .refusing] {
			XCTAssertLessThan(simulate(server: server), 4, "\(server) did not settle")
		}
	}

	private enum Server {
		case exact, clamped, roundedToFour, refusing

		func answer(_ asked: CGSize, current: CGSize) -> CGSize {
			switch self {
			case .exact:
				return asked
			case .clamped:
				return CGSize(width: min(max(asked.width, 320), 1600), height: min(max(asked.height, 200), 900))
			case .roundedToFour:
				return CGSize(width: (asked.width / 4).rounded(.down) * 4, height: asked.height)
			case .refusing:
				return current
			}
		}
	}

	/// Number of requests sent until nothing moves any more
	private func simulate(server: Server) -> Int {
		var negotiator = DesktopSizeNegotiator()
		var framebuffer = CGSize(width: 1024, height: 768)
		var view = CGSize(width: 1500, height: 1000)  // the user dragged the window
		var time = now
		var requests = 0

		for _ in 0..<60 {
			time = time.addingTimeInterval(0.3)

			if let asked = negotiator.request(view, framebuffer: framebuffer, now: time) {
				requests += 1

				let answer = server.answer(asked, current: framebuffer)

				if answer != framebuffer {
					framebuffer = answer
					negotiator.framebufferDidChange(to: framebuffer)

					// The window follows the framebuffer. It is sized by the delta of the view (NSWindow.fitContent),
					// so whatever the window adds around the view, the view becomes exactly the framebuffer
					if view != framebuffer {
						view = CGSize(width: framebuffer.width, height: framebuffer.height)
					}
				}
			}

		}

		return requests
	}

	func testAPasswordIsRemovedFromAURLForTheLog() {
		XCTAssertEqual(URL(string: "vnc://:secret@192.168.1.2:5900")!.removingPassword, "vnc://192.168.1.2:5900")
		XCTAssertEqual(URL(string: "vnc://user:secret@192.168.1.2:5900")!.removingPassword, "vnc://user@192.168.1.2:5900")
		XCTAssertEqual(URL(string: "vnc://192.168.1.2:5900")!.removingPassword, "vnc://192.168.1.2:5900")
	}
}
