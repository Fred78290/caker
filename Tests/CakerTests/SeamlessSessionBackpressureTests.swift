//
//  SeamlessSessionBackpressureTests.swift
//  CakerTests
//

import Darwin
import Foundation
import XCTest

@testable import CakedLib

final class SeamlessSessionBackpressureTests: XCTestCase {
	private func socketPair() throws -> (Int32, Int32) {
		var fds: [Int32] = [0, 0]

		XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds), 0)

		var one: Int32 = 1

		setsockopt(fds[0], SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))

		return (fds[0], fds[1])
	}

	func testGuestThatStopsReadingGetsDisconnectedInsteadOfBufferingForever() throws {
		let (host, guest) = try socketPair()

		defer { Darwin.close(guest) }

		let session = SeamlessSession(fd: host)

		// Nobody reads `guest`: the socket buffer fills, the writer blocks, and the queue must hit its bound.
		for i in 0..<(SeamlessSession.maxPendingMessages + 100_000) where !session.isClosed {
			session.send(.key(code: UInt32(i % 200), pressed: i % 2 == 0))
		}

		XCTAssertTrue(session.isClosed)
		session.closeDescriptorForTesting()
	}

	func testMotionIsCoalescedOnlyBehindAMotionOfTheSameWindow() throws {
		let (host, guest) = try socketPair()

		defer { Darwin.close(guest) }

		let session = SeamlessSession(fd: host)

		// Block the writer so everything after the first message stays queued.
		var chunk = [UInt8](repeating: 0, count: 4096)
		let flags = fcntl(host, F_GETFL)

		_ = fcntl(host, F_SETFL, flags | O_NONBLOCK)

		while Darwin.write(host, &chunk, chunk.count) > 0 {}

		_ = fcntl(host, F_SETFL, flags)

		for i in 0..<10_000 {
			session.send(.pointerMotion(id: 1, x: Float(i), y: 0))
		}

		// 10k motions of one window collapse: the queue never reached its message bound.
		XCTAssertFalse(session.isClosed)

		session.send(.key(code: 30, pressed: true))
		session.send(.pointerMotion(id: 1, x: 1, y: 1))
		session.send(.key(code: 30, pressed: false))
		session.send(.pointerMotion(id: 1, x: 2, y: 2))
		session.send(.pointerMotion(id: 2, x: 3, y: 3))

		// Key press, motion, key release, motion, other window's motion: nothing between two keys was merged away. One more
		// entry may be queued ahead of them when the writer had not yet picked up the last of the earlier motions.
		let queued = session.pendingMessageCountForTesting

		XCTAssertTrue(queued == 5 || queued == 6, "queued \(queued)")
		XCTAssertFalse(session.isClosed)

		session.close()
		session.closeDescriptorForTesting()
	}
}
