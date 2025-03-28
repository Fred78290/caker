import Foundation
import Virtualization
import GRPCLib
import NIO

var phUseLimaVMNet = false
protocol NetworkAttachement {
	func attachment(vmLocation: VMLocation) throws -> (VZMACAddress, VZNetworkDeviceAttachment)
	func stop()
}

// MARK: - Network shared
class NATNetworkInterface: NetworkAttachement {
	let macAddress: VZMACAddress

	init(macAddress: VZMACAddress) {
		self.macAddress = macAddress
	}

	func attachment(vmLocation: VMLocation) throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZNATNetworkDeviceAttachment())
	}
	
	func stop() {
	}
}

// MARK: - Network bridged
class BridgedNetworkInterface: NetworkAttachement {
	let interface: VZBridgedNetworkInterface
	let macAddress: VZMACAddress
	
	init(interface: VZBridgedNetworkInterface, macAddress: VZMACAddress) {
		self.interface = interface
		self.macAddress = macAddress
	}
	
	func attachment(vmLocation: VMLocation) throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZBridgedNetworkDeviceAttachment(interface: interface))
	}
	
	func stop() {
	}
}

class SharedNetworkInterface: NetworkAttachement, VZVMNetHandlerClient.CloseDelegate {
	let macAddress: VZMACAddress
	let mode: VMNetMode
	let networkInterface: String?
	var process: ProcessWithSharedFileHandle? = nil
	var pipeChannel: Channel? = nil

	init(mode: VMNetMode, networkInterface: String, macAddress: VZMACAddress) {
		self.mode = mode
		self.networkInterface = networkInterface
		self.macAddress = macAddress
	}

	init(macAddress: VZMACAddress) {
		self.mode = .shared
		self.networkInterface = nil
		self.macAddress = macAddress
	}

	func attachment(vmLocation: VMLocation) throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZFileHandleNetworkDeviceAttachment(fileHandle: try self.open(vmLocation: vmLocation)))
	}
	
	func closed(side: VZVMNetHandlerClient.HandlerSide) {
		if self.pipeChannel != nil {
			self.pipeChannel = nil
			
			if side == .host {
				Logger(self).info("VMNet closed by the host")
			} else {
				Logger(self).info("VMNet closed by the guest")
			}
		}
	}
	
	internal func setSocketBuffers(fd: Int32, sizeBytes: Int) throws {
		let option_len = socklen_t(MemoryLayout<Int>.size)
		var sendBufferSize = sizeBytes
		var receiveBufferSize = 4 * sizeBytes
		var ret = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &receiveBufferSize, option_len)
		
		if ret != 0 {
			perror("setsockopt(SO_RCVBUF) returned \(ret)")
			throw ServiceError("setsockopt(SO_RCVBUF) returned \(ret)")
		}
		
		ret = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sendBufferSize, option_len)
		
		if ret != 0 {
			perror("setsockopt(SO_SNDBUF) returned \(ret)")
			throw ServiceError("setsockopt(SO_SNDBUF) returned \(ret), \(errno)")
		}
	}
	
	internal func vmnetEndpoint() throws -> (URL, URL){
		if runAsSystem {
			return try NetworksHandler.vmnetEndpoint(mode: self.mode, networkInterface: networkInterface, asSystem: runAsSystem)
		} else {
			let systemSocketURL = try NetworksHandler.vmnetEndpoint(mode: self.mode, networkInterface: networkInterface, asSystem: true)
			
			if try systemSocketURL.0.exists() == false {
				return try NetworksHandler.vmnetEndpoint(mode: self.mode, networkInterface: networkInterface, asSystem: false)
			} else {
				return systemSocketURL
			}
		}
	}

	internal func open(vmLocation: VMLocation) throws -> FileHandle {
		let socketURL = try self.vmnetEndpoint()
		
		if try socketURL.0.exists() == false && VMRun.launchedFromService {
			try NetworksHandler.run(useLimaVMNet: phUseLimaVMNet, mode: self.mode, networkInterface: networkInterface, socketPath: socketURL.0, pidFile: socketURL.1)
			try socketURL.1.waitPID()
		}
		
		let socketAddress = try SocketAddress(unixDomainSocketPath: socketURL.0.path)
		let (vmfd, hostfd) = try socketAddress.withSockAddr { _, len in
			let fds: UnsafeMutablePointer<Int32> = UnsafeMutablePointer<Int32>.allocate(capacity: MemoryLayout<Int>.stride * 2)
			
			defer {
				fds.deallocate()
			}
			
			if socketpair(AF_UNIX, SOCK_DGRAM, 0, fds) != 0 {
				throw ServiceError("unable to create socket with exit code \(String(errno: errno))")
			}
			
			try setSocketBuffers(fd: fds[0], sizeBytes: 1024 * 1024)
			try setSocketBuffers(fd: fds[1], sizeBytes: 1024 * 1024)
			
			return (fds[0], fds[1])
		}
		
		if try socketURL.0.exists() {
			Logger(self).info("Use VZVMNet at: \(socketURL.0.path)")

			let client = ClientBootstrap(group: Root.group)
				.channelInitializer { inboundChannel in
					// When the child channel is created, create a new pipe and add the handlers
					return NIOPipeBootstrap(group: inboundChannel.eventLoop)
						.takingOwnershipOfDescriptor(inputOutput: hostfd)
						.flatMap { childChannel in
							let (guestHandler, hostHandler) = VZVMNetHandlerClient.matchedPair(useLimaVMNet: phUseLimaVMNet, delegate: self)
							
							return childChannel.pipeline.addHandler(guestHandler)
								.flatMap {
									inboundChannel.pipeline.addHandler(hostHandler)
								}
						}
				}
			
			let futureChannel = client.connect(to: socketAddress)
			
			futureChannel.whenComplete { result in
				switch result {
				case .success:
					Logger(self).info("Network file handle connected to \(socketURL.0.path)")
				case .failure(let error):
					Logger(self).error("Network file handle failed to connect to \(socketURL.0.path), \(error)")
				}
			}
			
			self.pipeChannel = try futureChannel.wait()
		} else {
			Logger(self).info("Use standalone VZVMNet with fd: \(vmfd)")

			self.process = try NetworksHandler.run(fileDescriptor: hostfd, mode: self.mode, networkInterface: networkInterface, macAddress: self.macAddress.string, pidFile: vmLocation.vmnetPID)
		}
		
		return FileHandle(fileDescriptor: vmfd, closeOnDealloc: true)
	}
	
	func stop() {
		if let process {
			if process.isRunning {
				if geteuid() != 0 {
					// If we are not running as root, we need to kill the process with sudo
					let _ = try? Shell.sudo(to: "kill \(process.processIdentifier)")
				} else {
					// Otherwise, we can just kill the process directly
					kill(process.processIdentifier, SIGTERM)
				}

				Logger(self).info("Terminated VZVMNet process")

				self.process = nil
			}
		}
	}
}
class VMNetworkInterface: SharedNetworkInterface {
	let interface: VZBridgedNetworkInterface
	
	init(interface: VZBridgedNetworkInterface, macAddress: VZMACAddress) {
		self.interface = interface
		super.init(mode: .bridged, networkInterface: interface.identifier, macAddress: macAddress)
	}
}
