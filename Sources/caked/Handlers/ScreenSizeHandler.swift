//
//  ScreenSizeHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/02/2026.
//
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct ScreenSizeHandler {
	static func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.unexpected = "\(error)"
		}
	}

	struct GetScreenSizeHandler: CakedCommand {
		var request: Caked_GetScreenSizeRequest

		func replyError(error: any Error) -> Caked_Reply {
			ScreenSizeHandler.replyError(error: error)
		}

		func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
			return Caked_Reply.with {
				$0.screenSize = CakedLib.ScreenSizeHandler.getScreenSize(name: self.request.name, runMode: runMode).caked
			}
		}
	}

	struct SetScreenSizeHandler: CakedCommand {
		var request: Caked_SetScreenSizeRequest

		func replyError(error: any Error) -> Caked_Reply {
			ScreenSizeHandler.replyError(error: error)
		}

		func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
			return Caked_Reply.with {
				$0.screenSize = CakedLib.ScreenSizeHandler.setScreenSize(name: self.request.name, width: Int(self.request.screenSize.width), height: Int(self.request.screenSize.height), runMode: runMode).caked
			}
		}
	}
}
