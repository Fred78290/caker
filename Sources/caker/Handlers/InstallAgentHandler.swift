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
		guard let client else {
			return self.installAgent(vmURL: vmURL, timeout: timeout, runMode: runMode)
		}

		if vmURL.isFileURL {
			return self.installAgent(vmURL: vmURL, timeout: timeout, runMode: runMode)
		}

		guard let host = vmURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		let reply = try client.installAgent(.with {
			$0.name = host
		}).response.wait().vms.installedAgent

		return InstalledAgentReply(reply)
	}
}
