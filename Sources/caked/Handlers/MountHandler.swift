import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import TextTable
import CakeAgentLib
import NIO
import Semaphore

class ReplyMountService: NSObject, NSSecureCoding, ReplyMountServiceProtocol {
	static var supportsSecureCoding: Bool = false

	private let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
	private var response: MountReply? = nil

	init(response: MountReply? = nil) {
		self.response = response
	}

	required init?(coder: NSCoder) {
		self.response = coder.decodeObject(forKey: "reply") as? MountReply
	}

	func reply(response: MountReply) -> Void {
		self.response = response
		self.semaphore.signal()
	}

	func wait() -> MountReply? {
		if self.response == nil {
			guard self.semaphore.wait(timeout: .now() + 10) == .timedOut else {
				Logger(self).error("Timeout")
				return nil
			}
		}

		return self.response
	}

	func encode(with coder: NSCoder) {
		coder.encode(self.reply, forKey: "reply")
	}
}

struct MountHandler: CakedCommandAsync {
	var request: Caked_MountRequest

	struct MountVirtioFSReply: Codable {
		let name: String
		let success: Bool
		let reason: String

		init(_ reply: Cakeagent_MountVirtioFSReply) {
			self.name = reply.name
			self.success = reply.success
			self.reason = reply.error
		}

		init(_ reply: Caked_MountVirtioFSReply) {
			self.name = reply.name
			self.success = reply.success
			self.reason = reply.error
		}
	}

	static func Mount(vmLocation: VMLocation, mounts: [DirectorySharingAttachment]) throws -> Caked_MountReply {
		let config: CakeConfig = try vmLocation.config()
		let valided = config.newAttachements(mounts)

		var response: Caked_MountReply = Caked_MountReply.with {
			$0.mounts = []
			$0.response = .success(true)
		}

		if valided.isEmpty == false {
			var directorySharingAttachments = config.mounts

			valided.forEach { mount in
				directorySharingAttachments.removeAll { $0.name == mount.name }
				directorySharingAttachments.append(mount)
			}

			config.mounts = directorySharingAttachments
			try config.save()

			if vmLocation.status == .running {
				let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.MountService.\(vmLocation.name)")
				let replier = ReplyMountService()

				xpcConnection.remoteObjectInterface = NSXPCInterface(with: MountServiceProtocol.self)
				xpcConnection.exportedInterface = NSXPCInterface(with: ReplyMountServiceProtocol.self)
				xpcConnection.exportedObject = replier

				xpcConnection.activate()

				let proxyObject = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") })

				guard let mountService = proxyObject as? MountServiceProtocol else {
					throw ServiceError("Failed to connect to MountService")
				}

				mountService.mount(request: MountRequest(directorySharingAttachments))

				if let reply = replier.wait() {
					response = reply.toCaked()
				} else {
					response.response = .error("Timeout")
				}

				xpcConnection.invalidate()
			}
		}

		return response
	}

	static func Umount(vmLocation: VMLocation, mounts: [DirectorySharingAttachment]) throws -> Caked_MountReply {
		let config: CakeConfig = try vmLocation.config()
		let valided = config.validAttachements(mounts)

		var response: Caked_MountReply = Caked_MountReply.with {
			$0.mounts = []
			$0.response = .success(true)
		}

		if valided.isEmpty == false {
			var directorySharingAttachments = config.mounts

			valided.forEach { mount in
				directorySharingAttachments.removeAll{ $0.name == mount.name }
			}

			config.mounts = directorySharingAttachments
			try config.save()

			if vmLocation.status == .running {
				let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.MountService.\(vmLocation.name)")
				let replier = ReplyMountService()

				xpcConnection.remoteObjectInterface = NSXPCInterface(with: MountServiceProtocol.self)
				xpcConnection.exportedInterface = NSXPCInterface(with: ReplyMountServiceProtocol.self)
				xpcConnection.exportedObject = replier

				xpcConnection.activate()

				guard let mountService = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") }) as? MountServiceProtocol else {
					throw ServiceError("Failed to connect to MountService")
				}

				mountService.umount(request: MountRequest(directorySharingAttachments))

				if let reply = replier.wait() {
					response = reply.toCaked()
				} else {
					response.response = .error("Timeout")
				}

				xpcConnection.invalidate()
			}
		}

		return response
	}

	mutating func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.request.name)
		let directorySharingAttachment = self.request.directorySharingAttachment()
		let format: Format = request.format == .text ? Format.text : Format.json
		let command = self.request.command

		return on.submit {
			let response: Caked_MountReply

			if command == .add {
				response = try Self.Mount(vmLocation: vmLocation, mounts: directorySharingAttachment)
			} else {
				response = try Self.Umount(vmLocation: vmLocation, mounts: directorySharingAttachment)
			}

			if case let .error(v) = response.response {
				throw ServiceError(v)
			}

			return format.renderSingle(style: Style.grid, uppercased: true, response.mounts.map { MountVirtioFSReply($0) })
		}
	}
}
