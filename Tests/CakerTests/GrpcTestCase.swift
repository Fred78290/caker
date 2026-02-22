import ArgumentParser
import GRPC
import NIOCore
import NIOPosix
import Synchronization
import XCTest
import CakeAgentLib

@testable import CakedLib
@testable import GRPCLib
@testable import cakectl
@testable import caked

class GrpcTestCase {
	let certs: CertificatesLocation = try! CertificatesLocation.createCertificats(runMode: .user)

	func createClient(listeningAddress: URL?, on: MultiThreadedEventLoopGroup, tls: Bool) throws -> CakedServiceClient {
		let client = try Caked.createClient(
			on: on,
			listeningAddress: listeningAddress,
			retries: .upTo(1),
			caCert: tls ? certs.caCertURL.absoluteURL.path : nil,
			tlsCert: tls ? certs.clientCertURL.absoluteURL.path : nil,
			tlsKey: tls ? certs.clientKeyURL.absoluteURL.path : nil)

		return client
	}

	func createServer(listeningAddress: URL?, on: MultiThreadedEventLoopGroup, tls: Bool) throws -> Server {
		let server = try ServiceHandler.createServer(
			eventLoopGroup: on,
			runMode: .user,
			listeningAddress: listeningAddress,
			serviceProviders: [try CakedProvider(group: on, runMode: .user)],
			caCert: tls ? certs.caCertURL.absoluteURL.path : nil,
			tlsCert: tls ? certs.serverCertURL.absoluteURL.path : nil,
			tlsKey: tls ? certs.serverKeyURL.absoluteURL.path : nil
		).wait()

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
			XCTAssertNoThrow(try client.channel.close().wait())
		}

		let reply = client.list(Caked_ListRequest(), callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(30))))
		let result = try reply.response.wait().vms.list

		if result.success {
			print(Format.text.render(result.infos))
		} else {
			print(Format.text.render(result.reason))
		}
	}
}
