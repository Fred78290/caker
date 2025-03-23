import Foundation
import Virtualization
import GRPCLib
import NIO

protocol NetworkAttachement {
	func attachment() -> (VZMACAddress, VZNetworkDeviceAttachment)
}

// MARK: - Network shared
class SharedNetworkInterface: NetworkAttachement {
	let macAddress: VZMACAddress

	init(macAddress: VZMACAddress) {
		self.macAddress = macAddress
	}

	func attachment() -> (VZMACAddress, VZNetworkDeviceAttachment) {
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

	func attachment() -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZBridgedNetworkDeviceAttachment(interface: interface))
	}
}

class VMNetworkInterface: NetworkAttachement {
	let interface: String
	let macAddress: VZMACAddress

	init(interface: String, macAddress: VZMACAddress) {
		self.interface = interface
		self.macAddress = macAddress
	}

	func attachment() -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZBridgedNetworkDeviceAttachment(interface: interface))
	}

	func open() throws -> FileHandle{
		let socketURL = try NetworksHandler.vmnetEndpoint(mode: .bridged, networkInterface: interface)
		let socketPath = socketURL.0.path

		if try socketURL.0.exists() == false {
			try NetworksHandler.run()
		}

		let addr = try SocketAddress(unixDomainSocketPath: socketURL.0.path)

		let socket = try VZFileHandle(forReadingFrom: socketPath)
	}
}