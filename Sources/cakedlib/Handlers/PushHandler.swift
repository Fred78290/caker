//
//  PushHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import GRPCLib

public struct PushHandler {
	public static func push(localName: String, remoteNames: [String], insecure: Bool, chunkSize: Int, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> PushReply {
		PushReply(success: false, message: "Not implemented")
	}
}
