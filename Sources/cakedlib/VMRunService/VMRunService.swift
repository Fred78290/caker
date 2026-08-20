import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Virtualization

public struct VNCInfos: Codable {
	public var urls: [String] = []
	public var screenSize: ViewSize? = nil

	public init() {
		self.urls = []
		self.screenSize = nil
	}

	public init(urls: [URL], screenSize: (width: Int, height: Int)) {
		self.urls = urls.map(\.absoluteString)
		self.screenSize = .init(width: screenSize.width, height: screenSize.height)
	}

	public init(urls: [String], screenSize: ViewSize?) {
		self.urls = urls
		self.screenSize = screenSize
	}
}

public enum SignalType: Int32, CaseIterable {
	case empty // = 0
	case shutdown // = 1
	case requestStop // = 2
	case suspend // = 3
}

public protocol VMRunServiceClient {
	var location: VMLocation { get }
	var vncInfos: VNCInfos { get }
	var screenSize: (width: Int, height: Int) { set get }

	func share(mounts: DirectorySharingAttachments) throws -> MountInfos
	func unshare(mounts: DirectorySharingAttachments) throws -> MountInfos
	func installAgent(timeout: UInt) throws -> (installed: Bool, reason: String)
	func startGrandCentralUpdate(frequency: Int32) throws -> (success: Bool, reason: String)
	func stopGrandCentralUpdate() throws -> (success: Bool, reason: String)
	func signal(signal: SignalType) throws -> (success: Bool, reason: String)
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

			if case .running = location.status {
				return try self.share(mounts: valided)
			} else {
				return MountInfos.with {
					$0.success = false
					$0.reason = String(localized: "VM is not running")
				}
			}
		}

		return MountInfos.with {
			$0.success = false
			$0.reason = String(localized: "No new mounts")
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

			if case .running = location.status {
				return try self.unshare(mounts: valided)
			} else {
				return MountInfos.with {
					$0.success = false
					$0.reason = String(localized: "VM is not running")
				}
			}
		}

		return MountInfos.with {
			$0.success = false
			$0.reason = String(localized: "No umounts")
		}
	}
}

public protocol VMRunServiceServerProtocol {
	func serve()
	func stop()
}

public class NoneVMRunServiceServer: VMRunServiceServerProtocol {
	public func serve() {
	}

	public func stop() {
	}
}

public enum VMRunServiceMode: String, CustomStringConvertible, ExpressibleByArgument, CaseIterable, EnumerableFlag {
	public var description: String {
		return self.rawValue
	}

	case disabled
	case grpc
	case xpc

	public static var `default`: VMRunServiceMode {
		return .grpc
	}

	public func client(location: VMLocation, runMode: Utils.RunMode) throws -> VMRunServiceClient? {
		switch self {

		case .disabled:
			return nil
		case .grpc:
			return try GRPCVMRunServiceClient.createClient(location: location, runMode: runMode)
		case .xpc:
			return try XPCVMRunServiceClient.createClient(location: location, runMode: runMode)
		}
	}

	public func serve(group: EventLoopGroup, runMode: Utils.RunMode, vm: VirtualMachine, certLocation: CertificatesLocation) -> VMRunServiceServerProtocol {
		switch self {
		case .disabled:
			return NoneVMRunServiceServer()
		case .grpc:
			return GRPCVMRunService(group: group.next(), runMode: runMode, vm: vm, certLocation: certLocation, logger: Logger("GRPCVMRunService"))
		case .xpc:
			return XPCVMRunServiceServer(group: group.next(), runMode: runMode, vm: vm, certLocation: certLocation)
		}
	}
}

class VMRunService: NSObject {
	weak var vm: VirtualMachine!
	let logger: Logger
	let runMode: Utils.RunMode
	let certLocation: CertificatesLocation
	let group: EventLoopGroup

#if TRACE
	deinit {
		print("VMRunService deinit")
	}
#endif

	var vncURL: VNCInfos? {
		if let vncURL = self.vm.vncURL {
			return VNCInfos(urls: vncURL, screenSize: vm.getScreenSize())
		}

		return nil
	}

	init(group: EventLoopGroup, runMode: Utils.RunMode, vm: VirtualMachine, certLocation: CertificatesLocation, logger: Logger) {
		self.vm = vm
		self.runMode = runMode
		self.group = group
		self.certLocation = certLocation
		self.logger = logger
	}

	func createCakeAgentHelper(retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentHelper {
		return try CakeAgentHelper(
			on: self.group.next(),
			listeningAddress: self.vm.location.agentURL,
			connectionTimeout: 30,
			caCert: self.certLocation.caCertURL.path(percentEncoded: false),
			tlsCert: self.certLocation.clientCertURL.path(percentEncoded: false),
			tlsKey: self.certLocation.clientKeyURL.path(percentEncoded: false),
			retries: retries)
	}

	func mount(request: Caked.MountRequest, umount: Bool) -> Caked_MountReply {
		guard request.mounts.isEmpty == false else {
			return Caked_MountReply.with {
				$0.success = false
				$0.mounts = []
				$0.reason = "No mounts specified"
			}
		}

		do {
			let config: CakeConfig = try vm.location.config()

			if config.os == .darwin {
				guard try vm.mountShares(config: config) else {
					return Caked_MountReply.with {
						$0.success = false
						$0.mounts = []
						$0.reason = String(localized: "No shared devices")
					}
				}

				return Caked_MountReply.with {
					$0.success = true
					$0.reason = String.empty
					$0.mounts = request.mounts.map { mount in
						.with {
							$0.mounted = true
							$0.name = mount.name
							$0.reason = String.empty
						}
					}
				}
			}

			let reply: CakeAgent.MountReply
			let conn = try self.createCakeAgentHelper()
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

			return Caked_MountReply.with {
				if case .error(let value) = reply.response {
					$0.success = false
					$0.reason = value
					$0.mounts = request.mounts.map { mount in
						.with {
							$0.name = mount.name
							$0.mounted = false
						}
					}
				} else {
					$0.success = true
					$0.reason = String(localized: "Success")
					$0.mounts = request.mounts.map { mount in
						.with {
							$0.name = mount.name
							$0.mounted = true
						}
					}
				}
			}
		} catch {
			return Caked_MountReply.with {
				$0.success = false
				$0.reason = error.reason
				$0.mounts = request.mounts.map { mount in
					.with {
						$0.name = mount.name
						$0.mounted = false
					}
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

	func installAgent(timeout: UInt) async throws -> Bool {
		try await self.vm.installAgent(updateAgent: self.vm.env.config.agent, timeout: timeout, runMode: self.runMode)
	}
}
