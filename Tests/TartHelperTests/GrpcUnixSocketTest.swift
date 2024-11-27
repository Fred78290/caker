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
	let certs: CertificatesLocation = try! CertificatesLocation.createCertificats(asSystem: false)
//	let address: URL = URL(string: try! Client.getDefaultServerAddress())!
	let address: URL = URL(string: "unix:///tmp/tartgrpc-\(getpid()).sock")!

	func createClient(on: MultiThreadedEventLoopGroup, tls: Bool) throws -> ClientConnection {
		let client = try Client.createClient(on: on,
		                                     listeningAddress: address,
		                                     caCert: tls ? certs.caCertURL.absoluteURL.path() : nil,
		                                     tlsCert: tls ? certs.clientCertURL.absoluteURL.path() : nil,
		                                     tlsKey: tls ? certs.clientKeyURL.absoluteURL.path() : nil)

		return client
	}

	func createServer(on: MultiThreadedEventLoopGroup, tls: Bool) throws -> Server {
		let server = try Service.Listen.createServer(on: on,
		                                             asSystem: false,
		                                             listeningAddress: address,
		                                             caCert: tls ? certs.caCertURL.absoluteURL.path() : nil,
		                                             tlsCert: tls ? certs.serverCertURL.absoluteURL.path() : nil,
		                                             tlsKey: tls ? certs.serverKeyURL.absoluteURL.path() : nil).wait()


		return server
	}

	func runClientList(tls: Bool) throws {
		let group = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let server = try self.createServer(on: group, tls: tls)

		defer {
			XCTAssertNoThrow(try server.close().wait())
		}

		let client = try self.createClient(on: group, tls: tls)

		defer {
			XCTAssertNoThrow(try client.close().wait())
		}

		let reply = try List().run(client: Tarthelper_ServiceNIOClient(channel: client), arguments: [])

		print(reply.output)
	}

	func testClientListWithTls() throws {
		XCTAssertNoThrow(try runClientList(tls: true))
	}

	func testClientListNoTls() throws {
		XCTAssertNoThrow(try runClientList(tls: false))
	}
}