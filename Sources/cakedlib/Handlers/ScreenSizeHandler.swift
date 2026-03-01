//
//  ScreenSizeHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//
import Foundation
import GRPCLib
import NIO

public struct ScreenSizeHandler {
	public static func setScreenSize(name: String, width: Int, height: Int, runMode: Utils.RunMode) -> ScreenSizeReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)

			guard location.status == .running else {
				return ScreenSizeReply(width: 0, height: 0, success: false, reason: "VM is not running")
			}

			var client = try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode)

			client.screenSize = (width: width, height: height)
			
			return ScreenSizeReply(width: width, height: height, success: true, reason: "")
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: false, reason: "\(error)")
		}
	}
	
	public static func getScreenSize(name: String, runMode: Utils.RunMode) -> ScreenSizeReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)

			guard location.status == .running else {
				return ScreenSizeReply(width: 0, height: 0, success: false, reason: "VM is not running")
			}

			let size = try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).screenSize
			
			return ScreenSizeReply(width: size.0, height: size.1, success: true, reason: "")
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: false, reason: "\(error)")
		}
	}
}

