import Foundation
import CakedLib
import GRPCLib

extension ListHandler {
	public static func list(client: CakedServiceClient?, vmonly: Bool, runMode: Utils.RunMode) throws -> VirtualMachineInfoReply {
		guard let client = client, runMode != .app else {
			return self.list(vmonly: vmonly, runMode: runMode)
		}

		return try VirtualMachineInfoReply(from: client.list(.with { $0.vmonly = vmonly }).response.wait().vms.list)
	}
}
