import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPortForwarding
import NIOPosix

public protocol CakedCommand {
	mutating func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply
	func replyError(error: Error) -> Caked_Reply
}

public protocol CakedCommandAsync: CakedCommand {
	mutating func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply
}

extension CakedCommand {
	public func createCakeAgentClient(on: EventLoopGroup, runMode: Utils.RunMode, name: String) throws -> CakeAgentClient {
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let listeningAddress = try StorageLocation(runMode: runMode).find(name).agentURL

		return try CakeAgentHelper.createClient(
			on: on,
			listeningAddress: listeningAddress,
			connectionTimeout: 30,
			caCert: certificates.caCertURL.path,
			tlsCert: certificates.clientCertURL.path,
			tlsKey: certificates.clientKeyURL.path)
	}
}

extension CakedCommandAsync {
	mutating func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		do {
			var handler = self

			return try on.makeFutureWithTask {
				return await handler.run(on: on, runMode: runMode)
			}.wait()
		} catch {
			return self.replyError(error: error)
		}
	}
}

protocol CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand
}

public class Unimplemented: Error {
	let description: String

	init(_ what: String) {
		self.description = what
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

extension Caked_MountRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) -> CakedCommand {
		return MountHandler(request: self)
	}

	func directorySharingAttachment() -> DirectorySharingAttachments {
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

extension Caked_CommonBuildRequest {
	func buildOptions() throws -> BuildOptions {
		try BuildOptions(request: self)
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

		options.entries = .caches

		if self.hasEntries {
			if let entries = PurgeOptions.PurgeEntry(rawValue: self.entries) {
				options.entries = entries
			}
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
		return try StartHandler(name: self.name, waitIPTimeout: self.hasWaitIptimeout ? Int(self.waitIptimeout) : 120, startMode: .background, runMode: provider.runMode)
	}
}

extension Caked_RestartRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return RestartHandler(request: self)
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

extension Caked_CloneRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return PullHandler(request: self)
	}
}

extension Caked_PushRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return PushHandler(request: self)
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

extension Caked_SuspendRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return SuspendHandler(request: self)
	}
}

extension Caked_PingRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return PingHandler(request: self, client: try provider.createCakeAgentConnection(vmName: self.name))
	}
}

class CakedProvider: @unchecked Sendable, Caked_ServiceAsyncProvider {
	let runMode: Utils.RunMode
	let group: EventLoopGroup
	let certLocation: CertificatesLocation

	init(group: EventLoopGroup, runMode: Utils.RunMode) throws {
		self.runMode = runMode
		self.group = group
		self.certLocation = try CertificatesLocation.createAgentCertificats(runMode: runMode)
	}

	func execute(command: CakedCommand) throws -> Caked_Reply {
		var command = command
		let eventLoop = self.group.next()

		Logger(self).debug("execute: \(command)")

		return command.run(on: eventLoop, runMode: self.runMode)
	}

	func execute(command: CreateCakedCommand) throws -> Caked_Reply {
		try self.execute(command: command.createCommand(provider: self))
	}

	func build(request: Caked_BuildRequest, responseStream: GRPCAsyncResponseStreamWriter<Caked_BuildStreamReply>, context: GRPCAsyncServerCallContext) async throws {
		_ = try self.execute(command: BuildHandler(provider: self, options: request.options.buildOptions(), responseStream: responseStream, context: context))
	}
	
	func launch(request: Caked_LaunchRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func start(request: Caked_StartRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func restart(request: Caked_RestartRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
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

	func clone(request: Caked_CloneRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func push(request: Caked_PushRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
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

	func suspend(request: Caked_Caked.VMRequest.SuspendRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Caked.Reply {
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

	func ping(request: Caked_PingRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		Caked_Reply()
	}
	
	func currentStatus(request: Caked_CurrentStatusRequest, responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, context: GRPCAsyncServerCallContext) async throws {
		
		_ = try self.execute(command: CurrentStatusHandler(provider: self, request: request, responseStream: responseStream))
	}

	func vncURL(request: Caked_InfoRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: VncURLHandler(request: request))
	}

	func createCakeAgentConnection(vmName: String, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentConnection {
		let listeningAddress = try StorageLocation(runMode: self.runMode).find(vmName).agentURL

		return CakeAgentConnection(eventLoop: self.group, listeningAddress: listeningAddress, certLocation: self.certLocation, retries: retries)
	}
}
