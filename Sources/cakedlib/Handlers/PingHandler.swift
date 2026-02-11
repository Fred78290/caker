//
//  PingHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/02/2026.
//
import Foundation
import CakeAgentLib
import GRPC
import GRPCLib
import NIO

public struct PingHandler {
	public static func ping(name: String, message: String, timestamp: Int64, runMode: Utils.RunMode, client: CakeAgentHelper, callOptions: CallOptions?) -> Caked_PingReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)

			if location.status == .running {
				let result = try client.ping(message: message, timestamp: timestamp)

				return Caked_PingReply.with {
					$0.success = true
					$0.message = result.message
					$0.requestTimestamp = result.requestTimestamp
					$0.responseTimestamp = result.responseTimestamp
					$0.currentStatus = .running
				}
			} else {
				return Caked_PingReply.with {
					$0.success = false
					$0.message = "VM is not running."
					$0.requestTimestamp = Int64(timestamp * 1_000_000_000)
					$0.responseTimestamp = Int64(Date().timeIntervalSince1970 * 1_000_000_000)
					
					switch location.status {
					case .stopped:
						$0.currentStatus = .stopped
					case .paused:
						$0.currentStatus = .paused
					case .running:
						$0.currentStatus = .running
					}
				}
			}
		} catch {
			return Caked_PingReply.with {
				$0.success = false
				$0.message = "\(error)"
				$0.requestTimestamp = Int64(timestamp * 1_000_000_000)
				$0.responseTimestamp = Int64(Date().timeIntervalSince1970 * 1_000_000_000)
				$0.currentStatus = .error
			}
		}
	}
}
