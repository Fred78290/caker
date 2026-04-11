//
//  VNCInfosHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//

import CakedLib
import Dispatch
import Foundation
import GRPC
import GRPCLib
import NIOCore

struct VNCInfosHandler: CakedCommand {
	var request: Caked_InfoRequest

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.unexpected = error.reason
		}
	}

	mutating func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		do {
			let vncInfos = try CakedLib.VNCInfosHandler.vncInfos(name: request.name, runMode: runMode)

			return Caked_Reply.with {
				$0.vms = .with {
					$0.vncURL = .with {
						$0.urls = vncInfos.urls
						if let screenSize = vncInfos.screenSize {
							$0.screenSize = .with {
								$0.width = Int32(screenSize.width)
								$0.height = Int32(screenSize.height)
							}
						}
					}
				}
			}
		} catch {
			return replyError(error: error)
		}
	}
}
