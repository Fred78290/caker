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

extension VMLocation.Status {
	init(from : Caked_VirtualMachineStatus) {
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
	public static func currentStatus(client: CakedServiceClient?, rootURL: URL, frequency: Int32, statusStream: AsyncThrowingStreamCurrentStatusReplyYield, runMode: Utils.RunMode) async throws {

		guard let client = client, runMode != .app else {
			return try await Self.currentStatus(rootURL: rootURL, frequency: frequency, statusStream: statusStream, runMode: runMode)
		}

		let (stream, continuation) = AsyncThrowingStream<Caked_Reply, Error>.makeStream()

		let flux = client.currentStatus(.with {
			$0.frequency = frequency
		}, callOptions: CallOptions(timeLimit: .none)) {
			status in
			
			continuation.yield(status)
		}

		flux.status.whenFailure { error in
			continuation.finish(throwing: error)
		}

		for try await status in stream {
			switch status.status.message {
			case .status(let status):
				statusStream.yield(.status(.init(from: status)))
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
