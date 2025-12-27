import XCTest

@testable import CakedLib
@testable import GRPCLib

final class RemoteTests: XCTestCase {
	let linuxcontainers = URL(string: "https://images.linuxcontainers.org/")!

	func testRemoteList() throws {
		let reply = RemoteHandler.listRemote(runMode: .user)

		XCTAssertTrue(reply.success)

		print(Format.text.renderList(reply.remotes))
	}

	func testRemoteAddDelete() throws {
		let remote = UUID().uuidString
		let addReply = RemoteHandler.addRemote(name: remote, url: linuxcontainers, runMode: .user)

		XCTAssertTrue(addReply.created)

		let deleteReply = RemoteHandler.deleteRemote(name: remote, runMode: .user)

		XCTAssertTrue(deleteReply.deleted)
	}

	func testRemoteDuplicate() throws {
		let remote = UUID().uuidString
		var addReply = RemoteHandler.addRemote(name: remote, url: linuxcontainers, runMode: .user)

		XCTAssertTrue(addReply.created)

		addReply = RemoteHandler.addRemote(name: remote, url: linuxcontainers, runMode: .user)

		XCTAssertFalse(addReply.created)

		let deleteReply = RemoteHandler.deleteRemote(name: remote, runMode: .user)

		XCTAssertTrue(deleteReply.deleted)
	}
}
