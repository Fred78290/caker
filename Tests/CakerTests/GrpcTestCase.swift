
import XCTest
import Synchronization
import NIOCore
import NIOPosix
import GRPC
import ArgumentParser

@testable import caked
@testable import cakectl
@testable import GRPCLib

class GrpcTestCase {
	let certs: CertificatesLocation = try! CertificatesLocation.createCertificats(asSystem: false)

	func createClient(listeningAddress: URL?, on: MultiThreadedEventLoopGroup, tls: Bool) throws -> ClientConnection {
		let client = try Client.createClient(on: on,
		                                     listeningAddress: listeningAddress,
											 retries: .upTo(1),
		                                     caCert: tls ? certs.caCertURL.absoluteURL.path : nil,
		                                     tlsCert: tls ? certs.clientCertURL.absoluteURL.path : nil,
		                                     tlsKey: tls ? certs.clientKeyURL.absoluteURL.path : nil)

		return client
	}

	func createServer(listeningAddress: URL?, on: MultiThreadedEventLoopGroup, tls: Bool) throws -> Server {
		let server = try Service.Listen.createServer(eventLoopGroup: on,
		                                             asSystem: false,
		                                             listeningAddress: listeningAddress,
		                                             caCert: tls ? certs.caCertURL.absoluteURL.path : nil,
		                                             tlsCert: tls ? certs.serverCertURL.absoluteURL.path : nil,
		                                             tlsKey: tls ? certs.serverKeyURL.absoluteURL.path : nil).wait()


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
		let serviceNIOClient = Caked_ServiceNIOClient(channel: client)

		defer {
			XCTAssertNoThrow(try client.close().wait())
		}

		let reply = serviceNIOClient.list(Caked_ListRequest(), callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(30))))
		
		print(Format.text.render(try reply.response.wait().successfull().vms.list))
	}
}
