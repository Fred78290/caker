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
	public static func setScreenSize(client: CakedServiceClient?, name: String, width: Int, height: Int, runMode: Utils.RunMode) throws -> ScreenSizeReply {
		guard let client = client, runMode != .app else {
			return self.setScreenSize(name: name, width: width, height: height, runMode: runMode)
		}

		return try ScreenSizeReply(from: client.setScreenSize(.with {
			$0.name = name
			$0.screenSize = .with {
				$0.width = Int32(width)
				$0.height = Int32(height)
			}
		}).response.wait().screenSize)
	}
	
	public static func getScreenSize(client: CakedServiceClient?, name: String, runMode: Utils.RunMode) throws -> ScreenSizeReply {
		guard let client = client, runMode != .app else {
			return self.getScreenSize(name: name, runMode: runMode)
		}
		
		return try ScreenSizeReply(from: client.getScreenSize(.with {
			$0.name = name
		}).response.wait().screenSize)
	}
}
