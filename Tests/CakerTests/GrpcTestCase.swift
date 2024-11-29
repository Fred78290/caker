
import XCTest
import Synchronization
import NIOCore
import NIOPosix
import GRPC

@testable import caked
@testable import cakectl
@testable import GRPCLib

class GrpcTestCase {
	let certs: CertificatesLocation = try! CertificatesLocation.createCertificats(asSystem: false)

	func createClient(listeningAddress: URL?, on: MultiThreadedEventLoopGroup, tls: Bool) throws -> ClientConnection {
		let client = try Client.createClient(on: on,
		                                     listeningAddress: listeningAddress,
		                                     caCert: tls ? certs.caCertURL.absoluteURL.path() : nil,
		                                     tlsCert: tls ? certs.clientCertURL.absoluteURL.path() : nil,
		                                     tlsKey: tls ? certs.clientKeyURL.absoluteURL.path() : nil)

		return client
	}

	func createServer(listeningAddress: URL?, on: MultiThreadedEventLoopGroup, tls: Bool) throws -> Server {
		let server = try Service.Listen.createServer(on: on,
		                                             asSystem: false,
		                                             listeningAddress: listeningAddress,
		                                             caCert: tls ? certs.caCertURL.absoluteURL.path() : nil,
		                                             tlsCert: tls ? certs.serverCertURL.absoluteURL.path() : nil,
		                                             tlsKey: tls ? certs.serverKeyURL.absoluteURL.path() : nil).wait()


		return server
	}

	func runClientList(listeningAddress: URL?, tls: Bool) throws {
		let group = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let server = try self.createServer(listeningAddress: listeningAddress, on: group, tls: tls)

		defer {
			XCTAssertNoThrow(try server.close().wait())
		}

		let client = try self.createClient(listeningAddress: listeningAddress, on: group, tls: tls)

		defer {
			XCTAssertNoThrow(try client.close().wait())
		}

		let reply = try List().run(client: Caked_ServiceNIOClient(channel: client), arguments: [])

		print(reply.output)
	}
}