import Foundation
import CakeAgentLib
import GRPC
import GRPCLib
import NIO
import Virtualization

protocol MountServiceClient {
	func mount(mounts: [DirectorySharingAttachment]) throws -> MountInfos
	func umount(mounts: [DirectorySharingAttachment]) throws -> MountInfos
}

protocol MountServiceServerProtocol {
	func serve()
	func stop()
}


class MountService: NSObject {
	let asSystem: Bool
	let vm: VirtualMachine
	let certLocation: CertificatesLocation
	let group: EventLoopGroup

	init(group: EventLoopGroup, asSystem: Bool, vm: VirtualMachine, certLocation: CertificatesLocation) {
		self.vm = vm
		self.asSystem = asSystem
		self.group = group
		self.certLocation = certLocation
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

	func mount(request: Cakeagent_MountRequest, umount: Bool) -> Cakeagent_MountReply {
		guard request.mounts.isEmpty == false else {
			return Cakeagent_MountReply.with {
				$0.response = .error("No mounts")
			}
		}

		do {
			let config: CakeConfig = try vm.vmLocation.config()

			if config.os == .darwin {
				guard let sharedDevices: VZVirtioFileSystemDevice = vm.virtualMachine.directorySharingDevices.first as? VZVirtioFileSystemDevice else {
					return Cakeagent_MountReply.with { 
						$0.response = .error("No shared devices")
					}
				}

				DispatchQueue.main.sync {
					sharedDevices.share = config.mounts.multipleDirectoryShares
				}

				return Cakeagent_MountReply.with {
					$0.response = .success(true)
					$0.mounts = request.mounts.map { mount in
						Cakeagent_MountVirtioFSReply.with { 
							$0.name = mount.name
							$0.response = .success(true)
						}
					}
				}
			}

			let conn = try self.createCakeAgentConnection()

			if umount {
				return try conn.umount(request: request)
			} else {
				return try conn.mount(request: request)
			}

		} catch {
			return Cakeagent_MountReply.with {
				$0.response = .error(error.localizedDescription)
			}
		}
	}
}

func createMountServiceClient(vmLocation: VMLocation) -> MountServiceClient {
	return XPCMountServiceClient(vmLocation: vmLocation)
}

func createMountServiceServer(group: EventLoopGroup, asSystem: Bool, vm: VirtualMachine, certLocation: CertificatesLocation) -> MountServiceServerProtocol {
	return XPCMountServiceServer(group: Root.group.next(), asSystem: asSystem, vm: vm, certLocation: certLocation)
}

