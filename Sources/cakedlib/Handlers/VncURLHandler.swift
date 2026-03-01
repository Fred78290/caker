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

public struct VncURLHandler {
	public static func vncURL(name: String, runMode: Utils.RunMode) throws -> [URL] {
		let location = try StorageLocation(runMode: runMode).find(name)

		if location.status == .running {
			return try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).vncURL
		}

		return []
	}
}
