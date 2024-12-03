import XCTest
import Synchronization
import NIOCore
import NIOPosix
import GRPC

@testable import caked
@testable import cakectl
@testable import GRPCLib

final class GrpcUnixSocketTests: XCTestCase {
	let testCase = GrpcTestCase()

	let address = URL(string: try! Client.getDefaultServerAddress(asSystem: false))
//	let address = URL(string: "unix:///tmp/caked-\(getpid()).sock")
//	let address = URL(string: "unix:///Users/fboltz/.cake/.cacked.sock")

	func testSocketClientListWithTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: true))
	}

	func testSocketClientListNoTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: false))
	}
}