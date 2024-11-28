import XCTest
import ShellOut
import Synchronization
import NIOCore
import NIOPosix
import GRPC

@testable import tarthelper
@testable import tartctl
@testable import GRPCLib

final class GrpcUnixSocketTests: XCTestCase {
	let testCase = GrpcTestCase()

//	let address: URL = URL(string: try! Client.getDefaultServerAddress())
	let address = URL(string: "unix:///tmp/tartgrpc-\(getpid()).sock")

	func testSocketClientListWithTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: true))
	}

	func testSocketClientListNoTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: false))
	}
}