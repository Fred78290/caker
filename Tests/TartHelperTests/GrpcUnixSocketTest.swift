import XCTest
import ShellOut
import Synchronization
import NIOCore
import NIOPosix
import GRPC

@testable import caked
@testable import cakectl
@testable import GRPCLib

final class GrpcUnixSocketTests: XCTestCase {
	let testCase = GrpcTestCase()

//	let address: URL = URL(string: try! Client.getDefaultServerAddress())
	let address = URL(string: "unix:///tmp/caked-\(getpid()).sock")

	func testSocketClientListWithTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: true))
	}

	func testSocketClientListNoTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: false))
	}
}