import Foundation
import GRPCLib
import NIOCore
import Virtualization

struct DuplicateHandler: CakedCommand {
	var request: Caked_DuplicateRequest

	static func duplicate(from: String, to: String, resetMacAddress: Bool, runMode: Utils.RunMode) throws -> String {
		let storageLocation = StorageLocation(runMode: runMode)
		let fromLocation = try storageLocation.find(from)

		// Check if the VM exists
		if fromLocation.status == .running {
			throw ServiceError("VM \(from) is running")
		}

		if storageLocation.exists(to) {
			throw ServiceError("VM \(to) already exists")
		}

		let tmpLocation = try fromLocation.duplicateTemporary(runMode: runMode)
		let config = try tmpLocation.config()

		// Change mac address and network mode
		if resetMacAddress {
			config.macAddress = VZMACAddress.randomLocallyAdministered()
			config.networks = config.networks.map {
				BridgeAttachement(network: $0.network, mode: $0.mode, macAddress: VZMACAddress.randomLocallyAdministered().string)
			}

			try config.save()
		}

		try storageLocation.relocate(to, from: tmpLocation)

		return "VM duplicated from (\(from)) to (\(to))"
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		return try Caked_Reply.with {
			$0.vms = try Caked_VirtualMachineReply.with {
				$0.message = try Self.duplicate(from: self.request.from, to: self.request.to, resetMacAddress: self.request.resetMacAddress, runMode: runMode)
			}
		}
	}
}
