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
	public static func stopVM(client: CakedServiceClient?, name: String, force: Bool, runMode: Utils.RunMode) throws -> StopReply {

		guard let client = client, runMode != .app else {
			return self.stopVMs(all: false, names: [name], force: force, runMode: runMode)
		}

		return try StopReply(from: client.stop(.with {
			$0.force = force
			$0.names = .with {
				$0.list = [name]
			}
		}).response.wait().vms.stop)
	}
}
