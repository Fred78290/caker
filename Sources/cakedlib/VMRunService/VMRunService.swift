import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Virtualization
import ArgumentParser

public protocol VMRunServiceClient {
	func vncURL() throws -> URL?
	func setScreenSize(width: Int, height: Int) throws
	func mount(mounts: [DirectorySharingAttachment]) throws -> MountInfos
	func umount(mounts: [DirectorySharingAttachment]) throws -> MountInfos
}

protocol VMRunServiceServerProtocol {
	func serve()
	func stop()
}

public enum VMRunServiceMode: String, CustomStringConvertible, ExpressibleByArgument, CaseIterable, EnumerableFlag {
	public var description: String {
		return self.rawValue
	}
	
	case grpc
	case xpc
}

class VMRunService: NSObject {
	let logger: Logger
	let runMode: Utils.RunMode
	let vm: VirtualMachine
	let certLocation: CertificatesLocation
	let group: EventLoopGroup

	var vncURL: URL? {
		return vm.vncURL
	}

	init(group: EventLoopGroup, runMode: Utils.RunMode, vm: VirtualMachine, certLocation: CertificatesLocation, logger: Logger) {
		self.vm = vm
		self.runMode = runMode
		self.group = group
		self.certLocation = certLocation
		self.logger = logger
	}

	func createCakeAgentConnection(retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentHelper {
		return try CakeAgentHelper(
			on: self.group.next(),
			listeningAddress: self.vm.location.agentURL,
			connectionTimeout: 30,
			caCert: self.certLocation.caCertURL.path,
			tlsCert: self.certLocation.clientCertURL.path,
			tlsKey: self.certLocation.clientKeyURL.path,
			retries: retries)
	}

	func mount(request: CakeAgent.MountRequest, umount: Bool) -> CakeAgent.MountReply {
		guard request.mounts.isEmpty == false else {
			return CakeAgent.MountReply.with {
				$0.response = .error("No mounts")
			}
		}

		do {
			let config: CakeConfig = try vm.location.config()

			if config.os == .darwin {
				guard let sharedDevices: VZVirtioFileSystemDevice = vm.virtualMachine.directorySharingDevices.first as? VZVirtioFileSystemDevice else {
					return CakeAgent.MountReply.with {
						$0.response = .error("No shared devices")
					}
				}

				DispatchQueue.main.sync {
					sharedDevices.share = config.mounts.multipleDirectoryShares
				}

				return CakeAgent.MountReply.with {
					$0.response = .success(true)
					$0.mounts = request.mounts.map { mount in
						CakeAgent.MountReply.MountVirtioFSReply.with {
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
			return CakeAgent.MountReply.with {
				$0.response = .error(error.localizedDescription)
			}
		}
	}

	func setScreenSize(width: Int, height: Int) {
		vm.setScreenSize(width: width, height: height)
	}
}

public func createVMRunServiceClient(_ mode: VMRunServiceMode, location: VMLocation, runMode: Utils.RunMode) throws -> VMRunServiceClient {
	if mode == .xpc {
		return try XPCVMRunServiceClient.createClient(location: location, runMode: runMode)
	} else {
		return try GRPCVMRunServiceClient.createClient(location: location, runMode: runMode)
	}
}

func createVMRunServiceServer(_ mode: VMRunServiceMode, group: EventLoopGroup, runMode: Utils.RunMode, vm: VirtualMachine, certLocation: CertificatesLocation) -> VMRunServiceServerProtocol {
	if mode == .xpc {
		return XPCVMRunServiceServer(group: group.next(), runMode: runMode, vm: vm, certLocation: certLocation)
	} else {
		return GRPCVMRunService(group: group.next(), runMode: runMode, vm: vm, certLocation: certLocation, logger: Logger("GRPCVMRunService"))
	}
}
