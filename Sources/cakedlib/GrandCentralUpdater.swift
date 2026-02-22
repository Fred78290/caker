//
//  GrandCentralUpdater.swift
//  Caker
//
//  Created by Frederic BOLTZ on 21/02/2026.
//

import Foundation
import GRPC
import GRPCLib
import NIO

public struct GrandCentralUpdater {
	let location: VMLocation
	let runMode: Utils.RunMode
	let client: CakedServiceClient

	public init(location: VMLocation, runMode: Utils.RunMode) throws {
		self.location = location
		self.runMode = runMode
		self.client = try ServiceHandler.serviceClient(runMode: runMode)!
	}

	public func start(frequency: Int32) async throws {
		try await CurrentStatusHandler.currentStatus(location: self.location, frequency: frequency, statusStream: <#T##CurrentStatusHandler.AsyncThrowingStreamCurrentStatusReplyYield#>, runMode: self.runMode)
	}
}
