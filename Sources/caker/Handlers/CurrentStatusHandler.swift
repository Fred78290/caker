//
//  CurrentStatusHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 20/02/2026.
//
import Foundation
import CakedLib
import GRPCLib
import GRPC
import NIO
import Combine
import SwiftUI

extension VMLocation.Status {
	init(_ from : Caked_VirtualMachineStatus) {
		switch from {
		case .stopped:
			self = .stopped
		case .running:
			self = .running
		case .paused:
			self = .paused
		default:
			self = .stopped
		}
	}
}

extension CurrentStatusHandler {
	public static func currentStatus(client: CakedServiceClient?, vmURL: URL, frequency: Int32, statusStream: AsyncThrowingStreamCurrentStatusReplyYield, runMode: Utils.RunMode) async throws -> Cancellable {
		guard let client, vmURL.isFileURL == false else {
			return try await Self.currentStatus(vmURL: vmURL, frequency: frequency, statusStream: statusStream, runMode: runMode)
		}

		return TaskCancellable {
			let (stream, continuation) = AsyncThrowingStream<Caked_Reply, Error>.makeStream()
			
			let flux = client.currentStatus(.with {
				$0.name = vmURL.vmName
				$0.frequency = frequency
			}, callOptions: CallOptions(timeLimit: .none)) {
				status in
				
				continuation.yield(status)
			}
			
			flux.status.whenFailure { error in
				continuation.finish(throwing: error)
			}
			
			for try await status in stream {
				status.status.statuses.forEach { status in
					switch status.message {
					case .status(let status):
						statusStream.yield(.status(.init(status)))
					case .screenshot(let png):
						statusStream.yield(.screenshot(png))
					case .usage(let usage):
						statusStream.yield(.usage(usage))
					case .failure(let reason):
						statusStream.yield(.error(ServiceError(reason)))
					default:
						break
					}
				}
			}
		}
	}
}
