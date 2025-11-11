import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct RemoteHandler: CakedCommand {
	var request: Caked_RemoteRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let reply: Caked_RemoteReply

		switch request.command {
		case .list:
			reply = try Caked_RemoteReply.with {
				$0.list = try Caked_ListRemoteReply.with {
					$0.remotes = try CakedLib.RemoteHandler.listRemote(runMode: runMode).map {
						$0.toCaked_RemoteEntry()
					}
				}
			}
		case .add:
			reply = Caked_RemoteReply.with {
				$0.created = CakedLib.RemoteHandler.addRemote(name: request.addRequest.name, url: URL(string: request.addRequest.url)!, runMode: runMode).caked
			}
		case .delete:
			reply = Caked_RemoteReply.with {
				$0.deleted = CakedLib.RemoteHandler.deleteRemote(name: request.deleteRequest, runMode: runMode).caked
			}
		default:
			throw ServiceError("Unknown command \(request.command)")
		}

		return Caked_Reply.with {
			$0.remotes = reply
		}
	}
}
