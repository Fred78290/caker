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

extension CakeAgent.MountReply {
	func toCaked() -> Vmrun_MountReply {
		Vmrun_MountReply.with { mountReply in
			if case let .error(value) = self.response {
				mountReply.error = value
			} else if case let .success(value) = self.response {
				mountReply.success = value
			}

			mountReply.mounts = self.mounts.map { mountVirtioFSReply in
				Vmrun_MountVirtioFSReply.with {
					$0.name = mountVirtioFSReply.name
					if case let .error(value) = mountVirtioFSReply.response {
						$0.error = value
					} else if case let .success(value) = mountVirtioFSReply.response {
						$0.success = value
					}
				}
			}
		}
	}
}

fileprivate extension DirectorySharingAttachment {
	func toMountVirtioFS() -> Vmrun_MountVirtioFS {
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

			if case let .error(value) = self.response {
				$0.response = .error(value)
			} else if case let .success(value) = self.response {
				$0.response = .success(value)
			}
		}
	}
}

extension Vmrun_MountReply {
	func toMountInfos() -> MountInfos {
		if case let .error(value) = self.response {
			return MountInfos.with {
				$0.response = .error(value)
			}
		}
		
		return MountInfos.with {
			$0.response = .success(true)
			$0.mounts = self.mounts.map { $0.toMountVirtioFS() }
		}
	}
}

extension Vmrun_MountRequest {
	init(_ command: Vmrun_MountCommand, attachments: [DirectorySharingAttachment]) {
		self.command = command
		self.mounts = attachments.map {
			$0.toMountVirtioFS()
		}
	}

	func toCakeAgent() -> CakeAgent.MountRequest {
		CakeAgent.MountRequest.with {
			$0.mounts = self.mounts.map { mount in
				CakeAgent.MountRequest.MountVirtioFS.with {
					$0.name = mount.name
					$0.target = mount.target
					$0.uid = Int32(mount.uid)
					$0.gid = Int32(mount.gid)
					$0.readonly = mount.readonly
					$0.early = true
				}
			}
		}
	}
}

extension Vmrun_MountReply {
	init(_ from: CakeAgent.MountReply) {
		self = Vmrun_MountReply.with { mountReply in
			if case let .error(value) = from.response {
				mountReply.error = value
			} else if case let .success(value) = from.response {
				mountReply.success = value
			}

			mountReply.mounts = from.mounts.map { mountVirtioFSReply in
				Vmrun_MountVirtioFSReply.with {
					$0.name = mountVirtioFSReply.name
					if case let .error(value) = mountVirtioFSReply.response {
						$0.error = value
					} else if case let .success(value) = mountVirtioFSReply.response {
						$0.success = value
					}
				}
			}
		}
	}
}

class GRPCVMRunServiceClient: VMRunServiceClient {
	let client: Vmrun_ServiceNIOClient
	
	public static func createClient(location: VMLocation, runMode: Utils.RunMode) throws -> GRPCVMRunServiceClient {
		
		let listeningAddress = location.serviceURL
		let target: ConnectionTarget
		let connectionTimeout: TimeInterval = 5
		let retries: ConnectionBackoff.Retries = .unlimited
		
		if listeningAddress.scheme == "unix" || listeningAddress.isFileURL {
			target = ConnectionTarget.unixDomainSocket(listeningAddress.path())
		} else if listeningAddress.scheme == "tcp" {
			target = ConnectionTarget.hostAndPort(listeningAddress.host ?? "127.0.0.1", listeningAddress.port ?? 5000)
		} else {
			throw ServiceError("unsupported address scheme: \(listeningAddress)")
		}
		
		var clientConfiguration = ClientConnection.Configuration.default(target: target, eventLoopGroup: Utilities.group.next())
		let certLocation = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let tlsCert = try NIOSSLCertificate(file: certLocation.clientCertURL.path, format: .pem)
		let tlsKey = try NIOSSLPrivateKey(file: certLocation.clientKeyURL.path, format: .pem)
		let trustRoots: NIOSSLTrustRoots = .certificates([try NIOSSLCertificate(file: certLocation.caCertURL.path, format: .pem)])
		
		clientConfiguration.tlsConfiguration = GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL(
			certificateChain: [.certificate(tlsCert)],
			privateKey: .privateKey(tlsKey),
			trustRoots: trustRoots,
			certificateVerification: .noHostnameVerification)
		
		if retries != .unlimited {
			clientConfiguration.connectionBackoff = ConnectionBackoff(maximumBackoff: connectionTimeout, minimumConnectionTimeout: connectionTimeout, retries: retries)
		} else {
			clientConfiguration.connectionBackoff = ConnectionBackoff(maximumBackoff: connectionTimeout)
		}
		
		return GRPCVMRunServiceClient(client: Vmrun_ServiceNIOClient(channel: ClientConnection(configuration: clientConfiguration)))
	}
	
	private init(client: Vmrun_ServiceNIOClient) {
		self.client = client
	}
	
	func vncURL() throws -> URL? {
		let result = try client.vncEndPoint(Vmrun_Empty()).response.wait()
		
		if result.hasVncURL {
			return URL(string: result.vncURL)
		}
		
		return nil
	}
	
	func mount(mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		try client.mount(Vmrun_MountRequest(.mount, attachments: mounts)).response.wait().toMountInfos()
	}
	
	func umount(mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		try client.mount(Vmrun_MountRequest(.umount, attachments: mounts)).response.wait().toMountInfos()
	}
	
	func setScreenSize(width: Int, height: Int) throws {
		_ = try client.setScreenSize(Vmrun_ScreenSize.with { $0.width = Int32(width); $0.height = Int32(height) }).response.wait()
	}

	func getScreenSize() throws -> (Int, Int) {
		let reply = try client.getScreenSize(Vmrun_Empty()).response.wait()

		return (Int(reply.width), Int(reply.height))
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
		
		let tlsCert = try NIOSSLCertificate(file: self.certLocation.serverCertURL.path, format: .pem)
		let tlsKey = try NIOSSLPrivateKey(file: self.certLocation.serverKeyURL.path, format: .pem)
		let trustRoots = NIOSSLTrustRoots.certificates([try NIOSSLCertificate(file: self.certLocation.caCertURL.path, format: .pem)])
		
		serverConfiguration.tlsConfiguration = GRPCTLSConfiguration.makeServerConfigurationBackedByNIOSSL(
			certificateChain: [.certificate(tlsCert)],
			privateKey: .privateKey(tlsKey),
			trustRoots: trustRoots,
			certificateVerification: CertificateVerification.none,
			requireALPN: false)
		
		return Server.start(configuration: serverConfiguration)
	}
	
	func serve() {
		Task {
			self.logger.info("Start GRPC VMRunService server")
			do {
				self.server = try await self.createServer().get()
			} catch {
				Logger.appendNewLine("Failed to start GRPC VMRunService server: \(error)")
			}
		}
	}
	
	func stop() {
		self.logger.info("Stop GRPC VMRunService server")
		
		if let server = self.server {
			try? server.close().wait()
		}
	}
	
	func vncEndPoint(request: Vmrun_Empty, context: GRPCAsyncServerCallContext) async throws -> Vmrun_VNCEndPointReply {
		guard let u = self.vm.vncURL else {
			return Vmrun_VNCEndPointReply()
		}
		
		return Vmrun_VNCEndPointReply.with { reply in
			reply.vncURL = u.absoluteString
		}
	}
	
	func mount(request: Vmrun_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Vmrun_MountReply {
		return self.mount(request: request.toCakeAgent(), umount: false).toCaked()
	}
	
	func umount(request: Vmrun_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Vmrun_MountReply {
		return self.mount(request: request.toCakeAgent(), umount: true).toCaked()
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
	

}
