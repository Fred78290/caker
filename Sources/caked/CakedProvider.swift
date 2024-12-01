import ArgumentParser
import Foundation
import GRPC
import GRPCLib

protocol CakedCommand {
	mutating func run(asSystem: Bool) async throws -> String
}

protocol CreateCakedCommand {
	func createCommand() -> CakedCommand
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

extension Caked_BuildRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		var command = BuildHandler(name: self.name)

		if self.hasCpu {
			command.cpu = UInt16(self.cpu)
		}

		if self.hasMemory {
			command.memory = UInt64(self.memory)
		}

		if self.hasDiskSize {
			command.diskSize = UInt16(self.diskSize)
		}

		if self.hasUser {
			command.user = self.user
		}

		if self.hasSshPwAuth {
			command.clearPassword = self.sshPwAuth
		}

		if self.hasNested {
			command.nested = self.nested
		}

		if self.hasAutostart {
			command.autostart = self.autostart
		}

		if self.hasCloudImage {
			command.cloudImage = self.cloudImage
		}

		if self.hasAliasImage {
			command.aliasImage = self.aliasImage
		}

		if self.hasFromImage {
			command.fromImage = self.fromImage
		}

		if self.hasOciImage {
			command.ociImage = self.ociImage
		}

		if self.hasRemoteContainerServer {
			command.remoteContainerServer = self.remoteContainerServer
		}

		if self.hasSshAuthorizedKey {
			command.sshAuthorizedKey = try? saveToTempFile(self.sshAuthorizedKey)
		}

		if self.hasUserData {
			command.userData = try? saveToTempFile(self.userData)
		}

		if self.hasVendorData {
			command.vendorData = try? saveToTempFile(self.vendorData)
		}

		if self.hasNetworkConfig {
			command.networkConfig = try? saveToTempFile(self.networkConfig)
		}

		if self.hasForwardedPort {
			command.forwardedPort = self.forwardedPort.components(separatedBy: ",").map { argument in
				return ForwardedPort(argument: argument)
			}
		}

		return command
	}
}

extension Caked_PurgeRequest : CreateCakedCommand {
  func createCommand() -> CakedCommand {
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

extension Caked_LaunchRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		var command = LaunchHandler(name: self.name)

		if self.hasForwardedPort {
			command.forwardedPort = self.forwardedPort.components(separatedBy: ",").map { argument in
				return ForwardedPort(argument: argument)
			}
		}

		if self.hasDir {
			command.dir = self.dir.components(separatedBy: ",")
		}

		if self.hasNetBridged {
			command.netBridged = self.netBridged.components(separatedBy: ",")
		}

		if self.hasNetHost {
			command.netHost = self.netHost
		}

		if self.hasNetSofnet {
			command.netSoftnet = self.netSofnet
		}

		if self.hasCpu {
			command.cpu = UInt16(self.cpu)
		}

		if self.hasMemory {
			command.memory = UInt64(self.memory)
		}

		if self.hasDiskSize {
			command.diskSize = UInt16(self.diskSize)
		}

		if self.hasUser {
			command.user = self.user
		}

		if self.hasSshPwAuth {
			command.clearPassword = self.sshPwAuth
		}

		if self.hasAutostart {
			command.autostart = self.autostart
		}

		if self.hasCloudImage {
			command.cloudImage = self.cloudImage
		}

		if self.hasAliasImage {
			command.aliasImage = self.aliasImage
		}

		if self.hasFromImage {
			command.fromImage = self.fromImage
		}

		if self.hasOciImage {
			command.ociImage = self.ociImage
		}

		if self.hasRemoteContainerServer {
			command.remoteContainerServer = self.remoteContainerServer
		}

		if self.hasSshAuthorizedKey {
			command.sshAuthorizedKey = try? saveToTempFile(self.sshAuthorizedKey)
		}

		if self.hasUserData {
			command.userData = try? saveToTempFile(self.userData)
		}

		if self.hasVendorData {
			command.vendorData = try? saveToTempFile(self.vendorData)
		}

		if self.hasNetworkConfig {
			command.networkConfig = try? saveToTempFile(self.networkConfig)
		}

		if self.hasNested {
			command.nested = self.nested
		}

		return command
	}
}

extension Caked_ConfigureRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		return ConfigureHandler(name: self.name)
	}
}

extension Caked_StartRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		return StartHandler(name: self.name)
	}
}

extension Caked_LoginRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		return LoginHandler(username: self.username, password: self.password, insecure: insecure, noValidate: noValidate)
	}
}

extension Caked_RemoteRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		return RemoteHandler(request: self)
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
	
	init(asSystem: Bool) {
		self.asSystem = asSystem
	}
	
	func execute(command: CreateCakedCommand) async throws -> Caked_Reply {
		var command = command.createCommand()
		var reply: Caked_Reply = Caked_Reply()
		
		do {
			reply.output = try await command.run(asSystem: self.asSystem)
		} catch {
			reply.error = Caked_Error(code: -1, reason: error.localizedDescription)
		}
		
		return reply
	}
	
	func cakeCommand(request: Caked_CakedCommandRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply
	{
		return try await self.execute(command: request)
	}
	
	func build(request: Caked_BuildRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply
	{
		return try await self.execute(command: request)
	}
	
	func launch(request: Caked_LaunchRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Caked_Reply
	{
		return try await self.execute(command: request)
	}
	
	func start(request: Caked_StartRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Caked_Reply
	{
		return try await self.execute(command: request)
	}
	
	func configure(request: Caked_ConfigureRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try await self.execute(command: request)
	}
	
	func purge(request: Caked_PurgeRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Caked_Reply
	{
		return try await self.execute(command: request)
	}
	
	func login(request: Caked_LoginRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try await self.execute(command: request)
	}
	
	func remote(request: Caked_RemoteRequest, context: GRPCAsyncServerCallContext) async throws -> GRPCLib.Caked_Reply {
		return try await self.execute(command: request)
	}
	
}
