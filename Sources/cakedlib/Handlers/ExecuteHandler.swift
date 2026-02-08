//
//  ExecuteHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/04/2025.
//

import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import CakeAgentLib

public struct ExecuteHandler {
	public static func execute(on: EventLoop, runMode: Utils.RunMode, requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, vmname: String, client: CakeAgentConnection) async throws
	{
		var vmname = vmname

		if vmname == "" {
			vmname = "primary"

			if StorageLocation(runMode: runMode).exists(vmname) == false {
				Logger(self).info("Creating primary VM")
				let build = await BuildHandler.build(options: .init(name: vmname), runMode: runMode, progressHandler: ProgressObserver.progressHandler)

				if build.builded == false {
					throw ServiceError(build.reason)
				}
			}
		}

		let location: VMLocation = try StorageLocation(runMode: runMode).find(vmname)

		if location.status != .running {
			Logger(self).info("Starting \(vmname)")

			let started = CakedLib.StartHandler.startVM(on: Utilities.group.next(), location: location, config: try location.config(), waitIPTimeout: 180, startMode: .background, runMode: runMode)

			if started.started == false {
				throw ServiceError(started.reason)
			}
		}

		try await client.execute(requestStream: requestStream, responseStream: responseStream)
	}
}
