import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Virtualization
import ArgumentParser

public protocol VMRunServiceClient {
	var location: VMLocation { get }

	func vncURL() throws -> URL?
	func setScreenSize(width: Int, height: Int) throws
	func getScreenSize() throws -> (Int, Int)
	func share(mounts: DirectorySharingAttachments) throws -> MountInfos
	func unshare(mounts: DirectorySharingAttachments) throws -> MountInfos
}

extension VMRunServiceClient {
	public func mount(mounts: DirectorySharingAttachments) throws -> MountInfos {
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
				return try self.share(mounts: valided)
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

	func umount(mounts: DirectorySharingAttachments) throws -> MountInfos {
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
				return try self.unshare(mounts: valided)
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
	
	func mount(request: Caked.MountRequest, umount: Bool) -> Caked.Reply {
		guard request.mounts.isEmpty == false else {
			return Caked.Reply.with {
				$0.error = .with {
					$0.reason = "No mounts specified"
				}
			}
		}
		
		do {
			let config: CakeConfig = try vm.location.config()

			if config.os == .darwin {
				guard try vm.mountShares(config: config) else {
					return Caked.Reply.with {
						$0.error = .with {
							$0.reason = "No shared devices"
						}
					}
				}
				
				return Caked.Reply.with {
					$0.response = .mounts(.with {
						$0.response = .success(true)
						$0.mounts = request.mounts.map { mount in
							.with {
								 $0.name = mount.name
								 $0.response = .success(true)
							}
						}
					})
				}
			}
			
			let reply: CakeAgent.MountReply
			let conn = try self.createCakeAgentConnection()
			let request = CakeAgent.MountRequest.with {
				$0.mounts = request.mounts.map { mount in
					.with {
						if mount.hasName {
							$0.name = mount.name
						}
						
						if mount.hasTarget {
							$0.target = mount.target
						}
						
						if mount.hasUid {
							$0.uid = mount.uid
						}
						
						if mount.hasGid {
							$0.gid = mount.gid
						}
					}
				}
			}

			if umount {
				reply = try conn.umount(request: request)
			} else {
				reply = try conn.mount(request: request)
			}

			return Caked.Reply.with {
				if case let .error(value) = reply.response {
					$0.error = .with {
						$0.reason = value
					}
				} else {
					$0.response = .mounts(.with {
						$0.response = .success(true)
						$0.mounts = request.mounts.map { mount in
								.with {
									$0.name = mount.name
									$0.response = .success(true)
								}
						}
					})
				}
			}
		} catch {
			return Caked.Reply.with {
				$0.error = .with {
					$0.reason = error.localizedDescription
				}
			}
		}
	}
	
	func setScreenSize(width: Int, height: Int) {
		vm.setScreenSize(width: width, height: height)
	}
	
	func getScreenSize() throws -> (Int, Int) {
		return vm.getScreenSize()
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
