import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO

public protocol CakeAgentAsyncParsableCommand: AsyncParsableCommand {
	var name: String { get }
	var createVM: Bool { get }
	var runMode: Utils.RunMode { get }
	var options: CakeAgentClientOptions { set get }
	var logLevel: Logger.LogLevel { get }
	var retries: ConnectionBackoff.Retries { get }
	var callOptions: CallOptions? { get }
	var interceptors: CakeAgentServiceClientInterceptorFactoryProtocol? { get }

	func run(on: EventLoopGroup, helper: CakeAgentHelper, callOptions: CallOptions?) async
}

extension CakeAgentAsyncParsableCommand {
	public var retries: ConnectionBackoff.Retries {
		.upTo(1)
	}

	public var interceptors: CakeAgentServiceClientInterceptorFactoryProtocol? {
		nil
	}

	public var callOptions: CallOptions? {
		CallOptions(timeLimit: .none)
	}

	public mutating func validateOptions(runMode: Utils.RunMode) throws {
		Logger.setLevel(self.logLevel)

		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let listeningAddress: URL

		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		if self.createVM {
			listeningAddress = StorageLocation(runMode: runMode).location(name).agentURL
		} else {
			listeningAddress = try StorageLocation(runMode: runMode).find(name).agentURL
		}

		if self.options.insecure == false {
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

	public mutating func validate() throws {
		try self.validateOptions(runMode: self.runMode)
	}

	public mutating func run() async throws {
		let eventLoop = Utilities.group.next()
		let helper = try CakeAgentHelper(on: eventLoop, client: self.options.createClient(on: eventLoop, retries: self.retries, interceptors: self.interceptors))

		await self.run(on: eventLoop, helper: helper, callOptions: self.callOptions)

		try? await helper.close()
	}

}
