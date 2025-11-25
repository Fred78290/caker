import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct ImageHandler: CakedCommandAsync {
	var request: Caked_ImageRequest

	func replyError(error: any Error) -> Caked_Reply {
		let reply: Caked_ImageReply

		switch request.command {
		case .info:
			reply = Caked_ImageReply.with {
				$0.infos = .with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}

		case .pull:
			reply = Caked_ImageReply.with {
				$0.pull = .with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		case .list:
			reply = Caked_ImageReply.with {
				$0.list = .with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		default:
			fatalError("Unknown command \(request.command)")
		}

		return Caked_Reply.with {
			$0.images = reply
		}
	}

	func execute(command: Caked_ImageCommand, name: String, runMode: Utils.RunMode) async -> Caked_Reply {
		let reply: Caked_ImageReply

		switch command {
		case .info:
			let result = await CakedLib.ImageHandler.info(name: name, runMode: runMode)

			reply = Caked_ImageReply.with {
				$0.infos = result.caked
			}

		case .pull:
			let result = await CakedLib.ImageHandler.pull(name: name, runMode: runMode)

			reply = Caked_ImageReply.with {
				$0.pull = result.caked
			}
		case .list:
			let result = await CakedLib.ImageHandler.listImage(remote: name, runMode: runMode)

			reply = Caked_ImageReply.with {
				$0.list = result.caked
			}
		default:
			fatalError("Unknown command \(command)")
		}

		return Caked_Reply.with {
			$0.images = reply
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			await self.execute(command: request.command, name: request.name, runMode: runMode)
		}
	}
}
