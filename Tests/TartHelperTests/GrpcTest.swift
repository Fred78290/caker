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

	func createClient() throws -> ClientConnection {
		guard let client = self.client else {
			let client = try Client.createClient(on: group,
							listeningAddress: URL(string: try Client.getDefaultServerAddress()),
							caCert: nil, tlsCert: nil, tlsKey: nil)
			self.client = client

			return client
		}

		return client
	}

	override func setUp() async throws {
		server = try await Service.Listen.createServer(on: group,
								asSystem: false,
								listeningAddress: URL(string: try Client.getDefaultServerAddress()),
								caCert: nil, tlsCert: nil, tlsKey: nil).get()
	}

	override func tearDown() async throws {
		if let server = self.server {
			try await server.onClose.get()
		}

		try! await group.shutdownGracefully()
	}

	func testClientList() async throws {
		let reply = try await List().run(client: Tarthelper_ServiceNIOClient(channel: try self.createClient()), arguments: [])

		print(reply.output)
	}
}