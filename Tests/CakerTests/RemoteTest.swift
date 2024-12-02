import XCTest
@testable import caked
@testable import GRPCLib

final class RemoteTests: XCTestCase {
	let linuxcontainers = URL(string: "https://images.linuxcontainers.org/")!

	func testRemoteList() throws {
		XCTAssertNoThrow(try RemoteHandler.listRemote(asSystem: false))

		print(Format.text.renderList(try! RemoteHandler.listRemote(asSystem: false)))
	}

	func testRemoteAddDelete() throws {
		let remote = UUID().uuidString

		XCTAssertNoThrow(try RemoteHandler.addRemote(name: remote, url: linuxcontainers, asSystem: false))
		XCTAssertNoThrow(try RemoteHandler.deleteRemote(name: remote, asSystem: false))
	}

	func testRemoteDuplicate() throws {
		let remote = UUID().uuidString

		XCTAssertNoThrow(try RemoteHandler.addRemote(name: remote, url: linuxcontainers, asSystem: false))
		XCTAssertThrowsError(try RemoteHandler.addRemote(name: remote, url: linuxcontainers, asSystem: false))
		XCTAssertNoThrow(try RemoteHandler.deleteRemote(name: remote, asSystem: false))
	}
}