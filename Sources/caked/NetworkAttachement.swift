import Foundation
import GRPCLib
import NIO
import Virtualization

var phUseLimaVMNet = false
protocol NetworkAttachement {
	func attachment(vmLocation: VMLocation, runMode: Utils.RunMode) throws -> (VZMACAddress, VZNetworkDeviceAttachment)
	func stop(runMode: Utils.RunMode)
}

// MARK: - Network shared
class NATNetworkInterface: NetworkAttachement {
	let macAddress: VZMACAddress

	init(macAddress: VZMACAddress) {
		self.macAddress = macAddress
	}

	func attachment(vmLocation: VMLocation, runMode: Utils.RunMode) throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZNATNetworkDeviceAttachment())
	}

	func stop(runMode: Utils.RunMode) {
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

	func attachment(vmLocation: VMLocation, runMode: Utils.RunMode) throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZBridgedNetworkDeviceAttachment(interface: interface))
	}

	func stop(runMode: Utils.RunMode) {
	}
}

class SharedNetworkInterface: NetworkAttachement, VZVMNetHandlerClient.CloseDelegate {
	let macAddress: VZMACAddress
	let mode: VMNetMode
	let networkName: String
	let networkConfig: VZSharedNetwork?
	var process: ProcessWithSharedFileHandle? = nil
	var pipeChannel: Channel? = nil
	var vmfd: Int32 = -1
	var hostfd: Int32 = -1
	var pidURL: URL? = nil

	init(mode: VMNetMode, networkName: String, macAddress: VZMACAddress) {
		self.mode = mode
		self.networkName = networkName
		self.macAddress = macAddress
		self.networkConfig = nil
	}

	init(macAddress: VZMACAddress, networkName: String = "shared", networkConfig: VZSharedNetwork? = nil) {
		self.mode = .shared
		self.networkName = networkName
		self.macAddress = macAddress
		self.networkConfig = networkConfig
	}

	func attachment(vmLocation: VMLocation, runMode: Utils.RunMode) throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZFileHandleNetworkDeviceAttachment(fileHandle: try self.open(vmLocation: vmLocation, runMode: runMode)))
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
			throw ServiceError("setsockopt(SO_SNDBUF) returned \(ret), \(String(cString:strerror(errno)))")
		}
	}

	internal func vmnetEndpoint(runMode: Utils.RunMode) throws -> (URL, URL) {
		if runMode.isSystem {
			return try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: runMode)
		} else {
			let systemSocketURL = try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: .system)

			if try systemSocketURL.0.exists() == false {
				return try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: runMode)
			} else {
				return systemSocketURL
			}
		}
	}

	internal func open(vmLocation: VMLocation, runMode: Utils.RunMode) throws -> FileHandle {
		var socketURL = try self.vmnetEndpoint(runMode: runMode)

		if try socketURL.0.exists() == false && (VMRun.launchedFromService || runMode == .app) {
			socketURL = try NetworksHandler.start(networkName: networkName, runMode: runMode)
		}

		let socketAddress = try SocketAddress(unixDomainSocketPath: socketURL.0.path)

		(self.vmfd, self.hostfd) = try socketAddress.withSockAddr { _, len in
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
						.takingOwnershipOfDescriptor(inputOutput: self.hostfd)
						.flatMap { childChannel in
							let (guestHandler, hostHandler) = VZVMNetHandlerClient.matchedPair(useLimaVMNet: false, delegate: self)

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

			let pidURL = vmLocation.rootURL.appending(path: "\(self.networkName).pid")
			self.process = try NetworksHandler.run(fileDescriptor: hostfd, networkConfig: .init(name: networkName, config: networkConfig), pidFile: pidURL, runMode: runMode)
			self.pidURL = pidURL
		}

		return FileHandle(fileDescriptor: self.vmfd, closeOnDealloc: true)
	}

	func stop(runMode: Utils.RunMode) {
		if let process {
			if process.isRunning {
				if geteuid() != 0 {
					_ = try? NetworksHandler.stop(pidURL: self.pidURL!, runMode: runMode)
				} else {
					// Otherwise, we can just kill the process directly
					kill(process.processIdentifier, SIGTERM)
				}

				Logger(self).info("Terminated VZVMNet process")

				self.process = nil
			}
		} else if let pipeChannel {
			// If we are running as a service, we need to close the channel
			let promise = pipeChannel.eventLoop.makePromise(of: Void.self)

			pipeChannel.close(promise: promise)

			do {
				try promise.futureResult.wait()
			} catch {
				Logger(self).error("Failed to close VZVMNet channel, \(error)")
			}

			self.pipeChannel = nil
		}

		if self.vmfd != -1 {
			close(self.vmfd)
			self.vmfd = -1
		}

		if self.hostfd != -1 {
			close(self.hostfd)
			self.hostfd = -1
		}
	}
}

class HostNetworkInterface: SharedNetworkInterface {
	init(macAddress: VZMACAddress) {
		super.init(mode: .host, networkName: "host", macAddress: macAddress)
	}
}

class VMNetworkInterface: SharedNetworkInterface {
	let interface: VZBridgedNetworkInterface

	init(interface: VZBridgedNetworkInterface, macAddress: VZMACAddress) {
		self.interface = interface
		super.init(mode: .bridged, networkName: interface.identifier, macAddress: macAddress)
	}
}
