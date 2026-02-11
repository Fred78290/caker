//
//  CurrentStatusHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/02/2026.
//
import Foundation
import GRPCLib
import GRPC
import CakeAgentLib
import NIO

typealias AsyncThrowingStreamCakeAgentCurrentUsageReply = (stream: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>, continuation: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.Continuation)

public struct CurrentStatusHandler {
	static func currentUsage(helper: CakeAgentHelper, _ continuation: AsyncThrowingStream<Caked_Reply, Error>.Continuation) async throws {
		let (stream, usage) = AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.makeStream()
		
		helper.currentUsage(frequency: 1, continuation: usage)
		
		try await withTaskCancellationHandler(operation: {
			for try await reply in stream {
				continuation.yield(.with {
					$0.status = .with {
						$0.usage = .with {
							$0.cpuCount = reply.cpuCount

							if reply.hasCpuInfos {
								$0.cpuInfos = reply.cpuInfos.caked
							}
							
							if reply.hasMemory {
								$0.memory = .with {
									let mem = reply.memory
									
									$0.total = mem.total
									$0.free = mem.free
									$0.used = mem.used
								}
							}
						}
					}
				})
			}
		}, onCancel: {
			usage.finish(throwing: CancellationError())
		})
	}

	public static func currentStatus(on: EventLoop, vmname: String, frequency: Int32, responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, client: CakeAgentConnection, runMode: Utils.RunMode) async throws {
		let location: VMLocation = try StorageLocation(runMode: runMode).find(vmname)
		var lastStatusSeen = location.status
		
		try await withThrowingTaskGroup(of: Void.self) { group in
			var group = group
			let (stream, continuation) = AsyncThrowingStream<Caked_Reply, Error>.makeStream()
			
			group.addTask { () -> Void in
				let sleep = 1000_000_000 / UInt64(frequency)
				
				while Task.isCancelled == false {
					continuation.yield(.with {
						$0.status = .with {
							switch location.status {
							case .running:
								$0.currentStatus = .running
							case .stopped:
								$0.currentStatus = .stopped
							default:
								$0.currentStatus = .UNRECOGNIZED(0)
							}
						}
					})
					
					if location.status == .running && lastStatusSeen == .stopped {
						group.addTask {
							try await currentUsage(helper: try CakeAgentHelper(on: on, client: client.createClient()), continuation)
						}
					}
					
					try? await Task.sleep(nanoseconds: sleep)
				}
			}

			for try await reply in stream {
				try await responseStream.send(reply)
			}
			
			group.cancelAll()
		}
	}
	
	public static func currentStatus(responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, vmname: String, frequency: Int32, client: CakeAgentConnection, runMode: Utils.RunMode) async throws {
		try await self.currentStatus(on: Utilities.group.next(), vmname: vmname, frequency: frequency, responseStream: responseStream, client: client, runMode: runMode)
	}
}

