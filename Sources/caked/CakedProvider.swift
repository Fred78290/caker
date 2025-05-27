import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPortForwarding
import NIOPosix

protocol CakedCommand {
	mutating func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply
}

protocol CakedCommandAsync: CakedCommand {
	mutating func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<Caked_Reply>
}

extension CakedCommand {
	func createCakeAgentClient(on: EventLoopGroup, asSystem: Bool, name: String) throws -> CakeAgentClient {
		let certificates = try CertificatesLocation.createAgentCertificats(asSystem: asSystem)
		let listeningAddress = try StorageLocation(asSystem: asSystem).find(name).agentURL

		return try CakeAgentHelper.createClient(on: on,
		                                        listeningAddress: listeningAddress,
		                                        connectionTimeout: 30,
		                                        caCert: certificates.caCertURL.path,
		                                        tlsCert: certificates.clientCertURL.path,
		                                        tlsKey: certificates.clientKeyURL.path)
	}
}

extension CakedCommandAsync {
	mutating func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		return try self.run(on: on, asSystem: asSystem).wait()
	}
}

protocol CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand
}

class Unimplemented: Error {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}

extension Caked_RunReply {
	private func print(_ out: Data, err: Bool) {
		let output = String(data: out, encoding: .utf8) ?? ""
		let lines = output.split(separator: "\n")

		for line in lines {
			if err {
				Logger(self).error(String(line))
			} else {
				Logger(self).info(String(line))
			}
		}
	}

	func log() {
		if self.stderr.isEmpty == false {
			self.print(self.stderr, err: true)
		}

		if self.stdout.isEmpty == false {
			self.print(self.stdout, err: false)
		}
	}
}

extension Caked_RunCommand: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return RunHandler(request: self, client: try provider.createCakeAgentConnection(vmName: self.vmname))
	}
}

extension Caked_InfoRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return InfosHandler(request: self, client: try provider.createCakeAgentConnection(vmName: self.name))
	}
}

extension Caked_CloneRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return CloneHandler(request: self)
	}
}

extension Caked_MountRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) -> CakedCommand {
		return MountHandler(request: self)
	}

	func directorySharingAttachment() -> [DirectorySharingAttachment] {
		return self.mounts.map { mount in
			DirectorySharingAttachment(
				source: mount.source,
				destination: mount.hasTarget ? mount.target : nil,
				readOnly: mount.readonly,
				name: mount.hasName ? mount.name : nil,
				uid: mount.hasUid ? Int(mount.uid) : nil,
				gid: mount.hasGid ? Int(mount.gid) : nil)
		}
	}
}

extension Caked_TemplateRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) -> CakedCommand {
		return TemplateHandler(request: self)
	}
}

extension Caked_RenameRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return RenameHandler(request: self)
	}
}

extension Caked_CakedCommandRequest: CreateCakedCommand {
	init(command: String, arguments: [String]) {
		self.init()
		self.command = command
		self.arguments = arguments
	}

	func createCommand(provider: CakedProvider) -> CakedCommand {
		return TartHandler(command: self.command, arguments: self.arguments)
	}
}

extension Caked_CommonBuildRequest {
	func buildOptions() throws -> BuildOptions {
		try BuildOptions(request: self)
	}
}

extension Caked_BuildRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return BuildHandler(options: try self.options.buildOptions())
	}
}

extension Caked_LaunchRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return LaunchHandler(options: try self.options.buildOptions(), waitIPTimeout: self.hasWaitIptimeout ? Int(self.waitIptimeout) : 180)
	}
}

extension Caked_PurgeRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		var options = PurgeOptions()

		if self.hasEntries {
			options.entries = self.entries
		}

		if self.hasOlderThan {
			options.olderThan = UInt(self.olderThan)
		} else {
			options.olderThan = nil
		}

		if self.hasSpaceBudget {
			options.spaceBudget = UInt(self.spaceBudget)
		} else {
			options.spaceBudget = nil
		}

		return PurgeHandler(options: options)
	}
}

extension Caked_DeleteRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return DeleteHandler(request: self)
	}
}

extension Caked_ConfigureRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return ConfigureHandler(options: ConfigureOptions(request: self))
	}
}

extension Caked_ListRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return ListHandler(vmonly: self.vmonly)
	}
}

extension Caked_StartRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return try StartHandler(name: self.name, waitIPTimeout: self.hasWaitIptimeout ? Int(self.waitIptimeout) : 120, startMode: .background, asSystem: provider.asSystem)
	}
}

extension Caked_DuplicateRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return DuplicateHandler(request: self)
	}
}

extension Caked_LoginRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return LoginHandler(request: self)
	}
}

extension Caked_LogoutRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return LogoutHandler(request: self)
	}
}

extension Caked_ImageRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return ImageHandler(request: self)
	}
}

extension Caked_RemoteRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return RemoteHandler(request: self)
	}
}

extension Caked_NetworkRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return NetworksHandler(request: self)
	}
}

extension Caked_WaitIPRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return WaitIPHandler(name: self.name, wait: Int(self.timeout))
	}
}

extension Caked_StopRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return StopHandler(request: self)
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
	let asSystem: Bool
	let group: EventLoopGroup
	let certLocation: CertificatesLocation

	init(group: EventLoopGroup, asSystem: Bool) throws {
		self.asSystem = asSystem
		self.group = group
		self.certLocation = try CertificatesLocation.createAgentCertificats(asSystem: asSystem)
	}

	func execute(command: CakedCommand) throws -> Caked_Reply {
		var command = command
		let eventLoop = self.group.next()

		Logger(self).debug("execute: \(command)")

		do {
			if var cmd = command as? CakedCommandAsync {
				let future = try cmd.run(on: eventLoop, asSystem: self.asSystem)

				return try future.wait()
			} else {
				return try command.run(on: eventLoop, asSystem: self.asSystem)
			}
		} catch {
			return Caked_Reply.with { reply in
				if let shellError = error as? ShellError {
					reply.error = Caked_Error(code: shellError.terminationStatus, reason: shellError.error)
				} else if let serviceError = error as? ServiceError {
					reply.error = Caked_Error(code: serviceError.exitCode, reason: serviceError.description)
				} else {
					reply.error = Caked_Error(code: -1, reason: error.localizedDescription)
				}
			}
		}
	}

	func execute(command: CreateCakedCommand) throws -> Caked_Reply {
		try self.execute(command: command.createCommand(provider: self))
	}

	func cakeCommand(request: Caked_CakedCommandRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func build(request: Caked_BuildRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func clone(request: Caked_CloneRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func launch(request: Caked_LaunchRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func start(request: Caked_StartRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func duplicate(request: Caked_DuplicateRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func delete(request: Caked_DeleteRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
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

	func rename(request: Caked_RenameRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func info(request: Caked_InfoRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func run(request: Caked_RunCommand, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func execute(requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, context: GRPCAsyncServerCallContext) async throws {
		_ = try self.execute(command: try ExecuteHandler(provider: self, requestStream: requestStream, responseStream: responseStream, context: context))
	}

	func mount(request: Caked_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func umount(request: Caked_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func createCakeAgentConnection(vmName: String, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentConnection {
		let listeningAddress = try StorageLocation(asSystem: asSystem).find(vmName).agentURL

		return CakeAgentConnection(eventLoop: self.group, listeningAddress: listeningAddress, certLocation: self.certLocation, retries: retries)
	}
}
