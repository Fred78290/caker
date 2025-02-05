import Foundation
import Virtualization

protocol NetworkAttachement {
	func attachment() -> VZNetworkDeviceAttachment
}

// MARK: - Network shared
class SharedNetworkInterface: NetworkAttachement {
	func attachment() -> VZNetworkDeviceAttachment {
		return VZNATNetworkDeviceAttachment()
	}
}

// MARK: - Network bridged
class BridgedNetworkInterface: NetworkAttachement {
	let interface: VZBridgedNetworkInterface

	init(interface: VZBridgedNetworkInterface) {
		self.interface = interface
	}

	func attachment() -> VZNetworkDeviceAttachment {
		return VZBridgedNetworkDeviceAttachment(interface: interface)
	}
}