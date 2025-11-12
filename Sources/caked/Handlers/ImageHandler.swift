import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct ImageHandler: CakedCommandAsync {
	var request: Caked_ImageRequest

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with {
			$0.images = Caked_ImageReply.with {
				$0.failed = "\(error)"
			}
		}
	}
	
	func execute(command: Caked_ImageCommand, name: String, runMode: Utils.RunMode) async throws -> Caked_Reply {
		switch command {
		case .info:
			let result = try await CakedLib.ImageHandler.info(name: name, runMode: runMode)

			return Caked_Reply.with {
				$0.images = Caked_ImageReply.with {
					$0.infos = result.toCaked_ImageInfo()
				}
			}

		case .pull:
			let result = try await CakedLib.ImageHandler.pull(name: name, runMode: runMode)

			return Caked_Reply.with {
				$0.images = Caked_ImageReply.with {
					$0.pull = result.toCaked_PulledImageInfo()
				}
			}
		case .list:
			let result = try await CakedLib.ImageHandler.listImage(remote: name, runMode: runMode)

			return Caked_Reply.with {
				$0.images = Caked_ImageReply.with {
					$0.list = Caked_ListImagesInfoReply.with {
						$0.infos = result.map {
							$0.toCaked_ImageInfo()
						}
					}
				}
			}
		default:
			throw ServiceError("Unknown command \(command)")
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			try await self.execute(command: request.command, name: request.name, runMode: runMode)
		}
	}
}
