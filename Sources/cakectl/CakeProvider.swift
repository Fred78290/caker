import ArgumentParser
import Foundation
@preconcurrency import GRPC
import GRPCLib
import NIO
import NIOPosix
import NIOSSL
import Semaphore

extension Caked_RenameRequest {
	init(command: Rename) {
		self.init()
		self.oldname = command.rename.name
		self.newname = command.rename.newName
	}
}

extension Caked_DuplicateRequest {
	init(command: Duplicate) {
		self.init()
		self.from = command.duplicate.from
		self.to = command.duplicate.to
		self.resetMacAddress = command.duplicate.resetMacAddress
	}
}

extension Caked_DeleteRequest {
	init(command: Delete) {
		self.init()

		if command.delete.all {
			self.all = true
		} else {
			self.names = Caked_DeleteRequest.VMNames.with {
				$0.list = command.delete.names
			}
		}
	}
}

extension Caked_ListRequest {
	init(command: List) {
		self.init()
		self.vmonly = !command.all
	}
}

extension Caked_CloneRequest {
	init(command: Pull) {
		self.init()
		self.name = command.pull.name
		self.image = command.pull.image
		self.insecure = command.pull.insecure
	}
}

extension Caked_PushRequest {
	init(command: Push) {
		self.init()
		self.localName = command.push.localName
		self.remoteNames = command.push.remoteNames
		self.insecure = command.push.insecure
		self.chunkSize = Int32(command.push.chunkSize)
		self.concurrency = Int32(command.push.concurrency)
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
		self.force = command.stop.force

		if command.stop.all {
			self.all = true
		} else {
			self.names = Caked_StopRequest.VMNames.with {
				$0.list = command.stop.names
			}
		}
	}
}

extension Caked_SuspendRequest {
	init(command: Suspend) {
		self.init()
		self.names = command.names
	}
}

extension Caked_PurgeRequest {
	init(command: Purge) {
		self.init()
		self.entries = command.purge.entries.rawValue

		if let olderThan = command.purge.olderThan {
			self.olderThan = Int32(olderThan)
		}

		if let spaceBudget = command.purge.spaceBudget {
			self.spaceBudget = Int32(spaceBudget)
		}
	}
}

extension Caked_LoginRequest {
	init(command: Login) throws {
		self.init()

		self.host = command.login.host
		self.insecure = command.login.insecure
		self.noValidate = command.login.noValidate

		if let username = command.login.username {
			self.username = username
		}

		if command.login.passwordStdin {
			if let password = readLine(strippingNewline: true) {
				self.password = password
			}
		} else if let password = command.login.password {
			self.password = password
		}
	}
}

extension Caked_LogoutRequest {
	init(command: Logout) {
		self.init()
		self.host = command.host
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

		self.command = .add
		self.createRequest = Caked_TemplateRequest.TemplateRequestAdd.with {
			$0.sourceName = command.template.name
			$0.templateName = command.template.template
		}
	}

	init(command: Template.DeleteTemplate) {
		self.init()

		self.command = .delete
		self.deleteRequest = command.template.name
	}

	init(command: Template.ListTemplate) {
		self.init()

		self.command = .list
	}
}

extension Caked_RemoteRequest {
	init(command: Remote.AddRemote) {
		self.init()

		self.command = .add
		self.addRequest = Caked_RemoteRequest.RemoteRequestAdd.with {
			$0.name = command.remote
			$0.url = command.url
		}
	}

	init(command: Remote.DeleteRemote) {
		self.init()

		self.command = .delete
		self.deleteRequest = command.remote
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

		self.command = .new
		self.create = Caked_NetworkRequest.CreateNetworkRequest.with {
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

		self.command = .set
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

		self.name = command.waitip.name
		self.timeout = Int32(command.waitip.wait)
	}
}

extension Caked_MountRequest {
	init(command: Mount) {
		self.init()

		self.name = command.mount.name
		self.command = .mount
		self.mounts = command.mount.mounts.map { mount in
			Caked_MountVirtioFS.with {
				$0.name = mount.name
				$0.source = mount.source
				$0.uid = Int32(mount.uid)
				$0.gid = Int32(mount.gid)
				if let destination = mount.destination {
					$0.target = destination
				}
			}
		}
	}

	init(command: Umount) {
		self.init()

		self.name = command.umount.name
		self.command = .umount
		self.mounts = command.umount.mounts.map { mount in
			Caked_MountVirtioFS.with {
				$0.name = mount.name
				$0.source = mount.source
				$0.uid = Int32(mount.uid)
				$0.gid = Int32(mount.gid)
				if let destination = mount.destination {
					$0.target = destination
				}
			}
		}
	}
}

extension CakedServiceClient {
	internal func exec(
		name: String,
		command: CakedChannelStreamer.ExecuteCommand,
		inputHandle: FileHandle = FileHandle.standardInput,
		outputHandle: FileHandle = FileHandle.standardOutput,
		errorHandle: FileHandle = FileHandle.standardError,
		callOptions: CallOptions? = nil
	) async throws -> Int32 {
		let handler = CakedChannelStreamer(inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle)
		var callOptions = callOptions ?? CallOptions()

		callOptions.timeLimit = .none
		callOptions.customMetadata.add(name: "CAKEAGENT_VMNAME", value: name)

		return try await handler.stream(command: command) {
			return self.execute(callOptions: callOptions, handler: handler.handleResponse)
		}
	}

	public func exec(
		name: String,
		command: String,
		arguments: [String],
		inputHandle: FileHandle = FileHandle.standardInput,
		outputHandle: FileHandle = FileHandle.standardOutput,
		errorHandle: FileHandle = FileHandle.standardError,
		callOptions: CallOptions? = nil
	) async throws -> Int32 {
		return try await self.exec(name: name, command: .execute(command, arguments), inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle, callOptions: callOptions)
	}

	public func shell(
		name: String,
		inputHandle: FileHandle = FileHandle.standardInput,
		outputHandle: FileHandle = FileHandle.standardOutput,
		errorHandle: FileHandle = FileHandle.standardError,
		callOptions: CallOptions? = nil
	) async throws -> Int32 {
		return try await self.exec(name: name, command: .shell(), inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle, callOptions: callOptions)
	}
}
