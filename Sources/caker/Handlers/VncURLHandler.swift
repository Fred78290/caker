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
	public static func vncURL(client: CakedServiceClient?, rootURL: URL, runMode: Utils.RunMode) throws -> [URL] {
		guard let client else {
			return try self.vncURL(rootURL: rootURL, runMode: runMode)
		}
		
		if rootURL.isFileURL {
			return try self.vncURL(rootURL: rootURL, runMode: runMode)
		}

		guard let host = rootURL.host(percentEncoded: false) else {
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
