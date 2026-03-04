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
	public static func restart(client: CakedServiceClient?, rootURL: URL, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) throws -> RestartReply {
		guard let client else {
			return RestartReply(objects: [
				self.restart(rootURL: rootURL, force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
			], success: true, reason: "Succes")
		}

		if rootURL.isFileURL {
			return RestartReply(objects: [
				self.restart(rootURL: rootURL, force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
			], success: true, reason: "Succes")
		}

		guard let host = rootURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		return try RestartReply(client.restart(.with {
			$0.force = force
			$0.names = [host]
			$0.waitIptimeout = Int32(waitIPTimeout)
		}).response.wait().vms.restarted)
	}
}
