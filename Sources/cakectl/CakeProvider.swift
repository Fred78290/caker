import ArgumentParser
import Foundation
@preconcurrency import GRPC
import GRPCLib
import NIO
import NIOPosix
import NIOSSL
import Semaphore

typealias CakeAgentClient = Caked_ServiceNIOClient

extension Caked_Reply {
	func successfull() throws -> Caked_Reply {
		if case .error(let errorMessage) = self.response {
			throw GrpcError(code: Int(errorMessage.code), reason: errorMessage.reason)
		}

		return self
	}
}

extension Caked_RenameRequest {
	init(command: Rename) {
		self.init()
		self.oldname = command.name
		self.newname = command.newName
	}
}

extension Caked_DuplicateRequest {
	init(command: Duplicate) {
		self.init()
		self.from = command.from
		self.to = command.to
		self.resetMacAddress = command.resetMacAddress
	}
}

extension Caked_DeleteRequest {
	init(command: Delete) {
		self.init()
		self.name = command.name
	}
}

extension Caked_ListRequest {
	init(command: List) {
		self.init()
		self.vmonly = command.vmonly
	}
}

extension Caked_CakedCommandRequest {
	init(command: String, arguments: [String]) {
		self.init()
		self.command = command
		self.arguments = arguments
	}
}

extension Caked_CommonBuildRequest {
	init(buildOptions: BuildOptions) throws {
		let mounts = buildOptions.mounts.map{$0.description}
		let networks = buildOptions.networks.map{$0.description}
		let sockets = buildOptions.sockets.map{$0.description}

		self.init()
		self.name = buildOptions.name
		self.cpu = Int32(buildOptions.cpu)
		self.memory = Int32(buildOptions.memory)
		self.diskSize = Int32(buildOptions.diskSize)
		self.user = buildOptions.user
		self.mainGroup = buildOptions.mainGroup
		self.sshPwAuth = buildOptions.clearPassword
		self.autostart = buildOptions.autostart
		self.nested = buildOptions.nested
		self.image = buildOptions.image

		if mounts.isEmpty == false {
			self.mounts = mounts.joined(separator: ",")
		}

		if networks.isEmpty == false {
			self.networks = networks.joined(separator: ",")
		}

		if sockets.isEmpty == false {
			self.sockets = sockets.joined(separator: ",")
		}

		if let console = buildOptions.consoleURL {
			self.console = console.description
		}

		if buildOptions.forwardedPorts.isEmpty == false {
			self.forwardedPort = buildOptions.forwardedPorts.map { forwardedPort in
				return forwardedPort.description
			}.joined(separator: ",")
		}

		if let sshAuthorizedKey = buildOptions.sshAuthorizedKey {
			self.sshAuthorizedKey = try Data(contentsOf: URL(filePath: sshAuthorizedKey))
		}

		if let vendorData = buildOptions.vendorData {
			self.vendorData = try Data(contentsOf: URL(filePath: vendorData))
		}

		if let userData = buildOptions.userData {
			if userData == "-" {
				if let input = (readLine(strippingNewline: true))?.split(whereSeparator: {$0 == " "}).map (String.init) {
					self.userData = input.joined(separator: "\n").data(using: .utf8)!
				}
			} else {
				self.userData = try Data(contentsOf: URL(filePath: userData))
			}
		}

		if let networkConfig = buildOptions.networkConfig {
			self.networkConfig = try Data(contentsOf: URL(filePath: networkConfig))
		}
	}
}

extension Caked_BuildRequest {
	init(buildOptions: BuildOptions) throws {
		self.init()
		self.options = try Caked_CommonBuildRequest(buildOptions: buildOptions)
	}
}

extension Caked_CloneRequest {
	init(command: Clone) {
		self.init()
		self.sourceName = command.sourceName
		self.targetName = command.newName
		self.insecure = command.insecure
		self.concurrency = UInt32(command.concurrency)
		self.deduplicate = command.deduplicate
	}
}

extension Caked_LaunchRequest {
	init(command: Launch) throws {
		self.init()
		self.options = try Caked_CommonBuildRequest(buildOptions: command.buildOptions)
		self.waitIptimeout = Int32(command.waitIPTimeout)
	}
}

extension Caked_StartRequest {
	init(command: Start) {
		self.init()
		self.name = command.name
	}
}

extension Caked_StopRequest {
	init(command: Stop) {
		self.init()
		self.name = command.name
		self.force = command.force
	}
}

extension Caked_PurgeRequest {
	init (command: Purge) {
		self.init()
		self.entries = command.entries

		if let olderThan = command.olderThan {
			self.olderThan = Int32(olderThan)
		}

		if let cacheBudget = command.cacheBudget {
			self.cacheBudget = Int32(cacheBudget)
		}

		if let spaceBudget = command.spaceBudget {
			self.spaceBudget = Int32(spaceBudget)
		}
	}
}

extension Caked_LoginRequest {
	init (command: Login) throws {
		self.init()

		self.host = command.host
		self.insecure = command.insecure
		self.noValidate = command.noValidate

		if let username = command.username {
			self.username = username
		}

		if command.passwordStdin {
			if let password = readLine(strippingNewline: true) {
				self.password = password
			}
		} else if let password = command.password {
			self.password = password
		}
	}
}

extension Caked_LogoutRequest {
	init (command: Logout) {
		self.init()
		self.host = command.host
	}
}

extension Caked_ConfigureRequest {
	init (options: ConfigureOptions) {
		self.init()
		self.name = options.name

		if let cpu = options.cpu {
			self.cpu = Int32(cpu)
		}

		if let memory = options.memory {
			self.memory = Int32(memory)
		}

		if let diskSize = options.diskSize {
			self.diskSize = Int32(diskSize)
		}

		if let displayRefit = options.displayRefit {
			self.displayRefit = displayRefit
		}

		if let autostart = options.autostart {
			self.autostart = autostart
		}

		if let nested = options.nested {
			self.nested = nested
		}

		if let mounts = options.mounts {
			self.mounts = mounts.map{$0.description}.joined(separator: ",")
		}

		if let networks = options.networks {
			self.networks = networks.map{$0.description}.joined(separator: ",")
		}

		if let sockets = options.sockets {
			self.networks = sockets.map{$0.description}.joined(separator: ",")
		}

		if let consoleURL = options.consoleURL {
			self.console = consoleURL.description
		}

		if let forwardedPort = options.forwardedPort {
			self.forwardedPort = forwardedPort.map{$0.description}.joined(separator: ",")
		}

		self.randomMac = options.randomMAC
	}
}

extension Caked_InfoRequest {
	init(command: Infos) {
		self.init()
		self.name = command.name
	}
}

extension Caked_ImageRequest {
	init(command: ImagesManagement.ListImage) {
		self.init()

		self.name = command.name
		self.command = .list
	}

	init(command: ImagesManagement.InfoImage) {
		self.init()

		self.name = command.name
		self.command = .info
	}

	init(command: ImagesManagement.PullImage) {
		self.init()

		self.name = command.name
		self.command = .pull
	}
}

extension Caked_TemplateRequest {
	init(command: Template.CreateTemplate) {
		self.init()
		var add: Caked_TemplateRequestAdd = Caked_TemplateRequestAdd()

		add.sourceName = command.name
		add.templateName = command.template

		self.command = .add
		self.create = add
	}

	init(command: Template.DeleteTemplate) {
		self.init()

		self.command = .delete
		self.delete = command.name
	}

	init(command: Template.ListTemplate) {
		self.init()

		self.command = .list
	}
}

extension Caked_RemoteRequest {
	init(command: Remote.AddRemote) {
		self.init()
		var add: Caked_RemoteRequestAdd = Caked_RemoteRequestAdd()

		add.name = command.remote
		add.url = command.url

		self.command = .add
		self.add = add
	}

	init(command: Remote.DeleteRemote) {
		self.init()

		self.command = .delete
		self.delete = command.remote
	}

	init(command: Remote.ListRemote) {
		self.init()

		self.command = .list
	}
}

extension Caked_NetworkRequest {
	init(command: Networks.Infos) {
		self.init()

		self.command = .status
		self.name = command.name
	}

	init(command: Networks.List) {
		self.init()

		self.command = .infos
	}

	init(command: Networks.Create) {
		self.init()

		self.command = .create
		self.create = Caked_CreateNetworkRequest.with {
			$0.mode = command.networkOptions.mode == .shared ? .shared : .host
			$0.name = command.networkOptions.name
			$0.gateway = command.networkOptions.gateway
			$0.dhcpEnd = command.networkOptions.dhcpEnd
			$0.netmask = command.networkOptions.subnetMask
			$0.uuid = command.networkOptions.interfaceID
			if let nat66Prefix = command.networkOptions.nat66Prefix {
				$0.nat66Prefix = nat66Prefix
			}
		}
	}

	init(command: Networks.Configure) {
		self.init()

		self.command = .configure
		self.configure = Caked_ConfigureNetworkRequest.with {
			$0.name = command.networkOptions.name

			if let gateway = command.networkOptions.gateway {
				$0.gateway = gateway
			}

			if let dhcpEnd = command.networkOptions.dhcpEnd {
				$0.dhcpEnd = dhcpEnd
			}

			if let subnetMask = command.networkOptions.subnetMask {
				$0.netmask = subnetMask
			}

			if let interfaceID = command.networkOptions.interfaceID {
				$0.uuid = interfaceID
			}

			if let nat66Prefix = command.networkOptions.nat66Prefix {
				$0.nat66Prefix = nat66Prefix
			}
		}
	}

	init(command: Networks.Delete) {
		self.init()

		self.command = .remove
		self.name = command.name
	}

	init(command: Networks.Start) {
		self.init()

		self.command = .start
		self.name = command.name
	}

	init(command: Networks.Stop) {
		self.init()

		self.command = .shutdown
		self.name = command.name
	}
}

extension Caked_WaitIPRequest {
	init(command: WaitIP) {
		self.init()

		self.name = command.name
		self.timeout = Int32(command.wait)
	}
}

extension Caked_MountRequest {
	init(command: Mount) {
		self.init()

		self.name = command.name
		self.command = .add
		self.mounts = command.mounts.map { mount in
			Caked_MountVirtioFS.with {
				$0.name = mount.name
				$0.source = mount.source
				$0.uid = Int32(mount.uid)
				$0.gid	= Int32(mount.gid)
				if let destination = mount.destination {
					$0.target = destination
				}
			}
		}
	}

	init(command: Umount) {
		self.init()

		self.name = command.name
		self.command = .delete
		self.mounts = command.mounts.map{ mount in
			Caked_MountVirtioFS.with {
				$0.name = mount.name
				$0.source = mount.source
				$0.uid = Int32(mount.uid)
				$0.gid	= Int32(mount.gid)
				if let destination = mount.destination {
					$0.target = destination
				}
			}
		}
	}
}


extension CakeAgentClient {
	internal func exec(name: String,
	                   command: CakedChannelStreamer.ExecuteCommand,
	                   inputHandle: FileHandle = FileHandle.standardInput,
	                   outputHandle: FileHandle = FileHandle.standardOutput,
	                   errorHandle: FileHandle = FileHandle.standardError,
	                   callOptions: CallOptions? = nil) async throws -> Int32 {
		let handler = CakedChannelStreamer(inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle)
		var callOptions = callOptions ?? CallOptions()
		
		callOptions.timeLimit = .none
		callOptions.customMetadata.add(name: "CAKEAGENT_VMNAME", value: name)

		return try await handler.stream(command: command) {
			return self.execute(callOptions: callOptions, handler: handler.handleResponse)
		}
	}

	public func exec(name: String,
	                 command: String,
	                 arguments: [String],
	                 inputHandle: FileHandle = FileHandle.standardInput,
	                 outputHandle: FileHandle = FileHandle.standardOutput,
	                 errorHandle: FileHandle = FileHandle.standardError,
	                 callOptions: CallOptions? = nil) async throws -> Int32 {
		return try await self.exec(name: name, command: .execute(command, arguments), inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle, callOptions: callOptions)
	}

	public func shell(name: String,
	                  inputHandle: FileHandle = FileHandle.standardInput,
	                  outputHandle: FileHandle = FileHandle.standardOutput,
	                  errorHandle: FileHandle = FileHandle.standardError,
	                  callOptions: CallOptions? = nil) async throws -> Int32 {
		return try await self.exec(name: name, command: .shell(), inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle, callOptions: callOptions)
	}
}
