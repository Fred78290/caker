import XCTest
import ShellOut
import Synchronization
import NIOCore
import NIOPosix
import GRPC

@testable import tarthelper
@testable import tartctl
@testable import GRPCLib

final class GrpcTests: XCTestCase {
	let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
	var server: Server? = nil
	var client: ClientConnection? = nil

	override func setUp() async throws {
		client = try Client().createClient(on: group)
		server = try await Service.Listen().createServer(on: group).get()
	}

	override func tearDown() async throws {
		if let server = self.server {
			try await server.onClose.get()
		}

		try! await group.shutdownGracefully()
	}

	func testClientList() async throws {
		if let client = self.client {
			let reply = try await List().run(client: Tarthelper_ServiceNIOClient(channel: client), arguments: [])

			print(reply.output)
		}
	}
}