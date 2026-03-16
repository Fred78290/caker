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
import SwiftUI

@MainActor
class InteractiveShell {
	let name: String
	let vmURL: URL
	var terminalView: VirtualMachineTerminalView! = nil

	private var shellStream: (any ShellHandler.ShellHandlerProtocol)! = nil
	private var cancelled = false
	private let logger = Logger("InteractiveShell")
	private var task: Task<Void, Error>?

	deinit {
		MainActor.assumeIsolated {
			self.closeShell()
		}
	}

	init(_ vmURL: URL) {
		self.vmURL = vmURL
		self.name = vmURL.lastPathComponent.deletingPathExtension
	}

	func buildTerminalView(frame: CGRect) -> VirtualMachineTerminalView {
		guard let terminalView else {
			let terminalView = VirtualMachineTerminalView(interactiveShell: self, frame: frame, font: Defaults.currentTerminalFont(), color: Defaults.currentTerminalFontColor())
			self.terminalView = terminalView
			
			return terminalView
		}

		terminalView.bounds = CGRect(origin: .zero, size: frame.size)

		return terminalView
	}

	func sendTerminalSize(rows: Int, cols: Int) {
		if let shellStream = self.shellStream {
			self.logger.debug("Terminal size: \(rows)x\(cols) for VM: \(self.name)")

			shellStream.sendTerminalSize(rows: rows, cols: cols)
		} else {
			self.logger.debug("Terminal size no shell: \(rows)x\(cols) for VM: \(self.name)")
		}
	}
	
	func sendDatas(data: ArraySlice<UInt8>) {
		if let shellStream = self.shellStream {
			shellStream.sendDatas(data: data)
		}
	}
	
	private func cancelledShell() {
		if let shellStream {
			shellStream.finish()
		}

		self.task = nil
	}

	func cancelShell() {
		guard let task else {
			return
		}

		self.logger.debug("Cancel shell for VM: \(self.name)")
		self.cancelled = true

		task.cancel()
	}

	func closeShell(_line: UInt = #line, _file: String = #file,_ completionHandler: (@MainActor () -> Void)? = nil) {
		defer {
			// Even if there is no active shell stream, honor the completion handler contract.
			if let completionHandler {
				Task { @MainActor in
					completionHandler()
				}
			}
		}

		guard let shellStream else {
			return
		}
		
#if DEBUG
		self.logger.debug("Close shell: \(self.name) \(_file):\(_line)")
#endif

		self.shellStream = nil

		shellStream.closeShell(promise: nil)
	}

	func startShell(rows: Int, cols: Int, handler: @MainActor @escaping (ShellHandler.ExecuteResponse) -> Void) {
		guard self.task == nil else {
			return
		}

		// Reset cancellation state when starting a new shell session
		self.cancelled = false
		
		self.task = Task { [weak self] in
			guard let self else { return }

			await self.runShell(rows: rows, cols: cols, handler: handler)
			self.logger.debug("Shell exited for \(self.name)")
		}
	}

	private func runShell(rows: Int, cols: Int, handler: @MainActor @escaping (ShellHandler.ExecuteResponse) -> Void) async {
		guard self.shellStream == nil else {
			return
		}

		await withTaskCancellationHandler(operation: {
			defer {
				self.closeShell {
					self.logger.debug("Shell ended, VM: \(self.name)")
				}
			}

			while Task.isCancelled == false && self.cancelled == false {
				do {
					let shellStream = try ShellHandler.shell(vmURL: self.vmURL,
															 terminalSize: ShellHandler.TerminalSize(rows: Int32(rows), cols: Int32(cols)),
															 connectionTimeout: 5,
															 runMode: AppState.shared.runMode)
					self.shellStream = shellStream

					for try await message in shellStream {
						await handler(message)
					}
					self.logger.debug("Shell stream closed, VM: \(self.name)")
				} catch {
					guard self.handleAgentHealthCheckFailure(error: error) else {
						return
					}

					self.closeShell()

					self.logger.debug("Shell not ready, VM: \(self.name), waiting...")

					try? await Task.sleep(nanoseconds: 1_000_000_000)
				}
			}

			self.logger.debug("Leave shell run loop, VM: \(self.name)")
			self.task = nil
		}, onCancel: {
			self.logger.debug("Shell cancelled, VM: \(self.name)")

			self.cancelledShell()
		})
	}
	
	private func handleAgentHealthCheckFailure(error: Error) -> Bool {
		self.logger.debug("VM \(self.name) shell is not ready \(error)")

		func handleGrpcStatus(_ grpcError: GRPCStatus) {
			switch grpcError.code {
			case .unavailable:
				// These could be temporary - continue monitoring
				self.logger.debug("VM \(self.name) agent unvailable")
				break
			case .cancelled:
				// These could be temporary - continue monitoring
				self.logger.debug("VM \(self.name) agent cancelled")
				break
			case .deadlineExceeded:
				// Timeout - VM might be under heavy load
				self.logger.debug("VM \(self.name) agent timeout")
			case .unimplemented:
				// unimplemented - Agent is too old, need update
				self.logger.warn("Agent monitoring: VM \(self.name) agent is too old, need update")
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

