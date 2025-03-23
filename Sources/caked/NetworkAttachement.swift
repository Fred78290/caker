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

class VMNetworkInterface: NetworkAttachement {
	let interface: VZBridgedNetworkInterface
	let macAddress: VZMACAddress
	let process = Process()

	init(interface: VZBridgedNetworkInterface, macAddress: VZMACAddress) {
		self.interface = interface
		self.macAddress = macAddress
	}

	func attachment() throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZFileHandleNetworkDeviceAttachment(fileHandle: try self.open()))
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
		let socketURL = try NetworksHandler.vmnetEndpoint(mode: .bridged, networkInterface: interface.identifier)

		if try socketURL.0.exists() == false {
			try NetworksHandler.run(mode: VMNetMode.bridged, networkInterface: interface.identifier)
		}

		let socket_fd = try SocketAddress(unixDomainSocketPath: socketURL.0.path).withSockAddr { addr, len in
			let socket_fd = socket(AF_UNIX, SOCK_DGRAM, 0)

			if socket_fd < 0 {
				throw ServiceError("unable to create socket")
			}

			if connect(socket_fd, addr, UInt32(len)) < 0 {
				throw ServiceError("unable to connect to socket")
			}

			try setSocketBuffers(fd: socket_fd, sizeBytes: 1024 * 1024)

			return socket_fd
		}

		return FileHandle(fileDescriptor: socket_fd, closeOnDealloc: true)
	}
}