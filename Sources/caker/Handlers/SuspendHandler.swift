//
//  SuspendHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//
import Foundation
import CakedLib
import GRPCLib

extension SuspendHandler {
	public static func suspendVM(client: CakedServiceClient?, name: String, runMode: Utils.RunMode) throws -> SuspendReply {
		guard let client = client, runMode != .app else {
			return self.suspendVMs(names: [name], runMode: runMode)
		}

		return SuspendReply(from: try client.suspend(.with {
			$0.names = [name]
		}).response.wait().vms.suspend)
	}
}
