import GRPC
import NIOCore
import NIOPosix
import Synchronization
import XCTest

@testable import GRPCLib
@testable import cakectl
@testable import caked

final class GrpcTcpSocketTests: XCTestCase {
	let testCase = GrpcTestCase()
	let address = URL(string: "tcp://127.0.0.1:\(Int.random(in: 9600..<9700))")

	func testTcpClientListWithTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: true))
	}

	func testTcpClientListNoTls() throws {
		XCTAssertNoThrow(try testCase.runClientList(listeningAddress: address, tls: false))
	}
}
