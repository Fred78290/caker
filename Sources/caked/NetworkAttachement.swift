import Foundation
import Virtualization

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