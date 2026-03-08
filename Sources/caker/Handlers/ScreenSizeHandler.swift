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
		guard let client else {
			return self.setScreenSize(vmURL: vmURL, width: width, height: height, runMode: runMode)
		}

		if vmURL.isFileURL {
			return self.setScreenSize(vmURL: vmURL, width: width, height: height, runMode: runMode)
		}

		guard let host = vmURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		return try ScreenSizeReply(client.setScreenSize(.with {
			$0.name = host
			$0.screenSize = .with {
				$0.width = Int32(width)
				$0.height = Int32(height)
			}
		}).response.wait().screenSize)
	}
	
	public static func getScreenSize(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> ScreenSizeReply {
		guard let client else {
			return self.getScreenSize(vmURL: vmURL, runMode: runMode)
		}
		
		if vmURL.isFileURL {
			return self.getScreenSize(vmURL: vmURL, runMode: runMode)
		}

		guard let host = vmURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		return try ScreenSizeReply(client.getScreenSize(.with {
			$0.name = host
		}).response.wait().screenSize)
	}
}
