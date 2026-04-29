//
//  StopHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//
import Foundation
import CakedLib
import GRPCLib

extension StopHandler {
	public static func stopVM(client: CakedServiceClient?, vmURL: URL, force: Bool, runMode: Utils.RunMode) throws -> StopReply {
		guard let client, vmURL.isFileURL == false else {
			return StopReply(objects: [
				self.stopVM(vmURL: vmURL, force: force, runMode: runMode)
			], success: true, reason: "Success")
		}

		return try StopReply(client.stop(.with {
			$0.force = force
			$0.names = .with {
				$0.list = [vmURL.vmName]
			}
		}).response.wait().vms.stop)
	}
}
