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

	init(_ from: Caked.Reply) {
		self.init()

		if case let .error(value) = from.response {
			self.response = .error(value.reason)
		} else {
			self.response = .success(true)
		}

		self.mounts = from.mounts.mounts.map { GRPCLib.MountVirtioFS(from: $0) }
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

extension Caked.Reply {
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

	init(_ attachements: DirectorySharingAttachments) {
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

	func toCaked(_ command: Caked.MountRequest.MountCommand) -> Caked_MountRequest {
		Caked_MountRequest.with {
			$0.command = command
			$0.mounts = self.mounts.map { mount in
				.with {
					$0.name = mount.name
					$0.source = mount.source
					$0.target = mount.target
					$0.readonly = mount.readonly
					$0.uid = mount.uid
					$0.gid = mount.gid
				}
			}
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

@objc protocol ReplyVMRunServiceProtocol {
	func vncURLReply(response: String)
	func mountReply(response: String)
	func screenSizeReply(width: Int, height: Int)
}

@objc protocol VMRunServiceProtocol {
	func vncUrl()
	func resizeScreen(width: Int, height: Int)
	func getScreenSize()
	func mount(request: String)
	func umount(request: String)
}

class XPCVMRunService: VMRunService, VMRunServiceProtocol {
	let connection: NSXPCConnection

	init(group: EventLoopGroup, runMode: Utils.RunMode, vm: VirtualMachine, certLocation: CertificatesLocation, connection: NSXPCConnection, logger: Logger) {
		self.connection = connection
		super.init(group: group, runMode: runMode, vm: vm, certLocation: certLocation, logger: logger)
	}

	func mount(request: MountRequest, umount: Bool) {
		let proxyObject = self.connection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("XPC Error: \($0)") })
		let reply: MountInfos

		self.logger.debug("XPC mount: \(String(describing: request))")

		guard let serviceReply = proxyObject as? ReplyVMRunServiceProtocol else {
			Logger(self).error("Failed to get proxy ReplyVMRunServiceProtocol")
			return
		}

		reply = self.mount(request: request.toCaked(umount ? .umount : .mount), umount: umount).toXPC()

		serviceReply.mountReply(response: reply.toJSON())

		self.logger.debug("Replied to mount request: \(reply)")
	}

	func vncUrl() {
		let proxyObject = self.connection.synchronousRemoteObjectProxyWithErrorHandler({ self.logger.error("XPC Error: \($0)") })
		let result: String

		if let u = self.vncURL {
			result = u.absoluteString
		} else {
			result = ""
		}

		self.logger.debug("Handling VNC URL request: \(result)")

		guard let serviceReply = proxyObject as? ReplyVMRunServiceProtocol else {
			self.logger.error("Failed to get proxy ReplyVMRunServiceProtocol")
			return
		}

		serviceReply.vncURLReply(response: result)

		self.logger.debug("Replied to VNC URL request: \(result)")
	}
	
	func resizeScreen(width: Int, height: Int) {
		let proxyObject = self.connection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("XPC Error: \($0)") })

		self.logger.debug("XPC setScreenSize: \(width)x\(height)")

		guard let serviceReply = proxyObject as? ReplyVMRunServiceProtocol else {
			Logger(self).error("Failed to get proxy ReplyVMRunServiceProtocol")
			return
		}

		self.setScreenSize(width: width, height: height)

		serviceReply.screenSizeReply(width: width, height: height)

		self.logger.debug("Replied to resizeScreen request")
	}

	func getScreenSize() {
		let proxyObject = self.connection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("XPC Error: \($0)") })

		self.logger.debug("XPC getScreenSize")

		guard let serviceReply = proxyObject as? ReplyVMRunServiceProtocol else {
			Logger(self).error("Failed to get proxy ReplyVMRunServiceProtocol")
			return
		}

		let (width, height) = self.vm.getScreenSize()

		serviceReply.screenSizeReply(width: width, height: height)

		self.logger.debug("Replied to getScreenSize request")
	}

	public func mount(request: String) {
		self.mount(request: MountRequest(fromJSON: request), umount: false)
	}

	public func umount(request: String) {
		self.mount(request: MountRequest(fromJSON: request), umount: true)
	}
}

class XPCVMRunServiceServer: NSObject, NSXPCListenerDelegate, VMRunServiceServerProtocol {
	private let listener: NSXPCListener
	private let certLocation: CertificatesLocation
	private let semaphore = AsyncSemaphore(value: 0)
	private let group: EventLoopGroup
	private let runMode: Utils.RunMode
	private let vm: VirtualMachine

	init(group: EventLoopGroup, runMode: Utils.RunMode, vm: VirtualMachine, certLocation: CertificatesLocation) {
		let name = vm.location.name

		self.listener = NSXPCListener(machServiceName: "com.aldunelabs.caked.VMRunService.\(name)")
		self.group = group
		self.runMode = runMode
		self.vm = vm
		self.certLocation = certLocation
		super.init()

		self.listener.delegate = self
	}

	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		Logger(self).debug("XPC receive connection: \(String(describing: newConnection))")

		newConnection.exportedInterface = NSXPCInterface(with: VMRunServiceProtocol.self)
		newConnection.exportedObject = XPCVMRunService(group: self.group.next(), runMode: self.runMode, vm: self.vm, certLocation: self.certLocation, connection: newConnection, logger: Logger("XPCVMRunService"))
		newConnection.remoteObjectInterface = NSXPCInterface(with: ReplyVMRunServiceProtocol.self)
		newConnection.activate()

		return true
	}

	func serve() {
		Task {
			Logger(self).debug("XPC start listening")

			listener.activate()

			do {
				try await self.semaphore.waitUnlessCancelled()
			} catch {
				Logger(self).error("Error: \(error)")
			}

			Logger(self).debug("XPC end listening")
		}
	}

	func stop() {
		self.semaphore.signal()
		listener.invalidate()
	}
}

class ReplyVMRunService: NSObject, NSSecureCoding, ReplyVMRunServiceProtocol {
	static let supportsSecureCoding: Bool = false
	
	enum ServiceReply {
		case mountInfos(MountInfos)
		case vncURL(String)
		case screenSize(Int, Int)
		case none
	}
	
	private let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
	private var response: ServiceReply? = nil
	private let logger: Logger = .init("ReplyVMRunService")
	
	override init() {
		self.response = nil
		super.init()
	}
	
	required init?(coder: NSCoder) {
		self.response = coder.decodeObject(forKey: "response") as? ServiceReply
	}
	
	func vncURLReply(response: String) {
		self.logger.debug("Received VNC URL: \(response)")
		self.response = .vncURL(response)
	}
	
	func mountReply(response: String) {
		self.logger.debug("Received MountReply: \(response)")
		self.response = .mountInfos(MountInfos(fromJSON: response))
		self.semaphore.signal()
	}
	
	func screenSizeReply(width: Int, height: Int) {
		self.logger.debug("Received ScreenSizeReply")
		self.response = .screenSize(width, height)
		self.semaphore.signal()
	}

	func wait() -> ServiceReply? {
		if self.response == nil {
			self.semaphore.wait()
			/*
			 guard self.semaphore.wait(timeout: .now().advanced(by: .seconds(300))) == .timedOut else {
			 Logger(self).error("Timeout")
			 return nil
			 }*/
		}
		
		return self.response
	}
	
	func encode(with coder: NSCoder) {
		coder.encode(self.response, forKey: "response")
	}
	
	func waitForMountInfosReply() -> MountInfos {
		if let reply = self.wait() {
			if case let .mountInfos(mountInfos) = reply {
				return mountInfos
			}
			
			return MountInfos.with {
				$0.response = .error("Unexpected reply from VMRunService \(reply)")
			}
		}
		
		return MountInfos.with {
			$0.response = .error("Timeout")
		}
	}
	
	@discardableResult func waitForScreenSizeReply() -> (Int, Int) {
		if let reply = self.wait() {
			if case let .screenSize(width, height) = reply {
				return (width, height)
			}
		}

		return (0, 0)
	}
}

class XPCVMRunServiceClient: VMRunServiceClient {
	let location: VMLocation
	let logger: Logger = .init("XPCVMRunServiceClient")
	
	static func createClient(location: VMLocation, runMode: Utils.RunMode) throws -> VMRunServiceClient {
		XPCVMRunServiceClient(location: location)
	}
	
	private init(location: VMLocation) {
		self.location = location
	}
	
	func vncURL() throws -> URL? {
		if location.status == .running {
			let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.VMRunService.\(location.name)")
			let replier = ReplyVMRunService()
			
			xpcConnection.remoteObjectInterface = NSXPCInterface(with: VMRunServiceProtocol.self)
			xpcConnection.exportedInterface = NSXPCInterface(with: ReplyVMRunServiceProtocol.self)
			xpcConnection.exportedObject = replier
			
			xpcConnection.activate()
			
			defer {
				xpcConnection.invalidate()
			}
			
			let proxyObject = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") })
			
			guard let service = proxyObject as? VMRunServiceProtocol else {
				logger.error("Failed to connect to VMRunService")
				throw ServiceError("Failed to connect to VMRunService")
			}
			
			logger.debug("Requesting VNC URL")
			
			service.vncUrl()
			
			logger.debug("Wait VNC URL reply")
			
			if let reply = replier.wait() {
				if case let .vncURL(url) = reply {
					logger.debug("VNC URL reply: \(url)")
					return URL(string: url)
				}
			}
			
			logger.debug("Unexpected VNC URL reply")
		}
		
		return nil
	}
	
	func share(mounts: DirectorySharingAttachments) throws -> MountInfos {
		let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.VMRunService.\(location.name)")
		let replier = ReplyVMRunService()
		
		xpcConnection.remoteObjectInterface = NSXPCInterface(with: VMRunServiceProtocol.self)
		xpcConnection.exportedInterface = NSXPCInterface(with: ReplyVMRunServiceProtocol.self)
		xpcConnection.exportedObject = replier
		
		xpcConnection.activate()
		
		defer {
			xpcConnection.invalidate()
		}
		
		let proxyObject = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") })
		
		guard let service = proxyObject as? VMRunServiceProtocol else {
			throw ServiceError("Failed to connect to VMRunService")
		}
		
		service.mount(request: MountRequest(mounts).toJSON())
		
		return replier.waitForMountInfosReply()
	}
	
	func unshare(mounts: DirectorySharingAttachments) throws -> MountInfos {
		let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.VMRunService.\(location.name)")
		let replier = ReplyVMRunService()
		
		xpcConnection.remoteObjectInterface = NSXPCInterface(with: VMRunServiceProtocol.self)
		xpcConnection.exportedInterface = NSXPCInterface(with: ReplyVMRunServiceProtocol.self)
		xpcConnection.exportedObject = replier
		
		xpcConnection.activate()
		
		defer {
			xpcConnection.invalidate()
		}
		
		guard let service = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") }) as? VMRunServiceProtocol else {
			throw ServiceError("Failed to connect to VMRunService")
		}
		
		service.umount(request: MountRequest(mounts).toJSON())
		
		return replier.waitForMountInfosReply()
	}
	
	func setScreenSize(width: Int, height: Int) throws {
		let config: CakeConfig = try location.config()
		
		config.display = DisplaySize(width: width, height: height)
		try config.save()
		
		if location.status == .running {
			let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.VMRunService.\(location.name)")
			let replier = ReplyVMRunService()
			
			xpcConnection.remoteObjectInterface = NSXPCInterface(with: VMRunServiceProtocol.self)
			xpcConnection.exportedInterface = NSXPCInterface(with: ReplyVMRunServiceProtocol.self)
			xpcConnection.exportedObject = replier
			
			xpcConnection.activate()
			
			defer {
				xpcConnection.invalidate()
			}
			
			guard let service = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") }) as? VMRunServiceProtocol else {
				throw ServiceError("Failed to connect to VMRunService")
			}
			
			service.resizeScreen(width: width, height: height)
			
			replier.waitForScreenSizeReply()
		}
	}
	
	func getScreenSize() throws -> (Int, Int) {
		let xpcConnection: NSXPCConnection = NSXPCConnection(machServiceName: "com.aldunelabs.caked.VMRunService.\(location.name)")
		let replier = ReplyVMRunService()
		
		xpcConnection.remoteObjectInterface = NSXPCInterface(with: VMRunServiceProtocol.self)
		xpcConnection.exportedInterface = NSXPCInterface(with: ReplyVMRunServiceProtocol.self)
		xpcConnection.exportedObject = replier
		
		xpcConnection.activate()
		
		defer {
			xpcConnection.invalidate()
		}
		
		guard let service = xpcConnection.synchronousRemoteObjectProxyWithErrorHandler({ Logger(self).error("Error: \($0)") }) as? VMRunServiceProtocol else {
			throw ServiceError("Failed to connect to VMRunService")
		}
		
		service.getScreenSize()

		return replier.waitForScreenSizeReply()
	}
	
}
