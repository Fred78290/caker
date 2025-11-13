import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore

struct MountHandler: CakedCommandAsync {
	var request: Caked_MountRequest

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with {
			$0.mounts = Caked_MountReply.with {
				$0.mounted = false
				$0.reason = "\(error)"
			}
		}
	}
	
	mutating func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		let location = try StorageLocation(runMode: runMode).find(self.request.name)
		let directorySharingAttachment = self.request.directorySharingAttachment()
		let command = self.request.command

		return on.submit {
			let response: MountInfos

			if command == .mount {
				response = CakedLib.MountHandler.Mount(VMRunHandler.serviceMode, location: location, mounts: directorySharingAttachment, runMode: runMode)
			} else {
				response = CakedLib.MountHandler.Umount(VMRunHandler.serviceMode, location: location, mounts: directorySharingAttachment, runMode: runMode)
			}

			return Caked_Reply.with {
				$0.mounts = Caked_MountReply.with {
					$0.mounted = response.success
					$0.reason = response.reason
					$0.mounts = response.mounts.map {
						$0.caked
					}
				}
			}
		}
	}
}
