//
//  PullHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import GRPCLib
import NIOCore
import CakedLib

struct PullHandler: CakedCommandAsync {
	var request: Caked_PullRequest
	
	func run(on: any EventLoop, runMode: Utils.RunMode) -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			let result = await CakedLib.PullHandler.pull(name: request.name, image: request.image, insecure: request.insecure, runMode: runMode, progressHandler: ProgressObserver.progressHandler)
			return Caked_Reply.with {
				$0.oci = .with {
					$0.pull = result.caked
				}
			}
		}
	}
	
	func replyError(error: any Error) -> Caked_Reply {
		Caked_Reply.with {
			$0.oci = .with {
				$0.pull = .with {
					$0.success = false
					$0.message = "\(error)"
				}
			}
		}
	}
}
