import Foundation
import Virtualization
import GRPCLib
import NIO

protocol NetworkAttachement {
	func attachment() throws -> (VZMACAddress, VZNetworkDeviceAttachment)
}

// MARK: - Network shared
class SharedNetworkInterface: NetworkAttachement {
	let macAddress: VZMACAddress

	init(macAddress: VZMACAddress) {
		self.macAddress = macAddress
	}

	func attachment() throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZNATNetworkDeviceAttachment())
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

	func attachment() throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZBridgedNetworkDeviceAttachment(interface: interface))
	}
}

class VMNetworkInterface: NetworkAttachement, CatchRemoteCloseDelegate {
	let interface: VZBridgedNetworkInterface
	let macAddress: VZMACAddress
	let process = Process()
	var pipeChannel: Channel? = nil

	init(interface: VZBridgedNetworkInterface, macAddress: VZMACAddress) {
		self.interface = interface
		self.macAddress = macAddress
	}

	func attachment() throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZFileHandleNetworkDeviceAttachment(fileHandle: try self.open()))
	}

	func closedByRemote(port: Int, fd: Int32) {
		if self.pipeChannel != nil {
			self.pipeChannel = nil

			if port == 0 {
				Logger(self).info("VMNet closed by the host")
			} else {
				Logger(self).info("VMNet closed by the guest")
			}
		}
	}

	private func setSocketBuffers(fd: Int32, sizeBytes: Int) throws {
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

	private func open() throws -> FileHandle {
		let socketURL: (URL, URL)

		if runAsSystem {
			socketURL = try NetworksHandler.vmnetEndpoint(mode: .bridged, networkInterface: interface.identifier, asSystem: runAsSystem)
		} else {
			let systemSocketURL = try NetworksHandler.vmnetEndpoint(mode: .bridged, networkInterface: interface.identifier, asSystem: true)

			if try systemSocketURL.0.exists() == false {
				socketURL = try NetworksHandler.vmnetEndpoint(mode: .bridged, networkInterface: interface.identifier, asSystem: false)
			} else {
				socketURL = systemSocketURL
			}
		}

		if try socketURL.0.exists() == false {
			try NetworksHandler.run(mode: VMNetMode.bridged, networkInterface: interface.identifier, socketPath: socketURL.0, pidFile: socketURL.1)
		}

		let socketAddress = try SocketAddress(unixDomainSocketPath: socketURL.0.path)
		let (vmfd, hostfd) = try socketAddress.withSockAddr { _, len in
			let fds: UnsafeMutablePointer<Int32> = UnsafeMutablePointer<Int32>.allocate(capacity: MemoryLayout<Int>.stride * 2)
			let ret = socketpair(AF_UNIX, SOCK_DGRAM, 0, fds)

			if ret != 0 {
				throw ServiceError("unable to create socket with exit code \(ret)")
			}

			try setSocketBuffers(fd: fds[0], sizeBytes: 1024 * 1024)
			try setSocketBuffers(fd: fds[1], sizeBytes: 1024 * 1024)

			return (fds[0], fds[1])
		}

		let client = ClientBootstrap(group: Root.group)
			.channelInitializer { inboundChannel in
				// When the child channel is created, create a new pipe and add the handlers
				return NIOPipeBootstrap(group: inboundChannel.eventLoop)
					.takingOwnershipOfDescriptor(inputOutput: hostfd)
					.flatMap { childChannel in
						let (ours, theirs) = GlueHandler.matchedPair()

						return childChannel.pipeline.addHandlers([CatchRemoteClose(port: 1, fd: hostfd, delegate: self), ours])
							.flatMap {
								inboundChannel.pipeline.addHandlers([CatchRemoteClose(port: 0, fd: hostfd, delegate: self), theirs])
							}
					}
			}

		let futureChannel = client.connect(to: socketAddress)
		
		futureChannel.whenComplete { result in
			switch result {
			case .success:
				Logger(self).info("Connected to \(socketURL.0.path)")
			case .failure(let error):
				Logger(self).error("Failed to connect to \(socketURL.0.path), \(error)")
			}
		}

		self.pipeChannel = try futureChannel.wait()

		return FileHandle(fileDescriptor: vmfd, closeOnDealloc: true)
	}
}