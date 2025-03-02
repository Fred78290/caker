import ArgumentParser
import Foundation
import CakeAgentLib
import NIO
import GRPC
import GRPCLib
import Logging

protocol CakeAgentAsyncParsableCommand: AsyncParsableCommand {
	var name: String { get }
	var createVM: Bool { get }	
	var options: CakeAgentClientOptions { set get }
	var logLevel: Logging.Logger.Level { get }
	var retries: ConnectionBackoff.Retries { get }
	var callOptions: CallOptions? { get }

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws
}

extension CakeAgentClientOptions {
	func createClient(on: EventLoopGroup, retries: ConnectionBackoff.Retries) throws -> CakeAgentClient {
		return try CakeAgentHelper.createClient(on: on,
		                                        listeningAddress: URL(string: self.address!)!,
		                                        connectionTimeout: self.timeout,
		                                        caCert: self.caCert,
		                                        tlsCert: self.tlsCert,
		                                        tlsKey: self.tlsKey,
												retries: retries)
	}
}

extension CakeAgentAsyncParsableCommand {
	func startVM(on: EventLoop, waitIPTimeout: Int, foreground: Bool = false) throws {
		let vmLocation = try StorageLocation(asSystem: false).find(name)

		if vmLocation.status != .running {
			Logger.info("Starting VM \(name)")
			let config = try vmLocation.config()

			let _ = try StartHandler.startVM(vmLocation: vmLocation, config: config, waitIPTimeout: waitIPTimeout, startMode: foreground ? .foreground : .background)
		}
	}

	mutating func validateOptions() throws {
		Logger.setLevel(self.logLevel)

		let certificates = try CertificatesLocation.createAgentCertificats(asSystem: runAsSystem)
		let listeningAddress: URL

		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		if self.createVM {
			listeningAddress = StorageLocation(asSystem: runAsSystem).location(name).agentURL
		} else {
			listeningAddress = try StorageLocation(asSystem: runAsSystem).find(name).agentURL
		}

		if self.options.insecure == false{
			if self.options.caCert == nil {
				self.options.caCert = certificates.caCertURL.path()
			}

			if self.options.tlsCert == nil {
				self.options.tlsCert = certificates.clientCertURL.path()
			}

			if self.options.tlsKey == nil {
				self.options.tlsKey = certificates.clientKeyURL.path()
			}
		}

		try self.options.validate(listeningAddress.absoluteString)
	}

	mutating func validate() throws {
		try self.validateOptions()
	}

	mutating func run() async throws {
		Root.sigintSrc.cancel()

		let grpcClient = try self.options.createClient(on: Root.group, retries: self.retries)

		do {
			try await self.run(on: Root.group.next(), client: grpcClient, callOptions: self.callOptions)

			try? await grpcClient.close()
		} catch {
			try? await grpcClient.close()
			throw error
		}
	}

}
