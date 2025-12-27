import GRPC
import NIOCore
import NIOPosix
import Synchronization
import XCTest

@testable import CakedLib
@testable import GRPCLib
@testable import cakectl

final class GrpcUnixSocketTests: XCTestCase {
	let testCase = GrpcTestCase()

	let address = URL(string: try! Utils.getDefaultServerAddress(runMode: .user))
	//	let address = URL(string: "unix:///tmp/caked-\(getpid()).sock")
	//	let address = URL(string: "unix:///Users/fboltz/.cake/.cacked.sock")

	func testSocketClientListWithTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: true))
	}

	func testSocketClientListNoTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: false))
	}
}
