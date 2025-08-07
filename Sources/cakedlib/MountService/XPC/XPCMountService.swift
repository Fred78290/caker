import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore
import Virtualization

extension DirectorySharingAttachment {
	func equals(to: XPCMountVirtioFS) -> Bool {
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

extension MountVirtioFS {
	init(from: CakeAgent.MountReply.MountVirtioFSReply) {
		self.init()

		self.name = from.name

		if case let .error(error) = from.response {
			self.response = .error(error)
		} else {
			self.response = .success(true)
		}
	}

	enum OneOf_Response: Equatable, Codable {
		case error(String)
		case success(Bool)
	}
}

extension MountInfos {
	init(request: MountRequest, error: Error) {
		self.init()

		self.response = .error(error.localizedDescription)
		self.mounts = request.mounts.map { MountVirtioFS(name: $0.name, error: error) }
	}

	init(_ from: CakeAgent.MountReply) {
		self.init()

		self.mounts = from.mounts.map { GRPCLib.MountVirtioFS(from: $0) }

		if case let .error(error) = from.response {
			self.response = .error(error)
		} else {
			self.response = .success(true)
		}
	}
}

struct XPCMountVirtioFS: Codable {
	var name: String = ""
	var source: String = ""
	var target: String = ""
	var uid: Int32 = 0
	var gid: Int32 = 0
	var readonly: Bool = false

	enum CodingKeys: String, CodingKey {
		case name = "name"
		case source = "source"
		case target = "target"
		case uid = "uid"
		case gid = "gid"
		case readonly = "readonly"
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(self.name, forKey: .name)
		try container.encode(self.source, forKey: .source)
		try container.encode(self.target, forKey: .target)
		try container.encode(self.uid, forKey: .uid)
		try container.encode(self.gid, forKey: .gid)
		try container.encode(self.readonly, forKey: .readonly)
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.name = try container.decode(String.self, forKey: .name)
		self.source = try container.decode(String.self, forKey: .source)
		self.target = try container.decode(String.self, forKey: .target)
		self.uid = try container.decode(Int32.self, forKey: .uid)
		self.gid = try container.decode(Int32.self, forKey: .gid)
		self.readonly = try container.decode(Bool.self, forKey: .readonly)
	}

	init(attachment: DirectorySharingAttachment) {
		self.name = attachment.name
		self.source = attachment.source
		self.target = attachment.destination ?? ""
		self.uid = Int32(attachment.uid)
		self.gid = Int32(attachment.gid)
		self.readonly = attachment.readOnly
	}

	init(name: String, source: String, target: String, uid: Int32, gid: Int32, readonly: Bool) {
		self.name = name
		self.source = source
		self.target = target
		self.uid = uid
		self.gid = gid
		self.readonly = readonly
	}

	func equals(to: DirectorySharingAttachment) -> Bool {
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

	func toDirectorySharingAttachment() -> DirectorySharingAttachment {
		DirectorySharingAttachment(source: self.source, destination: self.target, readOnly: self.readonly, name: self.name, uid: Int(self.uid), gid: Int(self.gid))
	}

	func toCakeAgent() -> CakeAgent.MountRequest.MountVirtioFS {
		CakeAgent.MountRequest.MountVirtioFS.with {
			$0.name = self.name
			$0.target = self.target
			$0.uid = self.uid
			$0.gid = self.gid
			$0.readonly = self.readonly
			$0.early = true
		}
	}
}

extension CakeAgent.MountReply {
	func toXPC() -> MountInfos {
		MountInfos(self)
	}
}

struct MountRequest: Codable {
	var mounts: [XPCMountVirtioFS] = []

	enum CodingKeys: String, CodingKey {
		case mounts = "mounts"
	}

	init(fromJSON: String) {
		let decoder = JSONDecoder()

		self = try! decoder.decode(Self.self, from: fromJSON.data(using: .utf8)!)
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.mounts = try container.decode([XPCMountVirtioFS].self, forKey: .mounts)
	}

	init(mounts: [XPCMountVirtioFS] = []) {
		self.mounts = mounts
	}

	init(_ attachements: [DirectorySharingAttachment]) {
		self.mounts = attachements.map {
			XPCMountVirtioFS(attachment: $0)
		}
	}

	init(_ from: Caked_MountRequest) {
		self.mounts = from.mounts.map { mount in
			XPCMountVirtioFS(name: mount.name, source: mount.source, target: mount.target, uid: mount.uid, gid: mount.gid, readonly: mount.readonly)
		}
	}

	func toCakeAgent() -> CakeAgent.MountRequest {
		CakeAgent.MountRequest.with { request in
			request.mounts = self.mounts.map { $0.toCakeAgent() }
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(self.mounts, forKey: .mounts)
	}

	public func toJSON() -> String {
		let encoder = JSONEncoder()

		encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]

		return try! encoder.encode(self).toString()
	}
}

@objc protocol ReplyMountServiceProtocol {
	func vncURLReply(response: String)
	func mountReply(response: String)
}

@objc protocol MountServiceProtocol {
	func vncUrl()
	func mount(request: String)
	func umount(request: String)
}

class XPCMountService: MountService, MountServiceProtocol {
	let connection: NSXPCConnection

	init(group: EventLoopGroup, runMode: Utils.RunMode, vm: VirtualMachine, certLocation: CertificatesLocation, connection: NSXPCConnection) {
		self.connection = connection
		super.init(group: group, runMode: runMode, vm: vm, certLocation: certLocation)
	}

	func mount(request: MountRequest, umount: Bool) {
		let proxyObject = self.connection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("XPC Error: \($0)") })
		let reply: MountInfos

		Logger(self).info("XPC mount: \(String(describing: request))")

		guard let mountServiceReply = proxyObject as? ReplyMountServiceProtocol else {
			Logger(self).error("Failed to get proxy ReplyMountServiceProtocol")
			return
		}

		reply = self.mount(request: request.toCakeAgent(), umount: umount).toXPC()

		mountServiceReply.mountReply(response: reply.toJSON())
	}

	func vncUrl() {
		let proxyObject = self.connection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("XPC Error: \($0)") })
		let result: String

		if let u = self.vncURL() {
			result = u.absoluteString
		} else {
			result = ""
		}

		guard let mountServiceReply = proxyObject as? ReplyMountServiceProtocol else {
			Logger(self).error("Failed to get proxy ReplyMountServiceProtocol")
			return
		}

		mountServiceReply.vncURLReply(response: result)
	}
	
	public func mount(request: String) {
		self.mount(request: MountRequest(fromJSON: request), umount: false)
	}

	public func umount(request: String) {
		self.mount(request: MountRequest(fromJSON: request), umount: true)
	}
}

class XPCMountServiceServer: NSObject, NSXPCListenerDelegate, MountServiceServerProtocol {
	private let listener: NSXPCListener
	private let certLocation: CertificatesLocation
	private let semaphore = AsyncSemaphore(value: 0)
	private let group: EventLoopGroup
	private let runMode: Utils.RunMode
	private let vm: VirtualMachine

	init(group: EventLoopGroup, runMode: Utils.RunMode, vm: VirtualMachine, certLocation: CertificatesLocation) {
		let name = vm.location.name

		self.listener = NSXPCListener(machServiceName: "com.aldunelabs.caked.MountService.\(name)")
		self.group = group
		self.runMode = runMode
		self.vm = vm
		self.certLocation = certLocation
		super.init()

		self.listener.delegate = self
	}

	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		Logger(self).info("XPC receive connection: \(String(describing: newConnection))")

		newConnection.exportedInterface = NSXPCInterface(with: MountServiceProtocol.self)
		newConnection.exportedObject = XPCMountService(group: self.group.next(), runMode: self.runMode, vm: self.vm, certLocation: self.certLocation, connection: newConnection)
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
	let location: VMLocation

	init(location: VMLocation) {
		self.location = location
	}

	func vncURL() throws -> URL? {
		if location.status == .running {
			let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.MountService.\(location.name)")
			let replier = ReplyMountService()

			xpcConnection.remoteObjectInterface = NSXPCInterface(with: MountServiceProtocol.self)
			xpcConnection.exportedInterface = NSXPCInterface(with: ReplyMountServiceProtocol.self)
			xpcConnection.exportedObject = replier

			xpcConnection.activate()

			defer {
				xpcConnection.invalidate()
			}

			let proxyObject = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") })

			guard let mountService = proxyObject as? MountServiceProtocol else {
				throw ServiceError("Failed to connect to MountService")
			}

			mountService.vncUrl()

			if let reply = replier.wait() {
				if case let .vncURL(url) = reply {
					return URL(string: url)
				}
			}
		}

		return nil
	}
	
	func mount(mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		let config: CakeConfig = try location.config()
		let valided = config.newAttachements(mounts)

		if valided.isEmpty == false {
			var directorySharingAttachments = config.mounts

			valided.forEach { mount in
				directorySharingAttachments.removeAll { $0.name == mount.name }
				directorySharingAttachments.append(mount)
			}

			config.mounts = directorySharingAttachments
			try config.save()

			if location.status == .running {
				let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.MountService.\(location.name)")
				let replier = ReplyMountService()

				xpcConnection.remoteObjectInterface = NSXPCInterface(with: MountServiceProtocol.self)
				xpcConnection.exportedInterface = NSXPCInterface(with: ReplyMountServiceProtocol.self)
				xpcConnection.exportedObject = replier

				xpcConnection.activate()

				defer {
					xpcConnection.invalidate()
				}

				let proxyObject = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") })

				guard let mountService = proxyObject as? MountServiceProtocol else {
					throw ServiceError("Failed to connect to MountService")
				}

				mountService.mount(request: MountRequest(valided).toJSON())

				return replier.waitForMountInfosReply()
			} else {
				return MountInfos.with {
					$0.response = .error("VM is not running")
				}
			}
		}

		return MountInfos.with {
			$0.response = .error("No new mounts")
		}
	}

	func umount(mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		let config: CakeConfig = try location.config()
		let valided = config.validAttachements(mounts)

		if valided.isEmpty == false {
			var directorySharingAttachments = config.mounts

			valided.forEach { mount in
				directorySharingAttachments.removeAll { $0.name == mount.name }
			}

			config.mounts = directorySharingAttachments
			try config.save()

			if location.status == .running {
				let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.MountService.\(location.name)")
				let replier = ReplyMountService()

				xpcConnection.remoteObjectInterface = NSXPCInterface(with: MountServiceProtocol.self)
				xpcConnection.exportedInterface = NSXPCInterface(with: ReplyMountServiceProtocol.self)
				xpcConnection.exportedObject = replier

				xpcConnection.activate()

				defer {
					xpcConnection.invalidate()
				}

				guard let mountService = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") }) as? MountServiceProtocol else {
					throw ServiceError("Failed to connect to MountService")
				}

				mountService.umount(request: MountRequest(valided).toJSON())

				return replier.waitForMountInfosReply()
			} else {
				return MountInfos.with {
					$0.response = .error("VM is not running")
				}
			}
		}

		return MountInfos.with {
			$0.response = .error("No umounts")
		}
	}
}
