import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore

struct MountHandler: CakedCommand {
	var request: Caked_MountRequest

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.mounts = Caked_MountReply.with {
				$0.success = false
				$0.reason = "\(error)"
			}
		}
	}

	mutating func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		do {
			let location = try StorageLocation(runMode: runMode).find(self.request.name)
			let directorySharingAttachment = self.request.directorySharingAttachment()
			let command = self.request.command
			let response: MountInfos

			if command == .mount {
				response = CakedLib.MountHandler.Mount(VMRunHandler.serviceMode, location: location, mounts: directorySharingAttachment, runMode: runMode)
			} else {
				response = CakedLib.MountHandler.Umount(VMRunHandler.serviceMode, location: location, mounts: directorySharingAttachment, runMode: runMode)
			}

			return Caked_Reply.with {
				$0.mounts = Caked_MountReply.with {
					$0.success = response.success
					$0.reason = response.reason
					$0.mounts = response.mounts.map {
						$0.caked
					}
				}
			}
		} catch {
			return Caked_Reply.with {
				$0.mounts = Caked_MountReply.with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		}
	}
}
