//
//  PullHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import GRPCLib

public struct PullHandler {
	public static func pull(location: VMLocation, image: String, insecure: Bool, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> PullReply {
		PullReply(success: false, message: "Not implemented")
	}

	public static func pull(name: String, image: String, insecure: Bool, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> PullReply {
		PullReply(success: false, message: "Not implemented")
	}
}
