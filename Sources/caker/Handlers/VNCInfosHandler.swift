//
//  VNCInfosHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/02/2026.
//
import Foundation
import CakedLib
import GRPCLib

extension VNCInfosHandler {
	public static func vncInfos(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> VNCInfos {
		guard let client, vmURL.isFileURL == false else {
			return try self.vncInfos(vmURL: vmURL, runMode: runMode)
		}

		let vms = try client.vncInfos(.with {
			$0.name = vmURL.vmName
		}).response.wait().vms
		
		if case .vncURL(let value)? = vms.response {
			var screenSize: GRPCLib.ViewSize? = nil

			if value.hasScreenSize {
				screenSize = GRPCLib.ViewSize(width: Int(value.screenSize.width), height: Int(value.screenSize.height))
			}

			return VNCInfos(urls: value.urls, screenSize: screenSize)
		}

		return VNCInfos()
	}
}
