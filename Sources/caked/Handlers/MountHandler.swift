import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore
import CakedLib


struct MountHandler: CakedCommandAsync {
	var request: Caked_MountRequest

	mutating func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		let vmLocation = try StorageLocation(runMode: runMode).find(self.request.name)
		let directorySharingAttachment = self.request.directorySharingAttachment()
		let command = self.request.command

		return on.submit {
			let response: MountInfos

			if command == .mount {
				response = try CakedLib.MountHandler.Mount(vmLocation: vmLocation, mounts: directorySharingAttachment)
			} else {
				response = try CakedLib.MountHandler.Umount(vmLocation: vmLocation, mounts: directorySharingAttachment)
			}

			if case let .error(v) = response.response {
				throw ServiceError(v)
			}

			return Caked_Reply.with {
				$0.mounts = Caked_MountReply.with {
					$0.mounts = response.mounts.map {
						$0.toCaked_MountVirtioFSReply()
					}

					if case let .error(v) = response.response {
						$0.response = .error(v)
					} else {
						$0.response = .success(true)
					}
				}
			}
		}
	}
}
