//
//  PingHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/02/2026.
//
import CakedLib
import CakeAgentLib
import Dispatch
import Foundation
import GRPCLib
import GRPC
import NIOCore

struct PingHandler: CakedCommand, Sendable {
	var request: Caked_PingRequest
	var client: CakeAgentConnection

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.ping = .with {
				$0.success = false
				$0.message = "\(error)"
				$0.requestTimestamp = self.request.timestamp
				$0.responseTimestamp = Int64(Date().timeIntervalSince1970 * 1_000_000_000)
				$0.status = .error
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		do {
			return try Caked_Reply.with {
				$0.ping = CakedLib.PingHandler.ping(name: self.request.name, message: self.request.message, timestamp: self.request.timestamp, runMode: runMode, client: CakeAgentHelper(on: on, client: try client.createClient()), callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
			}
		} catch {
			return replyError(error: error)
		}
	}
}
