//
//  InteractiveShell.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/01/2026.
//
import Foundation
import CakedLib
import CakeAgentLib
import GRPC
import GRPCLib

typealias AsyncThrowingStreamCakeAgentExecuteResponse = (stream: AsyncThrowingStream<CakeAgent.ExecuteResponse, Error>, continuation: AsyncThrowingStream<CakeAgent.ExecuteResponse, Error>.Continuation)

class InteractiveShell {
	let name: String
	let rootURL: URL

	private var shellStream: ShellHandler.ShellHandlerProtocol! = nil

#if DEBUG
	private let logger = Logger("InteractiveShell")
#endif

	deinit {
		self.closeShell()
	}

	init(rootURL: URL) {
		self.rootURL = rootURL
		self.name = rootURL.lastPathComponent.deletingPathExtension
	}
	
	func sendTerminalSize(rows: Int, cols: Int) {
		if let shellStream = self.shellStream {
			shellStream.sendTerminalSize(rows: rows, cols: cols)
		}
	}
	
	func sendDatas(data: ArraySlice<UInt8>) {
		if let shellStream = self.shellStream {
			shellStream.sendDatas(data: data)
		}
	}
	
	func closeShell(_line: UInt = #line, _file: String = #file,_ completionHandler: (@MainActor () -> Void)? = nil) {
		guard let shellStream else {
			return
		}
		
#if DEBUG
		self.logger.debug("Close shell: \(self.name) \(_file):\(_line)")
#endif

		self.shellStream = nil
		
		shellStream.closeShell {
			
		}
	}

	func runShell(rows: Int, cols: Int, handler: @MainActor @escaping (ShellHandler.ExecuteResponse) -> Void) async {
		await withTaskCancellationHandler(operation: {
			do {
				self.shellStream = try ShellHandler.shell(name: self.name, terminalSize: ShellHandler.TerminalSize(rows: Int32(rows), cols: Int32(cols)), connectionTimeout: 5, runMode: AppState.shared.runMode)
				
				try await self.shellStream.handleResponse { message in
					await handler(message)
				}
			} catch {
				guard self.handleAgentHealthCheckFailure(error: error) else {
					return
				}

				self.logger.debug("Shell not ready, VM: \(self.name), waiting...")

				try? await Task.sleep(nanoseconds: 1_000_000_000)
			}

			self.shellStream?.closeShell {
				self.logger.debug("Shell ended, VM: \(self.name)")
			}
		}, onCancel: {
			self.shellStream?.finish()
		})
	}
	
	private func handleAgentHealthCheckFailure(error: Error) -> Bool {
#if DEBUG
		self.logger.debug("VM \(self.name) shell is not ready \(error)")
#endif

		func handleGrpcStatus(_ grpcError: GRPCStatus) {
			switch grpcError.code {
			case .unavailable:
				// These could be temporary - continue monitoring
				self.logger.info("VM \(self.name) agent unvailable")
				break
			case .cancelled:
				// These could be temporary - continue monitoring
				self.logger.info("VM \(self.name) agent cancelled")
				break
			case .deadlineExceeded:
				// Timeout - VM might be under heavy load
				self.logger.info("VM \(self.name) agent timeout")
			case .unimplemented:
				// unimplemented - Agent is too old, need update
				self.logger.info("Agent monitoring: VM \(self.name) agent is too old, need update")
			default:
				// Other errors might indicate serious issues
				self.logger.error("VM \(self.name) agent error: \(grpcError)")
			}
		}

		if let grpcError = error as? any GRPCStatusTransformable {
			handleGrpcStatus(grpcError.makeGRPCStatus())
		} else if let grpcError = error as? GRPCStatus {
			handleGrpcStatus(grpcError)
		} else {
			// Agent is not responding - could indicate VM issues
			self.logger.error("VM \(self.name) agent not responding: \(error)")  // Check if it's a permanent failure (connection refused, etc.)
			return false
		}
		
		return true
	}
}

