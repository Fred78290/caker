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

			try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).setScreenSize(width: width, height: height)
			
			return ScreenSizeReply(width: width, height: height, success: true, reason: nil)
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: true, reason: "\(error)")
		}
	}
	
	public static func getScreenSize(name: String, runMode: Utils.RunMode) -> ScreenSizeReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)

			guard location.status == .running else {
				return ScreenSizeReply(width: 0, height: 0, success: false, reason: "VM is not running")
			}

			let size = try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).getScreenSize()
			
			return ScreenSizeReply(width: size.0, height: size.0, success: true, reason: nil)
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: true, reason: "\(error)")
		}
	}
}
