//
//  VncURLHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//
import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import Shout
import SystemConfiguration
import CakeAgentLib

public struct VNCInfosHandler {
	public static func vncInfos(vmURL: URL, runMode: Utils.RunMode) throws -> VNCInfos {
		return try vncInfos(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), runMode: runMode)
	}

	public static func vncInfos(name: String, runMode: Utils.RunMode) throws -> VNCInfos {
		return try vncInfos(location: StorageLocation(runMode: runMode).find(name), runMode: runMode)
	}

	public static func vncInfos(location: VMLocation, runMode: Utils.RunMode) throws -> VNCInfos {
		if case .running = location.status {
			return try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).vncInfos
		}

		return VNCInfos()
	}
}
