//
//  RestartHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//
import Foundation
import CakedLib
import GRPCLib

extension RestartHandler {
	public static func restart(client: CakedServiceClient?, name: String, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) throws -> RestartReply {

		guard let client = client, runMode != .app else {
			return self.restart(names: [name], force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
		}

		return try RestartReply(from: client.restart(.with {
			$0.force = force
			$0.names = [name]
			$0.waitIptimeout = Int32(waitIPTimeout)
		}).response.wait().vms.restarted)
	}
}
