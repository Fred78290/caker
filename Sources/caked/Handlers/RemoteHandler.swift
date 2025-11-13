import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct RemoteHandler: CakedCommand {
	var request: Caked_RemoteRequest

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		switch request.command {
		case .list:
			return Caked_Reply.with {
				$0.remotes = Caked_RemoteReply.with {
					$0.list = .with {
						$0.success = false
						$0.reason = "\(error)"
					}
				}
			}
		case .add:
			return Caked_Reply.with {
				$0.remotes = Caked_RemoteReply.with {
					$0.created = .with {
						$0.created = false
						$0.reason = "\(error)"
					}
				}
			}
		case .delete:
			return Caked_Reply.with {
				$0.remotes = Caked_RemoteReply.with {
					$0.deleted = .with {
						$0.deleted = false
						$0.reason = "\(error)"
					}
				}
			}
		default:
			fatalError("internal error")
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let reply: Caked_RemoteReply

		switch request.command {
		case .list:
			reply = Caked_RemoteReply.with {
				$0.list = CakedLib.RemoteHandler.listRemote(runMode: runMode).caked
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
