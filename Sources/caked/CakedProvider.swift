import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import NIOPortForwarding
import CakeAgentLib

protocol CakedCommand {
	mutating func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String>
}

extension CakedCommand {
	func createCakeAgentClient(on: EventLoopGroup, asSystem: Bool, name: String) throws -> CakeAgentClient {
		let certificates: CertificatesLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem))).createCertificats()
		let listeningAddress = try StorageLocation(asSystem: runAsSystem).find(name).agentURL

		return try CakeAgentHelper.createClient(on: on,
		                                        listeningAddress: listeningAddress,
		                                        connectionTimeout: 30,
		                                        caCert: certificates.caCertURL.path(),
		                                        tlsCert: certificates.clientCertURL.path(),
		                                        tlsKey: certificates.clientKeyURL.path())
	}
}
protocol CreateCakedCommand {
	func createCommand() throws -> CakedCommand
}

private func saveToTempFile(_ data: Data) throws -> String {
	let url = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString)
		.appendingPathExtension("txt")

	try data.write(to: url)

	return url.absoluteURL.path()
}

class Unimplemented: Error {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}

extension Caked_TemplateRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		return TemplateHandler(request: self)
	}
}

extension Caked_RenameRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return RenameHandler(request: self)
	}
}

extension Caked_CakedCommandRequest: CreateCakedCommand {
	init(command: String, arguments: [String]) {
		self.init()
		self.command = command
		self.arguments = arguments
	}

	func createCommand() -> CakedCommand {
		return TartHandler(command: self.command, arguments: self.arguments)
	}
}

extension Caked_CommonBuildRequest {
	func buildOptions() throws -> BuildOptions {
		try BuildOptions(request: self)
	}
}

extension Caked_BuildRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return BuildHandler(options: try self.options.buildOptions())
	}
}

extension Caked_LaunchRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return LaunchHandler(options: try self.options.buildOptions(), waitIPTimeout: self.hasWaitIptimeout ? Int(self.waitIptimeout) : 180)
	}
}

extension Caked_PurgeRequest : CreateCakedCommand {
  func createCommand() throws -> CakedCommand {
	var command = PurgeHandler()

	if self.hasEntries {
	  command.entries = self.entries
	}

	if self.hasOlderThan {
	  command.olderThan = UInt(self.olderThan)
	}

	if self.hasSpaceBudget {
	  command.spaceBudget = UInt(self.spaceBudget)
	}

	return command
  }
}

extension Caked_DeleteRequest : CreateCakedCommand {
  func createCommand() throws -> CakedCommand {
	return DeleteHandler(request: self)
  }
}

extension Caked_ConfigureRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return ConfigureHandler(options: ConfigureOptions(request: self))
	}
}

extension Caked_ListRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return ListHandler(format: self.format == .text ? .text : .json, vmonly: self.vmonly)
	}
}

extension Caked_StartRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return try StartHandler(name: self.name, waitIPTimeout: self.hasWaitIptimeout ? Int(self.waitIptimeout) : 120, startMode: .background)
	}
}

extension Caked_LoginRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return LoginHandler(request: self)
	}
}

extension Caked_LogoutRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return LogoutHandler(request: self)
	}
}

extension Caked_ImageRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return ImageHandler(request: self)
	}
}

extension Caked_RemoteRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return RemoteHandler(request: self)
	}
}

extension Caked_NetworkRequest: CreateCakedCommand {
	func createCommand() throws -> CakedCommand {
		return NetworksHandler(format: self.format == .text ? .text : .json)
	}
}

extension Caked_WaitIPRequest: CreateCakedCommand {
	func createCommand() throws -> any CakedCommand {
		return WaitIPHandler(name: self.name, wait: Int(self.timeout))
	}
}

extension Caked_StopRequest: CreateCakedCommand {
	func createCommand() throws -> any CakedCommand {
		return StopHandler(name: self.name, force: self.force)
	}
}

extension Caked_Error {
	init(code: Int32, reason: String) {
		self.init()

		self.code = code
		self.reason = reason
	}
}

class CakedProvider: @unchecked Sendable, Caked_ServiceAsyncProvider {
	var interceptors: Caked_ServiceServerInterceptorFactoryProtocol? = nil
	let asSystem: Bool
	let group: EventLoopGroup
	let certLocation: CertificatesLocation

	init(group: EventLoopGroup, asSystem: Bool) throws {
		self.asSystem = asSystem
		self.group = group
		self.certLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem))).createCertificats()
	}
	
	func execute(command: CreateCakedCommand) throws -> Caked_Reply {
		var command = try command.createCommand()
		var reply: Caked_Reply = Caked_Reply()
		
		Logger.debug("execute: \(command)")

		do {
			let future = try command.run(on: self.group.next(), asSystem: self.asSystem)

			reply.output = try future.wait()
		} catch {
			if let shellError = error as? ShellError {
				reply.error = Caked_Error(code: shellError.terminationStatus, reason: shellError.error)
			} else {
				reply.error = Caked_Error(code: -1, reason: error.localizedDescription)
			}
		}
		
		return reply
	}
	
	func cakeCommand(request: Caked_CakedCommandRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply{
		return try self.execute(command: request)
	}
	
	func build(request: Caked_BuildRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
	func launch(request: Caked_LaunchRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
	func start(request: Caked_StartRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
	func delete(request: Caked_DeleteRequest, context: GRPCAsyncServerCallContext) async throws -> GRPCLib.Caked_Reply {
		return try self.execute(command: request)
	}

	func configure(request: Caked_ConfigureRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
	func purge(request: Caked_PurgeRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
	func login(request: Caked_LoginRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
	func logout(request: Caked_LogoutRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

    func list(request: Caked_ListRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
    }

    func image(request: Caked_ImageRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
    }

	func remote(request: Caked_RemoteRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
    func template(request: Caked_TemplateRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
    }

	func networks(request: Caked_NetworkRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
	func waitIP(request: Caked_WaitIPRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func stop(request: Caked_StopRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

    func rename(request: GRPCLib.Caked_RenameRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> GRPCLib.Caked_Reply {
		return try self.execute(command: request)
    }

	func info(request: Caked_InfoRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_InfoReply {
		let conn: CakeAgentConnection = try createCakeAgentConnection(vmName: String(request.name))
		
		Logger.debug("execute: \(request)")

		return try conn.info()
	}

	func execute(request: Caked_ExecuteRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_ExecuteReply {
		let conn: CakeAgentConnection = try createCakeAgentConnection(vmName: String(request.name))

		Logger.debug("execute: \(request)")

		return try conn.execute(request: request)
	}

	func shell(requestStream: GRPCAsyncRequestStream<Caked_ShellRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ShellResponse>, context: GRPCAsyncServerCallContext) async throws {

		guard let vmname = context.request.headers.first(name: "CAKEAGENT_VMNAME") else {
			Logger.error(ServiceError("no CAKEAGENT_VMNAME header"))

			throw ServiceError("no CAKEAGENT_VMNAME header")
		}

		Logger.debug("shell: \(vmname)")

		let conn = try createCakeAgentConnection(vmName: vmname)
		
		return try await conn.shell(requestStream: requestStream, responseStream: responseStream)
	}

	func createCakeAgentConnection(vmName: String) throws -> CakeAgentConnection {
		let listeningAddress = try StorageLocation(asSystem: asSystem).find(vmName).agentURL

		return CakeAgentConnection(eventLoop: self.group, listeningAddress: listeningAddress, caCert: self.certLocation.caCertURL.path(), tlsCert: self.certLocation.serverCertURL.path(), tlsKey: self.certLocation.serverKeyURL.path())
	}
}
