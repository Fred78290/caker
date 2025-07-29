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

public struct ExecuteHandler {
	public static func execute(on: EventLoop, runMode: Utils.RunMode, requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, vmname: String, client: CakeAgentConnection) -> EventLoopFuture<
		Caked_Reply
	> {
		var vmname = vmname

		return on.makeFutureWithTask {
			if vmname == "" {
				vmname = "primary"

				if StorageLocation(runMode: runMode).exists(vmname) == false {
					Logger(self).info("Creating primary VM")
					try await BuildHandler.build(name: vmname, options: .init(name: vmname), runMode: runMode)
				}
			}

			let location: VMLocation = try StorageLocation(runMode: runMode).find(vmname)

			if location.status != .running {
				Logger(self).info("Starting \(vmname)")

				_ = try CakedLib.StartHandler.startVM(on: Utilities.group.next(), location: location, config: try location.config(), waitIPTimeout: 180, startMode: .background, runMode: runMode)
			}

			try await client.execute(requestStream: requestStream, responseStream: responseStream)

			return Caked_Reply()
		}
	}
}
