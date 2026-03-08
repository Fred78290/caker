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
		guard let client = client else {
			return try SuspendReply(
				objects: [
					suspendVM(vmURL: vmURL, runMode: runMode)
				], success: true, reason: "Success")
		}

		if vmURL.isFileURL {
			return try SuspendReply(
				objects: [
					suspendVM(vmURL: vmURL, runMode: runMode)
				], success: true, reason: "Success")
		}

		guard let host = vmURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		return SuspendReply(try client.suspend(.with {
			$0.names = [host]
		}).response.wait().vms.suspend)
	}
}
