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
	public static func installAgent(client: CakedServiceClient?, rootURL: URL, timeout: UInt, runMode: Utils.RunMode) throws -> InstalledAgentReply {
		guard let client else {
			return self.installAgent(rootURL: rootURL, timeout: timeout, runMode: runMode)
		}

		if rootURL.isFileURL {
			return self.installAgent(rootURL: rootURL, timeout: timeout, runMode: runMode)
		}

		guard let host = rootURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		let reply = try client.installAgent(.with {
			$0.name = host
		}).response.wait().vms.installedAgent

		return InstalledAgentReply(reply)
	}
}
