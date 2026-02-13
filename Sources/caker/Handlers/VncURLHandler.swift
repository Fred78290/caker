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
	public static func vncURL(client: CakedServiceClient?, name: String, runMode: Utils.RunMode) throws -> URL? {
		guard let client = client, runMode != .app else {
			return try self.vncURL(name: name, runMode: runMode)
		}
		
		let vms = try client.vncURL(.with {
			$0.name = name
		}).response.wait().vms
		
		if case .vncURL(let v)? = vms.response {
			return URL(string: v)
		}

		return nil
	}
}
