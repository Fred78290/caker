import XCTest
import ShellOut
import Synchronization
import NIOCore
import NIOPosix
import GRPC

@testable import tarthelper
@testable import tartctl
@testable import GRPCLib

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