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
			return try setScreenSize(location: StorageLocation(runMode: runMode).find(name), width: width, height: height, runMode: runMode)
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: false, reason: error.reason)
		}
	}

	public static func setScreenSize(vmURL: URL, width: Int, height: Int, runMode: Utils.RunMode) -> ScreenSizeReply {
		do {
			return try setScreenSize(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), width: width, height: height, runMode: runMode)
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: false, reason: error.reason)
		}
	}

	public static func setScreenSize(location: VMLocation, width: Int, height: Int, runMode: Utils.RunMode) -> ScreenSizeReply {
		do {
			guard case .running = location.status else {
				return ScreenSizeReply(width: 0, height: 0, success: false, reason: String(localized: "VM is not running"))
			}

			var client = try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode)

			client.screenSize = (width: width, height: height)
			
			return ScreenSizeReply(width: width, height: height, success: true, reason: String.empty)
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: false, reason: error.reason)
		}
	}

	public static func getScreenSize(name: String, runMode: Utils.RunMode) -> ScreenSizeReply {
		do {
			return try getScreenSize(location: StorageLocation(runMode: runMode).find(name), runMode: runMode)
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: false, reason: error.reason)
		}
	}

	public static func getScreenSize(vmURL: URL, runMode: Utils.RunMode) -> ScreenSizeReply {
		do {
			return try getScreenSize(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), runMode: runMode)
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: false, reason: error.reason)
		}
	}

	public static func getScreenSize(location: VMLocation, runMode: Utils.RunMode) -> ScreenSizeReply {
		do {
			guard case .running = location.status else {
				return ScreenSizeReply(width: 0, height: 0, success: false, reason: String(localized: "VM is not running"))
			}

			let size = try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).screenSize
			
			return ScreenSizeReply(width: size.0, height: size.1, success: true, reason: String.empty)
		} catch {
			return ScreenSizeReply(width: 0, height: 0, success: false, reason: error.reason)
		}
	}
}

