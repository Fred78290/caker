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
	public static func restart(client: CakedServiceClient?, vmURL: URL, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) throws -> RestartReply {
		guard let client, vmURL.isFileURL == false else {
			return RestartReply(objects: [
				self.restart(vmURL: vmURL, startMode: .background, gcd: false, force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
			], success: true, reason: "Succes")
		}

		return try RestartReply(client.restart(.with {
			$0.force = force
			$0.names = [vmURL.vmName]
			$0.waitIptimeout = Int32(waitIPTimeout)
		}).response.wait().vms.restarted)
	}
}
