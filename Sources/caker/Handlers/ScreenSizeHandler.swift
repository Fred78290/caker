//
//  ScreenSizeHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/02/2026.
//
import Foundation
import CakedLib
import GRPCLib

extension ScreenSizeHandler {
	public static func setScreenSize(client: CakedServiceClient?, vmURL: URL, width: Int, height: Int, runMode: Utils.RunMode) throws -> ScreenSizeReply {
		guard let client, vmURL.isFileURL == false else {
			return self.setScreenSize(vmURL: vmURL, width: width, height: height, runMode: runMode)
		}

		return try ScreenSizeReply(client.setScreenSize(.with {
			$0.name = vmURL.vmName
			$0.screenSize = .with {
				$0.width = Int32(width)
				$0.height = Int32(height)
			}
		}).response.wait().screenSize)
	}
	
	public static func getScreenSize(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> ScreenSizeReply {
		guard let client, vmURL.isFileURL == false else {
			return self.getScreenSize(vmURL: vmURL, runMode: runMode)
		}

		return try ScreenSizeReply(client.getScreenSize(.with {
			$0.name = vmURL.vmName
		}).response.wait().screenSize)
	}
}
