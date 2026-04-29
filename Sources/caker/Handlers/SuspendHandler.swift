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
	public static func suspendVM(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> SuspendReply {
		guard let client, vmURL.isFileURL == false else {
			return try SuspendReply(
				objects: [
					suspendVM(vmURL: vmURL, runMode: runMode)
				], success: true, reason: "Success")
		}

		return SuspendReply(try client.suspend(.with {
			$0.names = [vmURL.vmName]
		}).response.wait().vms.suspend)
	}
}
