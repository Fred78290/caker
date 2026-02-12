//
//  VncURLHandler.swift
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

struct VncURLHandler: CakedCommand {
	var request: Caked_InfoRequest

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.unexpected = "\(error)"
		}
	}

	mutating func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		do {
			guard let url = try CakedLib.VncURLHandler.vncURL(name: request.name, runMode: runMode) else {
				return Caked_Reply.with {
					$0.vms = .with {
						$0.vncURL = ""
					}
				}
			}

			return Caked_Reply.with {
				$0.vms = .with {
					$0.vncURL = url.absoluteString
				}
			}
		} catch {
			return replyError(error: error)
		}
	}
}
