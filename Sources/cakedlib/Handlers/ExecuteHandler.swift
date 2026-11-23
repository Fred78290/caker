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
import SwiftUI

public struct ExecuteHandler {	
	public static func execute(on: EventLoop, runMode: Utils.RunMode, requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, vmname: String, shellUser: String?, client: CakeAgentConnection) async throws {
		var vmname = vmname

		if vmname == String.empty {
			vmname = GetOptions.primaryName

			if StorageLocation(runMode: runMode).exists(vmname) == false {
				Logger(self).info("Creating primary VM")
				let build = await BuildHandler.build(options: .init(name: vmname, diskFormat: .raw), runMode: runMode, progressHandler: ProgressObserver.progressHandler)

				if build.builded == false {
					throw ServiceError(build.reason)
				}
			}
		}

		let location: VMLocation = try StorageLocation(runMode: runMode).find(vmname)
		// A configuration that can't be read is an error: an empty user would run the command as the agent's own (root).
		let shellUser = try shellUser ?? location.config().configuredUser

		if case .stopped = location.status {
			Logger(self).info("Starting \(vmname)")

			// The daemon shows the windows through its SeamlessTunnel: a VM started here must not listen for them itself.

			let started = CakedLib.StartHandler.startVM(on: Utilities.group.next(), location: location, screenSize: nil, vncPassword: nil, vncPort: 0, waitIPTimeout: 180, startMode: .service, gcd: false, recoveryMode: false, runMode: runMode)

			if started.started == false {
				throw ServiceError(started.reason)
			}
		}

		try await client.execute(requestStream: requestStream, responseStream: responseStream, user: shellUser)
	}
}
