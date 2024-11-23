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
	mutating func run() async throws -> String
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

extension Tartd_TartCommandRequest: CreateTartdCommand {
	init(command: String, arguments: [String]) {
		self.init()
		self.command = command
		self.arguments = arguments
	}

	func createCommand() -> TartdCommand {
		return TartHandler(command: self.command, arguments: self.arguments)
	}
}

extension Tartd_BuildRequest: CreateTartdCommand {
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

extension Tartd_LaunchRequest: CreateTartdCommand {
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

extension Tartd_StartRequest: CreateTartdCommand {
	func createCommand() -> TartdCommand {
		return StartHandler(name: self.name)
	}
}

extension Tartd_Error {
	init(code: Int32, reason: String) {
		self.init()

		self.code = code
		self.reason = reason
	}
}
class TartDaemonProvider: @unchecked Sendable, Tartd_ServiceAsyncProvider {
	var interceptors: Tartd_ServiceServerInterceptorFactoryProtocol? = nil

	func execute(command: CreateTartdCommand) async throws -> Tartd_TartReply {
		var command = command.createCommand()
		var reply: Tartd_TartReply = Tartd_TartReply()

		do {
			reply.output = try await command.run()
		} catch {
			reply.error = Tartd_Error(code: -1, reason: error.localizedDescription)
		}

		return reply
	}

	func tartCommand(request: Tartd_TartCommandRequest, context: GRPCAsyncServerCallContext) async throws
		-> Tartd_TartReply
	{
		return try await self.execute(command: request)
	}

	func build(request: Tartd_BuildRequest, context: GRPCAsyncServerCallContext) async throws
		-> Tartd_TartReply
	{
		return try await self.execute(command: request)
	}

	func launch(request: Tartd_LaunchRequest, context: GRPC.GRPCAsyncServerCallContext) async throws
		-> Tartd_TartReply
	{
		return try await self.execute(command: request)
	}

	func start(request: Tartd_StartRequest, context: GRPC.GRPCAsyncServerCallContext) async throws
		-> Tartd_TartReply
	{
		return try await self.execute(command: request)
	}
}
