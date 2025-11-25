import CakedLib
//
//  PushHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import GRPCLib
import NIOCore

struct PushHandler: CakedCommandAsync {
	var request: Caked_PushRequest

	func run(on: any EventLoop, runMode: Utils.RunMode) -> NIOCore.EventLoopFuture<GRPCLib.Caked_Reply> {
		return on.makeFutureWithTask {
			let result = await CakedLib.PushHandler.push(
				localName: self.request.localName, remoteNames: self.request.remoteNames, insecure: self.request.insecure, chunkSizeInMB: Int(self.request.chunkSize), concurrency: UInt(self.request.concurrency), runMode: runMode,
				progressHandler: ProgressObserver.progressHandler)

			return Caked_Reply.with {
				$0.oci = .with {
					$0.push = result.caked
				}
			}
		}
	}

	func replyError(error: any Error) -> Caked_Reply {
		Caked_Reply.with {
			$0.oci = .with {
				$0.push = .with {
					$0.success = false
					$0.message = "\(error)"
				}
			}
		}
	}
}
