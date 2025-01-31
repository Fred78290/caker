import ArgumentParser
import Foundation
import CakeAgentLib
import NIO
import GRPC
import GRPCLib

protocol CakeAgentAsyncParsableCommand: AsyncParsableCommand {
	var name: String { get }	
	var options: CakeAgentClientOptions { set get }

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws
}

extension CakeAgentAsyncParsableCommand {
	mutating func validate() throws {
		let certificates: CertificatesLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: runAsSystem))).createCertificats()

		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}
		
		let listeningAddress = try StorageLocation(asSystem: runAsSystem).find(name).agentURL
		
		if self.options.insecure == false{
			if self.options.caCert == nil {
				self.options.caCert = certificates.caCertURL.path()
			}

			if self.options.tlsCert == nil {
				self.options.tlsCert = certificates.serverCertURL.path()
			}

			if self.options.tlsKey == nil {
				self.options.tlsKey = certificates.serverKeyURL.path()
			}
		}

		try self.options.validate(listeningAddress.absoluteString)
	}
	
	mutating func run() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		do {
			let grpcClient = try self.options.createClient(on: group)

			do {
				try await self.run(on: group,
				                      client: grpcClient,
				                      callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(options.timeout))))

				try! await grpcClient.close()
			} catch {
				try! await grpcClient.close()
				throw error
			}

			try! await group.shutdownGracefully()
		} catch {
			try! await group.shutdownGracefully()
			throw error
		}
	}

}