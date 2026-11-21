import AppKit
import Foundation
import RoyalVNCKit
import XCTest

@testable import CakedLib

/// The real VNCServer and the real RoyalVNCKit client over loopback, with a plain NSView as the "guest display".
/// What matters here is the wire: a resize is answered once, with one size, and nothing keeps moving afterwards.
@MainActor
final class VNCResizeLoopbackTests: XCTestCase {
	private final class Guest: NSObject, VNCServerDelegate, @unchecked Sendable {
		let view: NSView
		private(set) var requests: [CGSize] = []
		/// Applied after the request, like a guest that follows (nil: the guest ignores it)
		var follow: ((CGSize) -> CGSize?)? = { $0 }

		init(view: NSView) {
			self.view = view
		}

		func willStart(_ server: VNCServer) {}
		func didStart(_ server: VNCServer) {}
		func willStop(_ server: VNCServer) {}
		func didStop(_ server: VNCServer) {}
		func vncServer(_ server: VNCServer, clientDidConnect clientAddress: String) {}
		func vncServer(_ server: VNCServer, clientDidDisconnect clientAddress: String) {}
		func vncServer(_ server: VNCServer, didReceiveError error: Error) {}
		func vncServer(_ server: VNCServer, didReceiveKeyEvent key: UInt32, isDown: Bool) {}
		func vncServer(_ server: VNCServer, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8) {}

		func vncServer(_ server: VNCServer, clientDidResizeDesktop screens: [CakedLib.VNCScreenDesktop]) {
			guard let screen = screens.first else {
				return
			}

			let asked = CGSize(width: Int(screen.width), height: Int(screen.height))

			requests.append(asked)

			if let size = follow?(asked) {
				view.setFrameSize(size)
			}
		}
	}

	private final class Client: NSObject, RoyalVNCKit.VNCConnectionDelegate, @unchecked Sendable {
		var ready = false
		var sizes: [CGSize] = []
		var connection: RoyalVNCKit.VNCConnection?

		func connection(_ connection: RoyalVNCKit.VNCConnection, stateDidChange connectionState: RoyalVNCKit.VNCConnection.ConnectionState) {}
		func connection(_ connection: RoyalVNCKit.VNCConnection, credentialFor authenticationType: RoyalVNCKit.VNCAuthenticationType, completion: @escaping ((any RoyalVNCKit.VNCCredential)?) -> Void) { completion(nil) }
		func connection(_ connection: RoyalVNCKit.VNCConnection, didCreateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) { ready = true }
		func connection(_ connection: RoyalVNCKit.VNCConnection, didResizeFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) { sizes.append(framebuffer.cgSize) }
		func connection(_ connection: RoyalVNCKit.VNCConnection, didUpdateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer, x: UInt16, y: UInt16, width: UInt16, height: UInt16) {}
		func connection(_ connection: RoyalVNCKit.VNCConnection, didUpdateCursor cursor: RoyalVNCKit.VNCCursor) {}
	}

	private struct HandshakeFailed: Error {}

	/// A handshake that does not complete is a regression of the server or of the client: it fails, it does not skip
	private func requireReady(_ client: Client, file: StaticString = #filePath, line: UInt = #line) throws {
		guard client.ready else {
			XCTFail("the loopback VNC handshake did not complete", file: file, line: line)

			throw HandshakeFailed()
		}
	}

	private func pump(_ seconds: TimeInterval, until condition: () -> Bool = { false }) {
		let end = Date().addingTimeInterval(seconds)

		while Date() < end && condition() == false {
			RunLoop.main.run(until: Date().addingTimeInterval(0.02))
		}
	}

	private func connect(guest: Guest) throws -> (VNCServer, Client, RoyalVNCKit.VNCConnection) {
		let server = try VNCServer(guest.view, name: "loopback", password: nil, port: 0, allInet: false)

		server.delegate = guest
		try server.start()

		let client = Client()
		let settings = RoyalVNCKit.VNCConnection.Settings(
			isDebugLoggingEnabled: false, hostname: "127.0.0.1", port: server.port, isShared: true, isScalingEnabled: false, useDisplayLink: false,
			inputMode: .none, isClipboardRedirectionEnabled: false, colorDepth: .depth24Bit, frameEncodings: .default)
		let connection = RoyalVNCKit.VNCConnection(settings: settings, logger: VNCConnectionLogger(false))

		connection.delegate = client
		client.connection = connection
		connection.connect()

		pump(5) { client.ready }

		return (server, client, connection)
	}

	/// True when the client's framebuffer holds the picture (not black)
	private func isPainted(_ connection: RoyalVNCKit.VNCConnection) -> Bool {
		guard let image = connection.framebuffer?.cgImage, let data = image.dataProvider?.data as Data?, data.isEmpty == false else {
			return false
		}

		let bytesPerPixel = max(image.bitsPerPixel / 8, 1)
		let offset = (image.height / 2) * image.bytesPerRow + (image.width / 2) * bytesPerPixel

		guard offset + 3 < data.count else {
			return false
		}

		return data[offset] != 0 || data[offset + 1] != 0 || data[offset + 2] != 0
	}

	private func makeGuest() -> Guest {
		let view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))

		view.wantsLayer = true
		view.layer?.backgroundColor = NSColor.systemBlue.cgColor

		return Guest(view: view)
	}

	func testAResizeIsAnsweredOnceAndSettles() throws {
		let guest = makeGuest()
		let (server, client, connection) = try connect(guest: guest)

		defer {
			connection.disconnect()
			server.stop()
		}

		try requireReady(client)

		pump(0.5)

		let before = client.sizes.count

		connection.setDesktopSize(CGSize(width: 800, height: 600))
		pump(3) { connection.framebuffer?.cgSize == CGSize(width: 800, height: 600) }

		XCTAssertEqual(connection.framebuffer?.cgSize, CGSize(width: 800, height: 600))

		// Nothing moves any more: not a second resize, not a second request
		let settled = client.sizes.count

		pump(1.5)

		XCTAssertEqual(client.sizes.count, settled)
		XCTAssertEqual(guest.requests, [CGSize(width: 800, height: 600)])
		XCTAssertEqual(settled - before, 1, "one size change for one request: \(client.sizes)")
	}

	func testAnIgnoredResizeKeepsTheFramebufferAndStopsAsking() throws {
		let guest = makeGuest()

		guest.follow = nil

		let (server, client, connection) = try connect(guest: guest)

		defer {
			connection.disconnect()
			server.stop()
		}

		try requireReady(client)

		pump(0.5)

		let before = client.sizes.count

		connection.setDesktopSize(CGSize(width: 800, height: 600))
		pump(3)

		XCTAssertEqual(connection.framebuffer?.cgSize, CGSize(width: 640, height: 480))
		XCTAssertEqual(client.sizes.count, before)
		XCTAssertEqual(guest.requests.count, 1)
	}

	func testARequestForTheCurrentSizeChangesNothing() throws {
		let guest = makeGuest()
		let (server, client, connection) = try connect(guest: guest)

		defer {
			connection.disconnect()
			server.stop()
		}

		try requireReady(client)

		pump(0.5)

		let before = client.sizes.count

		connection.setDesktopSize(CGSize(width: 640, height: 480))
		pump(1)

		XCTAssertEqual(client.sizes.count, before)
		XCTAssertTrue(guest.requests.isEmpty)
	}

	func testSeveralResizesInARowEndOnTheLastOne() throws {
		let guest = makeGuest()
		let (server, client, connection) = try connect(guest: guest)

		defer {
			connection.disconnect()
			server.stop()
		}

		try requireReady(client)

		for size in [CGSize(width: 700, height: 500), CGSize(width: 900, height: 700), CGSize(width: 1000, height: 640)] {
			connection.setDesktopSize(size)
			pump(0.4)
		}

		pump(3) { connection.framebuffer?.cgSize == CGSize(width: 1000, height: 640) }

		XCTAssertEqual(connection.framebuffer?.cgSize, CGSize(width: 1000, height: 640))

		let settled = client.sizes.count

		pump(1.5)

		XCTAssertEqual(client.sizes.count, settled)
	}

	func testTheClientKeepsTheWholePictureThroughEveryKindOfResize() throws {
		let guest = makeGuest()
		let (server, client, connection) = try connect(guest: guest)

		defer {
			connection.disconnect()
			server.stop()
		}

		try requireReady(client)

		pump(1)
		XCTAssertTrue(isPainted(connection), "after connect")

		// Same size: only an answer comes back
		connection.setDesktopSize(CGSize(width: 640, height: 480))
		pump(1)
		XCTAssertTrue(isPainted(connection), "after a request for the current size")

		// A new size
		connection.setDesktopSize(CGSize(width: 900, height: 700))
		pump(3) { connection.framebuffer?.cgSize == CGSize(width: 900, height: 700) }
		pump(1)
		XCTAssertTrue(isPainted(connection), "after a resize")

		// A guest that does not follow: the answer comes after the timeout
		guest.follow = nil
		connection.setDesktopSize(CGSize(width: 500, height: 400))
		pump(3)
		XCTAssertTrue(isPainted(connection), "after a resize the guest ignored")
	}
}
