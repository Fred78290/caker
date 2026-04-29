//
//  InstallAgentHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 04/03/2026.
//

import Foundation
import CakedLib
import GRPCLib

extension InstallAgentHandler {
	public static func installAgent(client: CakedServiceClient?, vmURL: URL, timeout: UInt, runMode: Utils.RunMode) throws -> InstalledAgentReply {
		guard let client, vmURL.isFileURL == false else {
			return self.installAgent(vmURL: vmURL, timeout: timeout, runMode: runMode)
		}

		let reply = try client.installAgent(.with {
			$0.name = vmURL.vmName
		}).response.wait().vms.installedAgent

		return InstalledAgentReply(reply)
	}
}
