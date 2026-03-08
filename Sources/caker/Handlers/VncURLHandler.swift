//
//  VncURLHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/02/2026.
//
import Foundation
import CakedLib
import GRPCLib

extension VncURLHandler {
	public static func vncURL(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> [URL] {
		guard let client else {
			return try self.vncURL(vmURL: vmURL, runMode: runMode)
		}
		
		if vmURL.isFileURL {
			return try self.vncURL(vmURL: vmURL, runMode: runMode)
		}

		guard let host = vmURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		let vms = try client.vncURL(.with {
			$0.name = host
		}).response.wait().vms
		
		if case .vncURL(let value)? = vms.response {
			return value.urls.compactMap {
				URL(string: $0)
			}
		}

		return []
	}
}
