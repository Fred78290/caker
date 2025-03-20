import Foundation
import CakeAgentLib
import Virtualization
import Semaphore
import GRPC
import GRPCLib
import CakeAgentLib
import NIO

extension DirectorySharingAttachment {
	func equals(to: MountVirtioFS) -> Bool {
		if self.readOnly != to.readonly {
			return false
		}

		if self.source != to.target {
			return false
		}

		if self.path.path != to.name {
			return false
		}

		if self.uid != to.uid {
			return false
		}

		if self.gid != to.gid {
			return false
		}

		return true
	}
}

public class MountVirtioFSReply: NSObject, NSSecureCoding {
	public static var supportsSecureCoding = false

	public var name: String = String()
	public var response: MountVirtioFSReply.OneOf_Response? = nil

	public func encode(with coder: NSCoder) {
		coder.encode(self.name, forKey: "name")
		coder.encode(self.response, forKey: "response")
	}

	public required init?(coder: NSCoder) {
		self.name = coder.decodeObject(forKey: "name") as? String ?? ""
		self.response = coder.decodeObject(forKey: "response") as? MountVirtioFSReply.OneOf_Response
	}

	public init(_ from: Cakeagent_MountVirtioFSReply) {
		self.name = from.name

		if case let .error(error) = from.response {
			self.response = MountVirtioFSReply.OneOf_Response.error(error)
		} else {
			self.response = MountVirtioFSReply.OneOf_Response.success(true)
		}
	}

	public init(name: String, error: Error) {
		self.name = name
		self.response = .error(String(describing: error))
	}

	public enum OneOf_Response: Equatable {
		case error(String)
		case success(Bool)
	}
}

public class MountReply: NSObject, NSSecureCoding {
	public static var supportsSecureCoding = false

	public var mounts: [MountVirtioFSReply] = []
	public var response: MountReply.OneOf_Response? = nil

	public func encode(with coder: NSCoder) {
		coder.encode(self.mounts, forKey: "mounts")
		coder.encode(self.response, forKey: "response")
	}

	public required init?(coder: NSCoder) {
		self.mounts = coder.decodeObject(forKey: "mounts") as? [MountVirtioFSReply] ?? []
		self.response = coder.decodeObject(forKey: "response") as? MountReply.OneOf_Response
	}

	public init(request: MountRequest, error: Error) {
		self.response = .error(error.localizedDescription)
		self.mounts = request.mounts.map { mount in
			MountVirtioFSReply(name: mount.name, error: error)
		}
	}

	public init(_ from: Cakeagent_MountReply) {
		self.mounts = from.mounts.map { mount in
			MountVirtioFSReply(mount)
		}

		if case let .error(error) = from.response {
			self.response = MountReply.OneOf_Response.error(error)
		} else {
			self.response = MountReply.OneOf_Response.success(true)
		}
	}

	public enum OneOf_Response: Equatable {
		case error(String)
		case success(Bool)
	}

	public func toCaked() -> Caked_MountReply {
		Caked_MountReply.with { reply in
			reply.mounts = self.mounts.map { mount in
				Caked_MountVirtioFSReply.with {
					$0.name = mount.name

					if case let .error(error) = mount.response {
						$0.response = .error(error)
					} else {
						$0.response = .success(true)
					}
				}
			}

			if case let .error(error) = self.response {
				reply.response = .error(error)
			} else {
				reply.response = .success(true)
			}
		}
	}
}

public class MountVirtioFS: NSObject, NSSecureCoding {
	public static var supportsSecureCoding = false

	public var name: String = String()
	public var source: String = String()
	public var target: String = String()
	public var uid: Int32 = 0
	public var gid: Int32 = 0
	public var readonly: Bool = false

	public func encode(with coder: NSCoder) {
		coder.encode(name, forKey: "name")
		coder.encode(source, forKey: "source")
		coder.encode(target, forKey: "target")
		coder.encode(uid, forKey: "uid")
		coder.encode(gid, forKey: "gid")
		coder.encode(readonly, forKey: "readonly")
	}

	public required init?(coder: NSCoder) {
		self.name = coder.decodeObject(forKey: "name") as? String ?? ""
		self.source = coder.decodeObject(forKey: "source") as? String ?? ""
		self.target = coder.decodeObject(forKey: "target") as? String ?? ""
		self.uid = coder.decodeInt32(forKey: "uid")
		self.gid = coder.decodeInt32(forKey: "gid")
		self.readonly = coder.decodeBool(forKey: "readonly")
	}

	public init(attachment: DirectorySharingAttachment) {
		self.name = attachment.name
		self.source = attachment.source
		self.target = attachment.destination ?? ""
		self.uid = Int32(attachment.uid)
		self.gid = Int32(attachment.gid)
		self.readonly = attachment.readOnly
	}

	public init(name: String, source: String, target: String, uid: Int32, gid: Int32, readonly: Bool) {
		self.name = name
		self.source = source
		self.target = target
		self.uid = uid
		self.gid = gid
		self.readonly = readonly
	}

	public func equals(to: DirectorySharingAttachment) -> Bool {
		if self.readonly != to.readOnly {
			return false
		}

		if self.source != to.source {
			return false
		}

		if self.target != to.destination {
			return false
		}

		if self.name != to.name {
			return false
		}

		if self.uid != to.uid {
			return false
		}

		if self.gid != to.gid {
			return false
		}

		return true
	}

	public func toDirectorySharingAttachment() -> DirectorySharingAttachment {
		DirectorySharingAttachment(source: self.source, destination: self.target, readOnly: self.readonly, name: self.name, uid: Int(self.uid), gid: Int(self.gid))
	}

	public func toCakeAgent() -> Cakeagent_MountVirtioFS {
		Cakeagent_MountVirtioFS.with {
			$0.name = self.name
			$0.target = self.target
			$0.uid = self.uid
			$0.gid = self.gid
			$0.readonly = self.readonly
			$0.early = true
		}
	}
}

extension Cakeagent_MountReply {
	func toXPC() -> MountReply {
		MountReply(self)
	}
}

public class MountRequest: NSObject, NSSecureCoding {
	public static var supportsSecureCoding: Bool = false

	public var mounts: [MountVirtioFS] = []

	public init(mounts: [MountVirtioFS] = []) {
		self.mounts = mounts
	}

	public required init?(coder: NSCoder) {
		self.mounts = coder.decodeObject(forKey: "mounts") as? [MountVirtioFS] ?? []
	}

	init(_ attachements: [DirectorySharingAttachment]) {
		self.mounts = attachements.map {
			MountVirtioFS(attachment: $0)
		}
	}

	init(_ from: Caked_MountRequest) {
		self.mounts = from.mounts.map { mount in
			MountVirtioFS(name: mount.name, source: mount.source, target: mount.target, uid: mount.uid, gid: mount.gid, readonly: mount.readonly)
		}
	}

	func toCakeAgent() -> Cakeagent_MountRequest {
		Cakeagent_MountRequest.with { request in
			request.mounts = self.mounts.map { mount in
				Cakeagent_MountVirtioFS.with {
					$0.name = mount.name
					$0.target = mount.target
					$0.uid = mount.uid
					$0.gid = mount.gid
					$0.readonly = mount.readonly
				}
			}	
		}
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.mounts, forKey: "mounts")
	}

}

@objc protocol ReplyMountServiceProtocol {
	func reply(response: MountReply) -> Void
}

@objc protocol MountServiceProtocol {
	func mount(request: MountRequest) -> Void
	func umount(request: MountRequest) -> Void
}

class XPCMountService: MountService, MountServiceProtocol {
	let connection: NSXPCConnection

	init(group: EventLoopGroup, asSystem: Bool, vm: VirtualMachine, certLocation: CertificatesLocation, connection: NSXPCConnection) {
		self.connection = connection
		super.init(group: group, asSystem: asSystem, vm: vm, certLocation: certLocation)
	}

	func mount(request: MountRequest, umount: Bool) -> Void {
		let proxyObject = self.connection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("XPC Error: \($0)") })
		let reply: MountReply

		Logger(self).info("XPC mount: \(String(describing: request))")

		guard let mountServiceReply = proxyObject as? ReplyMountServiceProtocol else {
			Logger(self).error("Failed to get proxy ReplyMountServiceProtocol")
			return
		}

		reply = self.mount(request: request.toCakeAgent(), umount: umount).toXPC()

		mountServiceReply.reply(response: reply)
	}

	public func mount(request: MountRequest) -> Void {
		self.mount(request: request, umount: false)
	}

	public func umount(request: MountRequest) -> Void {
		self.mount(request: request, umount: true)
	}
}

class XPCMountServiceServer: NSObject, NSXPCListenerDelegate, MountServiceServerProtocol {
	private let listener: NSXPCListener
	private let certLocation: CertificatesLocation
	private let semaphore = AsyncSemaphore(value: 0)
	private let group: EventLoopGroup
	private let asSystem: Bool
	private let vm: VirtualMachine

	init(group: EventLoopGroup, asSystem: Bool, vm: VirtualMachine, certLocation: CertificatesLocation) {
		let name = vm.vmLocation.name

		self.listener = NSXPCListener(machServiceName: "com.aldunelabs.caked.MountService.\(name)")
		self.group = group
		self.asSystem = asSystem
		self.vm = vm
		self.certLocation = certLocation
		super.init()

		self.listener.delegate = self
	}

	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		Logger(self).info("XPC receive connection: \(String(describing: newConnection))")

		newConnection.exportedInterface = NSXPCInterface(with: MountServiceProtocol.self)
		newConnection.exportedObject = XPCMountService(group: self.group.next(), asSystem: self.asSystem, vm: self.vm, certLocation: self.certLocation, connection: newConnection)
		newConnection.remoteObjectInterface = NSXPCInterface(with: ReplyMountServiceProtocol.self)
		newConnection.activate()

		return true
	}

	func serve() {
		Task {
			Logger(self).info("XPC start listening")

			listener.activate()

			do {
				try await self.semaphore.waitUnlessCancelled()
			} catch {
				Logger(self).error("Error: \(error)")
			}

			Logger(self).info("XPC end listening")
		}
	}

	func stop() {
		self.semaphore.signal()
		listener.invalidate()
	}
}

class XPCMountServiceClient: MountServiceClient {
	let vmLocation: VMLocation

	init(vmLocation: VMLocation) {
		self.vmLocation = vmLocation
	}

	func mount(mounts: [DirectorySharingAttachment]) throws -> Caked_MountReply {
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

	func umount(mounts: [DirectorySharingAttachment]) throws -> Caked_MountReply {
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
}
