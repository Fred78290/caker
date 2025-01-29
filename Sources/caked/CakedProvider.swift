import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import NIOPortForwarding

protocol CakedCommand {
	mutating func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String>
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

extension Caked_CommonBuildRequest {
	func buildOptions() -> BuildOptions {
		var options: BuildOptions = BuildOptions()

		options.name = self.name
		options.displayRefit = false

		if self.hasCpu {
			options.cpu = UInt16(self.cpu)
		} else {
			options.cpu = 1
		}

		if self.hasMemory {
			options.memory = UInt64(self.memory)
		} else {
			options.memory = 512
		}

		if self.hasDiskSize {
			options.diskSize = UInt16(self.diskSize)
		} else {
			options.diskSize = 20
		}

		if self.hasUser {
			options.user = self.user
		} else {
			options.user = "admin"
		}

		if self.hasPassword {
			options.password = self.password
		} else {
			options.password = nil
		}

		if self.hasMainGroup {
			options.mainGroup = self.mainGroup
		} else {
			options.mainGroup = "admin"
		}

		if self.hasSshPwAuth {
			options.clearPassword = self.sshPwAuth
		} else {
			options.clearPassword = false
		}

		if self.hasNested {
			options.nested = self.nested
		} else {
			options.nested = true
		}

		if self.hasAutostart {
			options.autostart = self.autostart
		} else {
			options.autostart = false
		}

		if self.hasImage {
			options.image = self.image
		} else {
			options.image = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img"
		}

		if self.hasSshAuthorizedKey {
			options.sshAuthorizedKey = try? saveToTempFile(self.sshAuthorizedKey)
		} else {
			options.sshAuthorizedKey = nil
		}

		if self.hasUserData {
			options.userData = try? saveToTempFile(self.userData)
		} else {
			options.userData = nil
		}

		if self.hasVendorData {
			options.vendorData = try? saveToTempFile(self.vendorData)
		} else {
			options.vendorData = nil
		}

		if self.hasNetworkConfig {
			options.networkConfig = try? saveToTempFile(self.networkConfig)
		} else {
			options.networkConfig = nil
		}

		if self.hasForwardedPort {
			options.forwardedPort = self.forwardedPort.components(separatedBy: ",").map { argument in
				return ForwardedPort(argument: argument)
			}
		} else {
			options.forwardedPort = []
		}

		if self.hasMounts {
			options.mounts = self.mounts.components(separatedBy: ",")
		} else {
			options.mounts = []
		}

		if self.hasNetBridged {
			options.netBridged = self.netBridged.components(separatedBy: ",")
		} else {
			options.netBridged = []
		}

//		if self.hasNetHost {
//			options.netHost = self.netHost
//		} else {
//			options.netHost = false
//		}
//
//		if self.hasNetSofnet {
//			options.netSoftnet = self.netSofnet
//		} else {
//			options.netSoftnet = false
//		}
//
//		if self.hasNetSoftnetAllow {
//			options.netSoftnetAllow = self.netSoftnetAllow
//		} else {
//			options.netSoftnetAllow = nil
//		}

		return options
	} 
}

extension Caked_BuildRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		return BuildHandler(options: self.options.buildOptions())
	}
}

extension Caked_LaunchRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		return LaunchHandler(options: self.options.buildOptions(), waitIPTimeout: self.hasWaitIptimeout ? Int(self.waitIptimeout) : 180)
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

extension Caked_ConfigureRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		var options = ConfigureOptions()

		options.name = self.name
		options.displayRefit = false

		if self.hasCpu {
			options.cpu = UInt16(self.cpu)
		} else {
			options.cpu = 1
		}

		if self.hasMemory {
			options.memory = UInt64(self.memory)
		} else {
			options.memory = 512
		}

		if self.hasDiskSize {
			options.diskSize = UInt16(self.diskSize)
		} else {
			options.diskSize = 20
		}

		if self.hasNested {
			options.nested = self.nested
		} else {
			options.nested = false
		}

		if self.hasAutostart {
			options.autostart = self.autostart
		} else {
			options.autostart = false
		}

		if self.hasMounts {
			options.mount = self.mounts.components(separatedBy: ",")
		} else {
			options.mount = []
		}

		if self.hasNetBridged {
			options.netBridged = self.netBridged.components(separatedBy: ",")
		} else {
			options.netBridged = []
		}

//		if self.hasNetHost {
//			options.netHost = self.netHost
//		} else {
//			options.netHost = false
//		}
//
//		if self.hasNetSoftnet {
//			options.netSoftnet = self.netSoftnet
//		} else {
//			options.netSoftnet = false
//		}
//
//		if self.hasNetSoftnetAllow {
//			options.netSoftnetAllow = self.netSoftnetAllow
//		} else {
//			options.netSoftnetAllow = nil
//		}

		if self.hasRandomMac {
			options.randomMAC = self.randomMac
		}

		if self.hasForwardedPort {
			options.forwardedPort = []

			for forwardedPort in self.forwardedPort.components(separatedBy: ",") {
				options.forwardedPort.append(ForwardedPort(argument: forwardedPort))
			}
		}

		return ConfigureHandler(options: options)
	}
}

extension Caked_StartRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		return StartHandler(name: self.name, waitIPTimeout: self.hasWaitIptimeout ? Int(self.waitIptimeout) : 120)
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

extension Caked_NetworkRequest: CreateCakedCommand {
	func createCommand() -> CakedCommand {
		return NetworksHandler(format: self.format == .text ? .text : .json)
	}
}

extension Caked_WaitIPRequest: CreateCakedCommand {
	func createCommand() -> any CakedCommand {
		return WaitIPHandler(name: self.name, wait: Int(self.timeout))
	}
}

extension Caked_StopRequest: CreateCakedCommand {
	func createCommand() -> any CakedCommand {
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
		var command = command.createCommand()
		var reply: Caked_Reply = Caked_Reply()
		
		do {
			let future = try command.run(on: self.group.any(), asSystem: self.asSystem)

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
	
	func configure(request: Caked_ConfigureRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
	func purge(request: Caked_PurgeRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply
	{
		return try self.execute(command: request)
	}
	
	func login(request: Caked_LoginRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}
	
	func remote(request: Caked_RemoteRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
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

	func info(request: Caked_InfoRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_InfoReply {
		let conn = try createCakeAgentConnection(vmName: String(request.name))

		return try await conn.info(context: context)
	}

	func execute(request: Caked_ExecuteRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_ExecuteReply {
		let conn = try createCakeAgentConnection(vmName: String(request.name))

		return try await conn.execute(request: request, context: context)
	}

	func shell(requestStream: GRPCAsyncRequestStream<Caked_ShellRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ShellResponse>, context: GRPCAsyncServerCallContext) async throws {
		guard let vmname = context.request.headers.first(name: "CAKEAGENT_VMNAME") else {
			throw ServiceError("no CAKEAGENT_VMNAME header")
		}

		let conn = try createCakeAgentConnection(vmName: vmname)
		
		return try await conn.shell(requestStream: requestStream, responseStream: responseStream, context: context)
	}

	func createCakeAgentConnection(vmName: String) throws -> CakeAgentConnection {
		let listeningAddress = try StorageLocation(asSystem: asSystem).find(vmName).agentURL

		return CakeAgentConnection(eventLoop: self.group, listeningAddress: listeningAddress, caCert: self.certLocation.caCertURL.path(), tlsCert: self.certLocation.serverCertURL.path(), tlsKey: self.certLocation.serverKeyURL.path())
	}
}
