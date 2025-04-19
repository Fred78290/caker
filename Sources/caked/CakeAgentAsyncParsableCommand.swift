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
	var asSystem: Bool { get }
	var options: CakeAgentClientOptions { set get }
	var logLevel: Logging.Logger.Level { get }
	var retries: ConnectionBackoff.Retries { get }
	var callOptions: CallOptions? { get }
	var interceptors: Cakeagent_AgentClientInterceptorFactoryProtocol? { get }

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws
}

extension CakeAgentAsyncParsableCommand {
	var retries: ConnectionBackoff.Retries {
		.upTo(1)
	}

	var interceptors: Cakeagent_AgentClientInterceptorFactoryProtocol? {
		nil
	}

	var callOptions: CallOptions? {
		CallOptions(timeLimit: .none)
	}

	func startVM(on: EventLoop, name: String, waitIPTimeout: Int, foreground: Bool = false, asSystem: Bool) throws {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)

		if vmLocation.status != .running {
			Logger(self).info("Starting VM \(name)")
			let config = try vmLocation.config()

			let _ = try StartHandler.startVM(vmLocation: vmLocation, config: config, waitIPTimeout: waitIPTimeout, startMode: foreground ? .foreground : .background, asSystem: asSystem)
		}
	}

	mutating func validateOptions(asSystem: Bool) throws {
		Logger.setLevel(self.logLevel)

		let certificates = try CertificatesLocation.createAgentCertificats(asSystem: asSystem)
		let listeningAddress: URL

		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		if self.createVM {
			listeningAddress = StorageLocation(asSystem: asSystem).location(name).agentURL
		} else {
			listeningAddress = try StorageLocation(asSystem: asSystem).find(name).agentURL
		}

		if self.options.insecure == false{
			if self.options.caCert == nil {
				self.options.caCert = certificates.caCertURL.path
			}

			if self.options.tlsCert == nil {
				self.options.tlsCert = certificates.clientCertURL.path
			}

			if self.options.tlsKey == nil {
				self.options.tlsKey = certificates.clientKeyURL.path
			}
		}

		try self.options.validate(listeningAddress.absoluteString)
	}

	mutating func validate() throws {
		try self.validateOptions(asSystem: self.asSystem)
	}

	mutating func run() async throws {
		let eventLoop = Root.group.next()
		let grpcClient = try self.options.createClient(on: eventLoop, retries: self.retries, interceptors: self.interceptors)

		do {
			try await self.run(on: eventLoop, client: grpcClient, callOptions: self.callOptions)

			try? await grpcClient.close()
		} catch {
			try? await grpcClient.close()
			throw error
		}
	}

}
