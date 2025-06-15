import Foundation
import GRPCLib
import NIOCore
import CakedLib

struct RemoteHandler: CakedCommand {
	var request: Caked_RemoteRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let message: String

		switch request.command {
		case .list:
			let result = try CakedLib.RemoteHandler.listRemote(runMode: runMode)
			return Caked_Reply.with {
				$0.remotes = Caked_RemoteReply.with {
					$0.list = Caked_ListRemoteReply.with {
						$0.remotes = result.map {
							$0.toCaked_RemoteEntry()
						}
					}
				}
			}
		case .add:
			message = try CakedLib.RemoteHandler.addRemote(name: request.addRequest.name, url: URL(string: request.addRequest.url)!, runMode: runMode)
		case .delete:
			message = try CakedLib.RemoteHandler.deleteRemote(name: request.deleteRequest, runMode: runMode)
		default:
			throw ServiceError("Unknown command \(request.command)")
		}

		return Caked_Reply.with {
			$0.remotes = Caked_RemoteReply.with {
				$0.message = message
			}
		}
	}
}
