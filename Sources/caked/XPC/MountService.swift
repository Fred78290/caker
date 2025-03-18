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

public class MountVirtioFSReply: NSObject {
	public var name: String = String()
	public var response: MountVirtioFSReply.OneOf_Response? = nil

	convenience public init(_ from: Cakeagent_MountVirtioFSReply) {
		self.init()

		self.name = from.name

		if case let .error(error) = from.response {
			self.response = MountVirtioFSReply.OneOf_Response.error(error)
		} else {
			self.response = MountVirtioFSReply.OneOf_Response.success(true)
		}
	}

	public enum OneOf_Response: Equatable {
		case error(String)
		case success(Bool)
	}
}

public class MountReply: NSObject {
	public var mounts: [MountVirtioFSReply] = []
	public var response: MountReply.OneOf_Response? = nil

	convenience public init(_ from: Cakeagent_MountReply) {
		self.init()

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

public class MountVirtioFS: NSObject {
	public var name: String = String()
	public var source: String = String()
	public var target: String = String()
	public var uid: Int32 = 0
	public var gid: Int32 = 0
	public var readonly: Bool = false

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
		}
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

	public init(_ attachements: [DirectorySharingAttachment]) {
		self.mounts = attachements.map {
			MountVirtioFS(attachment: $0)
		}
	}

	public init(_ from: Caked_MountRequest) {
		self.mounts = from.mounts.map { mount in
			MountVirtioFS(name: mount.name, source: mount.source, target: mount.target, uid: mount.uid, gid: mount.gid, readonly: mount.readonly)
		}
	}

	public func toCakeAgent() -> Cakeagent_MountRequest {
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
        
    }

}

@objc protocol ReplyMountServiceProtocol {
	func reply(response: MountReply) -> Void
}

@objc protocol MountServiceProtocol {
	func mount(request: MountRequest) -> Void
	func umount(request: MountRequest) -> Void
}

public class MountService: NSObject, MountServiceProtocol {
	let asSystem: Bool
	let vm: VirtualMachine
	let certLocation: CertificatesLocation
	let group: EventLoopGroup
	let connection: NSXPCConnection

	init(group: EventLoopGroup, asSystem: Bool, vm: VirtualMachine, certLocation: CertificatesLocation, connection: NSXPCConnection) {
		self.vm = vm
		self.asSystem = asSystem
		self.group = group
		self.certLocation = certLocation
		self.connection = connection
	}

	func createCakeAgentConnection(retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentHelper {
		return try CakeAgentHelper(on: self.group.next(),
		                           listeningAddress: self.vm.vmLocation.agentURL,
		                           connectionTimeout: 30,
		                           caCert: self.certLocation.caCertURL.path,
		                           tlsCert: self.certLocation.clientCertURL.path,
		                           tlsKey: self.certLocation.clientKeyURL.path,
		                           retries: retries)
	}

	public func mount(request: MountRequest) -> Void {
		let reply = MountReply()
		let proxyObject = self.connection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("XPC Error: \($0)") })

		Logger(self).info("XPC mount: \(String(describing: request))")

		guard let mountServiceReply = proxyObject as? ReplyMountServiceProtocol else {
			Logger(self).error("Failed to get proxy ReplyMountServiceProtocol")
			return
		}

		reply.mounts = request.mounts.map { mount in
			let mountReply = MountVirtioFSReply()

			mountReply.name = mount.name
			mountReply.response = MountVirtioFSReply.OneOf_Response.success(true)

			return mountReply
		}

		if request.mounts.isEmpty == false {
			do {
				let config = try vm.vmLocation.config()

				if config.os == .darwin {
					var directories: [String : VZSharedDirectory] = [:]

					guard let sharedDevices: VZVirtioFileSystemDevice = vm.virtualMachine.directorySharingDevices.first as? VZVirtioFileSystemDevice else {
						reply.response = MountReply.OneOf_Response.error("No shared devices")
						mountServiceReply.reply(response: reply)
						return
					}

					config.mounts.forEach { attachment in
						if let configuration = attachment.configuration {
							directories[attachment.name] = configuration
						}
					}

					sharedDevices.share = VZMultipleDirectoryShare(directories: directories)
				} else {
					let conn = try createCakeAgentConnection()
					let agentRequest = Cakeagent_MountRequest.with {
						$0.mounts = request.mounts.map { $0.toCakeAgent() }
					}

					let agentReply = try conn.mount(request: agentRequest)

					reply.mounts.append(contentsOf: agentReply.mounts.map { mount in
						MountVirtioFSReply(mount)
					})

					if case let .error(error) = agentReply.response {
						reply.response = MountReply.OneOf_Response.error(error)
					} else {
						reply.response = MountReply.OneOf_Response.success(true)
					}
				}
			} catch {
				reply.response = MountReply.OneOf_Response.error(error.localizedDescription)
			}
		}

		mountServiceReply.reply(response: reply)
	}

	public func umount(request: MountRequest) -> Void {
		let reply = MountReply()
		let proxyObject = self.connection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("XPC Error: \($0)") })

		Logger(self).info("XPC umount: \(String(describing: request))")

		guard let mountServiceReply = proxyObject as? ReplyMountServiceProtocol else {
			Logger(self).error("Failed to get proxy ReplyMountServiceProtocol")
			return
		}

		reply.mounts = request.mounts.map { mount in
			let mountReply = MountVirtioFSReply()

			mountReply.name = mount.name
			mountReply.response = MountVirtioFSReply.OneOf_Response.success(true)

			return mountReply
		}

		if request.mounts.isEmpty == false {
			do {
				let config = try vm.vmLocation.config()

				if config.os == .darwin {
					var directories: [String : VZSharedDirectory] = [:]

					guard let sharedDevices: VZVirtioFileSystemDevice = vm.virtualMachine.directorySharingDevices.first as? VZVirtioFileSystemDevice else {
						reply.response = MountReply.OneOf_Response.error("No shared devices")
						mountServiceReply.reply(response: reply)
						return
					}

					config.mounts.forEach { attachment in
						if let configuration = attachment.configuration {
							directories[attachment.name] = configuration
						}
					}

					sharedDevices.share = VZMultipleDirectoryShare(directories: directories)
				} else {
					let conn = try createCakeAgentConnection()
					let agentRequest = Cakeagent_MountRequest.with {
						$0.mounts = request.mounts.map { $0.toCakeAgent() }
					}

					let agentReply = try conn.umount(request: agentRequest)

					reply.mounts.append(contentsOf: agentReply.mounts.map { mount in
						return MountVirtioFSReply(mount)
					})

					if case let .error(error) = agentReply.response {
						reply.response = MountReply.OneOf_Response.error(error)
					} else {
						reply.response = MountReply.OneOf_Response.success(true)
					}
				}
			} catch {
				reply.response = MountReply.OneOf_Response.error(error.localizedDescription)
			}
		}

		mountServiceReply.reply(response: reply)
	}
}

class MountServiceDelegate: NSObject, NSXPCListenerDelegate {
	private let listener: NSXPCListener
	private let certLocation: CertificatesLocation
	private let semaphore = AsyncSemaphore(value: 0)
	private let group: EventLoopGroup
	private let asSystem: Bool
	private let vm: VirtualMachine

	init(group: EventLoopGroup, asSystem: Bool, vm: VirtualMachine) throws {
		let name = vm.vmLocation.name

		self.listener = NSXPCListener(machServiceName: "com.aldunelabs.caked.MountService.\(name)")
		self.group = group
		self.asSystem = asSystem
		self.vm = vm
		self.certLocation = try CertificatesLocation.createAgentCertificats(asSystem: asSystem)
		super.init()

		self.listener.delegate = self
	}

	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		Logger(self).info("XPC receive connection: \(String(describing: newConnection))")

		newConnection.exportedInterface = NSXPCInterface(with: MountServiceProtocol.self)
		newConnection.exportedObject = MountService(group: self.group.next(), asSystem: self.asSystem, vm: self.vm, certLocation: self.certLocation, connection: newConnection)
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