import Foundation
import CakedLib
import GRPCLib

extension RenameHandler {
	public static func rename(client: CakedServiceClient?, vmURL: URL, newname: String, runMode: Utils.RunMode) throws -> RenameReply {
		guard let client, vmURL.isFileURL == false else {
			return self.rename(vmURL: vmURL, newname: newname, runMode: runMode)
		}

		return try RenameReply(client.rename(.with {
			$0.oldname = vmURL.vmName
			$0.newname = newname
		}).response.wait().vms.renamed)
	}
}
