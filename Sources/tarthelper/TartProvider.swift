import ArgumentParser
//
//  Greeter.swift
//  tart
//
//  Created by Frederic BOLTZ on 19/11/2024.
//
import Foundation
import GRPC
import GRPCLib

protocol TartdCommand {
	mutating func run(asSystem: Bool) async throws -> String
}

protocol CreateTartdCommand {
	func createCommand() -> TartdCommand
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

extension Tarthelper_TartCommandRequest: CreateTartdCommand {
	init(command: String, arguments: [String]) {
		self.init()
		self.command = command
		self.arguments = arguments
	}

	func createCommand() -> TartdCommand {
		return TartHandler(command: self.command, arguments: self.arguments)
	}
}

extension Tarthelper_BuildRequest: CreateTartdCommand {
	func createCommand() -> TartdCommand {
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

		if self.hasInsecure {
			command.insecure = self.insecure
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

		return command
	}
}

extension Tarthelper_PruneRequest : CreateTartdCommand {	
  func createCommand() -> TartdCommand {
    var command = PruneHandler()
    
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

extension Tarthelper_LaunchRequest: CreateTartdCommand {
	func createCommand() -> TartdCommand {
		var command = LaunchHandler(name: self.name)

		command.dir = self.dir
		command.netBridged = self.netBridged
		command.netHost = self.netHost

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

		if self.hasInsecure {
			command.insecure = self.insecure
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

		return command
	}
}

extension Tarthelper_StartRequest: CreateTartdCommand {
	func createCommand() -> TartdCommand {
		return StartHandler(name: self.name)
	}
}

extension Tarthelper_Error {
	init(code: Int32, reason: String) {
		self.init()

		self.code = code
		self.reason = reason
	}
}

class TartDaemonProvider: @unchecked Sendable, Tarthelper_ServiceAsyncProvider {
	var interceptors: Tarthelper_ServiceServerInterceptorFactoryProtocol? = nil
	let asSystem: Bool

	init(asSystem: Bool) {
		self.asSystem = asSystem
	}

	func execute(command: CreateTartdCommand) async throws -> Tarthelper_TartReply {
		var command = command.createCommand()
		var reply: Tarthelper_TartReply = Tarthelper_TartReply()

		do {
			reply.output = try await command.run(asSystem: self.asSystem)
		} catch {
			reply.error = Tarthelper_Error(code: -1, reason: error.localizedDescription)
		}

		return reply
	}

	func tartCommand(request: Tarthelper_TartCommandRequest, context: GRPCAsyncServerCallContext) async throws
		-> Tarthelper_TartReply
	{
		return try await self.execute(command: request)
	}

	func build(request: Tarthelper_BuildRequest, context: GRPCAsyncServerCallContext) async throws
		-> Tarthelper_TartReply
	{
		return try await self.execute(command: request)
	}

	func launch(request: Tarthelper_LaunchRequest, context: GRPC.GRPCAsyncServerCallContext) async throws
		-> Tarthelper_TartReply
	{
		return try await self.execute(command: request)
	}

	func start(request: Tarthelper_StartRequest, context: GRPC.GRPCAsyncServerCallContext) async throws
		-> Tarthelper_TartReply
	{
		return try await self.execute(command: request)
	}

	func prune(request: Tarthelper_PruneRequest, context: GRPC.GRPCAsyncServerCallContext) async throws
		-> Tarthelper_TartReply
	{
		return try await self.execute(command: request)
	}
}
