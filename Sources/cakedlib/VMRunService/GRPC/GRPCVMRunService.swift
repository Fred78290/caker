import CakeAgentLib
import Crypto
import Foundation
import GRPC
import GRPCLib
import NIO
import NIOSSL
import Semaphore
import SwiftASN1
import X509

extension Caked_MountReply {
	func toCaked() -> Vmrun_MountReply {
		.init(self)
	}
}

extension DirectorySharingAttachment {
	fileprivate func toMountVirtioFS() -> Vmrun_MountVirtioFS {
		Vmrun_MountVirtioFS.with {
			$0.source = self.source
			$0.name = self.name
			$0.uid = Int32(self.uid)
			$0.gid = Int32(self.gid)
			$0.readonly = self.readOnly

			if let destination {
				$0.target = destination
			}
		}
	}
}

extension Vmrun_MountVirtioFSReply {
	func toMountVirtioFS() -> MountVirtioFS {
		MountVirtioFS.with {
			$0.name = self.name
			if case .error(let value) = self.response {
				$0.reason = value
				$0.mounted = false
			} else {
				$0.reason = ""
				$0.mounted = true
			}
		}
	}
}

extension Vmrun_MountReply {
	func toMountInfos() -> MountInfos {
		if case .error(let value) = self.response {
			return MountInfos.with {
				$0.success = false
				$0.reason = value
				$0.mounts = self.mounts.map { $0.toMountVirtioFS() }
			}
		}

		return MountInfos.with {
			$0.success = true
			$0.reason = "Success"
			$0.mounts = self.mounts.map { $0.toMountVirtioFS() }
		}
	}
}

extension Vmrun_MountRequest {
	init(_ command: Vmrun_MountCommand, attachments: DirectorySharingAttachments) {
		self.command = command
		self.mounts = attachments.map {
			$0.toMountVirtioFS()
		}
	}

	func toCaked() -> Caked.MountRequest {
		Caked.MountRequest.with {
			$0.mounts = self.mounts.map { mount in
				Caked.MountRequest.MountVirtioFS.with {
					$0.name = mount.name
					$0.target = mount.target
					$0.uid = Int32(mount.uid)
					$0.gid = Int32(mount.gid)
					$0.readonly = mount.readonly
				}
			}
		}
	}
}

extension Vmrun_MountReply {
	init(_ from: Caked_MountReply) {
		self = Vmrun_MountReply.with { mountReply in
			if from.success {
				mountReply.response = .success(true)
			} else {
				mountReply.response = .error(from.reason)
			}

			mountReply.mounts = from.mounts.map { mountVirtioFSReply in
				Vmrun_MountVirtioFSReply.with {
					$0.name = mountVirtioFSReply.name
					if mountVirtioFSReply.mounted {
						$0.success = true
					} else {
						$0.error = mountVirtioFSReply.reason
					}
				}
			}
		}
	}
}

class GRPCVMRunServiceClient: VMRunServiceClient {
	let client: Vmrun_ServiceNIOClient
	let location: VMLocation
	
	public static func createClient(location: VMLocation, runMode: Utils.RunMode) throws -> GRPCVMRunServiceClient {
		
		let listeningAddress = location.serviceURL
		let target: ConnectionTarget
		let connectionTimeout: TimeInterval = 5
		let retries: ConnectionBackoff.Retries = .upTo(1)
		
		if listeningAddress.scheme == "unix" || listeningAddress.isFileURL {
			target = ConnectionTarget.unixDomainSocket(listeningAddress.path())
		} else if listeningAddress.scheme == "tcp" {
			target = ConnectionTarget.hostAndPort(listeningAddress.host ?? "127.0.0.1", listeningAddress.port ?? 5000)
		} else {
			throw ServiceError("unsupported address scheme: \(listeningAddress)")
		}
		
		var clientConfiguration = ClientConnection.Configuration.default(target: target, eventLoopGroup: Utilities.group.next())
		let certLocation = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		
		clientConfiguration.tlsConfiguration = try GRPCTLSConfiguration.makeClientConfiguration(
			caCert: certLocation.caCertURL.path,
			tlsKey: certLocation.clientKeyURL.path,
			tlsCert: certLocation.clientCertURL.path)
		
		if retries != .unlimited {
			clientConfiguration.connectionBackoff = ConnectionBackoff(maximumBackoff: connectionTimeout, minimumConnectionTimeout: connectionTimeout, retries: retries)
		} else {
			clientConfiguration.connectionBackoff = ConnectionBackoff(maximumBackoff: connectionTimeout)
		}
		
		return GRPCVMRunServiceClient(location: location, client: Vmrun_ServiceNIOClient(channel: ClientConnection(configuration: clientConfiguration)))
	}
	
	private init(location: VMLocation, client: Vmrun_ServiceNIOClient) {
		self.location = location
		self.client = client
	}

	var vncURL: [URL] {
		get {
			guard let result = try? client.vncEndPoint(Vmrun_Empty()).response.wait() else {
				return []
			}
	
			return result.vncURL.compactMap {
				URL(string: $0)
			}
		}
	}
	
	var screenSize: (width: Int, height: Int) {
		get {
			guard let reply = try? client.getScreenSize(Vmrun_Empty()).response.wait() else {
				return (0, 0)
			}
			
			return (Int(reply.width), Int(reply.height))
		}
		
		set {
			_ = try? client.setScreenSize(
				Vmrun_ScreenSize.with {
					$0.width = Int32(newValue.width)
					$0.height = Int32(newValue.height)
				}
			).response.wait()
		}
	}
		
	func share(mounts: DirectorySharingAttachments) throws -> MountInfos {
		try client.mount(Vmrun_MountRequest(.mount, attachments: mounts)).response.wait().toMountInfos()
	}
	
	func unshare(mounts: DirectorySharingAttachments) throws -> MountInfos {
		try client.mount(Vmrun_MountRequest(.umount, attachments: mounts)).response.wait().toMountInfos()
	}
	
	func setScreenSize(width: Int, height: Int) throws {
		_ = try client.setScreenSize(
			Vmrun_ScreenSize.with {
				$0.width = Int32(width)
				$0.height = Int32(height)
			}
		).response.wait()
	}
		
	func installAgent(timeout: UInt) throws -> (installed: Bool, reason: String) {
		let reply = try client.installAgent(.with {
			$0.timeout = Int32(timeout)
		}).response.wait()
		
		return (reply.installed, reply.reason)
	}

	func startGrandCentralUpdate(frequency: Int32) throws -> (success: Bool, reason: String) {
		let reply = try client.startGrandCentralUpdate(.with { $0.frequency = frequency }).response.wait()
		
		return (reply.success, reply.reason)
	}
	
	func stopGrandCentralUpdate() throws -> (success: Bool, reason: String) {
		let reply = try client.stopGrandCentralUpdate(.init()).response.wait()

		return (reply.success, reply.reason)
	}
}

class GRPCVMRunService: VMRunService, @unchecked Sendable, Vmrun_ServiceAsyncProvider, VMRunServiceServerProtocol {
	var server: Server? = nil

	func createServer() throws -> EventLoopFuture<Server> {
		let listeningAddress = self.vm.location.serviceURL
		let target: ConnectionTarget

		if listeningAddress.isFileURL || listeningAddress.scheme == "unix" {
			try listeningAddress.deleteIfFileExists()
			target = ConnectionTarget.unixDomainSocket(listeningAddress.path)
		} else if listeningAddress.scheme == "tcp" {
			target = ConnectionTarget.hostAndPort(listeningAddress.host ?? "127.0.0.1", listeningAddress.port ?? 5000)
		} else {
			throw ServiceError("unsupported listening address scheme: \(String(describing: listeningAddress.scheme))")
		}

		var serverConfiguration = Server.Configuration.default(target: target, eventLoopGroup: self.group, serviceProviders: [self])

		serverConfiguration.tlsConfiguration = try GRPCTLSConfiguration.makeServerConfiguration(caCert: self.certLocation.caCertURL.path,
																								tlsKey: self.certLocation.serverKeyURL.path,
																								tlsCert: self.certLocation.serverCertURL.path)

		return Server.start(configuration: serverConfiguration)
	}

	func serve() {
		Task {
			#if DEBUG
				self.logger.debug("Start GRPC VMRunService server")
			#endif

			do {
				self.server = try await self.createServer().get()
			} catch {
				self.logger.error("Failed to start GRPC VMRunService server: \(error)")
			}
		}
	}

	func stop() {
		#if DEBUG
			self.logger.debug("Stop GRPC VMRunService server")
		#endif

		if let server = self.server {
			try? server.close().wait()
		}
	}

	func vncEndPoint(request: Vmrun_Empty, context: GRPCAsyncServerCallContext) async throws -> Vmrun_VNCEndPointReply {
		guard let vncURL = self.vm.vncURL else {
			return Vmrun_VNCEndPointReply()
		}

		return Vmrun_VNCEndPointReply.with { reply in
			reply.vncURL = vncURL.map(\.absoluteString)
		}
	}

	func installAgent(request: Vmrun_InstalledAgentRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Vmrun_InstalledAgentReply {
		do {
			let installed = try await self.installAgent(timeout: UInt(request.timeout))

			return .with {
				$0.installed = installed
			}
		} catch {
			return .with {
				$0.installed = false
				$0.reason = "\(error)"
			}
		}
	}
	
	func mount(request: Vmrun_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Vmrun_MountReply {
		return self.mount(request: request.toCaked(), umount: false).toCaked()
	}

	func umount(request: Vmrun_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Vmrun_MountReply {
		return self.mount(request: request.toCaked(), umount: true).toCaked()
	}

	func setScreenSize(request: Vmrun_ScreenSize, context: GRPCAsyncServerCallContext) async throws -> Vmrun_Empty {
		self.setScreenSize(width: Int(request.width), height: Int(request.height))

		return Vmrun_Empty()
	}

	func getScreenSize(request: Vmrun_Empty, context: GRPCAsyncServerCallContext) async throws -> Vmrun_ScreenSize {
		let screenSize = self.vm.getScreenSize()

		return Vmrun_ScreenSize.with {
			$0.width = Int32(screenSize.0)
			$0.height = Int32(screenSize.1)
		}
	}

	func startGrandCentralUpdate(request: Vmrun_FrequencyRequest, context: GRPCAsyncServerCallContext) async throws -> Vmrun_GrandCentralUpdateReply {
		do {
			try await self.vm.startGrandCentralUpdate(frequency: request.frequency, runMode: self.runMode)
		} catch {
			return .with {
				$0.success = false
				$0.reason = "\(error)"
			}
		}

		return .with {
			$0.success = true
		}
	}
	
	func stopGrandCentralUpdate(request: Vmrun_Empty, context: GRPCAsyncServerCallContext) async throws -> Vmrun_GrandCentralUpdateReply {
		do {
			try self.vm.stopGrandCentralUpdate()
		} catch {
			return .with {
				$0.success = false
				$0.reason = "\(error)"
			}
		}

		return .with {
			$0.success = true
		}
	}
}
