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

extension Vmrun_MountRequest {
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

class GRPCMountService: MountService, @unchecked Sendable, Vmrun_ServiceAsyncProvider {
	var server: Server? = nil

	func createServer() throws -> EventLoopFuture<Server> {
		let listeningAddress = self.vm.location.mountServiceURL
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
			do {
				self.server = try await self.createServer().get()
			} catch {
				Logger.appendNewLine("Failed to start MountService server: \(error)")
			}
		}
	}

	func stop() {
		if let server = self.server {
			try? server.close().wait()
		}
	}

	func mount(request: Vmrun_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Vmrun_MountReply {
		return self.mount(request: request.toCakeAgent(), umount: false).toCaked()
	}

	func umount(request: Vmrun_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Vmrun_MountReply {
		return self.mount(request: request.toCakeAgent(), umount: true).toCaked()
	}
}
