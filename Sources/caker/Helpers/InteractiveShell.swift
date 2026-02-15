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

enum ExecuteResponse: Equatable, Sendable {
	case exitCode(Int32)
	case stdout(Data)
	case stderr(Data)
	case failure(String)
	case established(Bool)
	
	public var exitCode: Int32 {
	  get {
		  if case .exitCode(let v) = self {
			  return v
		  }
		return 0
	  }
		set {
			self = .exitCode(newValue)
		}
	}

	public var stdout: Data {
	  get {
		  if case .stdout(let v) = self {
			  return v
		  }
		return Data()
	  }
		set {
			self = .stdout(newValue)
		}
	}

	public var stderr: Data {
	  get {
		  if case .stderr(let v) = self {
			  return v
		  }
		return Data()
	  }
		set {
			self = .stderr(newValue)
		}
	}

	public var failure: String {
	  get {
		  if case .failure(let v) = self {
			  return v
		  }
		return String()
	  }
	  set {self = .failure(newValue)}
	}

	public var established: Bool {
	  get {
		  if case .established(let v) = self {
			  return v
		  }
		return false
	  }
		set {
			self = .established(newValue)
		}
	}
}

enum ExecuteRequest: Sendable, Equatable {
	struct TerminalSize: Sendable, Equatable {
		var rows: Int32 = 0
		var cols: Int32 = 0
	}

	enum ExecuteCommand: Sendable, Equatable {
		struct Command: Sendable, Equatable {
			var command: String = String()
			var args: [String] = []
		}

		case command(ExecuteCommand.Command)
		case shell(Bool)
	}

	case command(ExecuteCommand)
	case input(Data)
	case size(TerminalSize)
	case eof(Bool)
}

typealias CakeAgentExecuteStream = BidirectionalStreamingCall<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>

typealias AsyncThrowingStreamCakeAgentExecuteResponse = (stream: AsyncThrowingStream<CakeAgent.ExecuteResponse, Error>, continuation: AsyncThrowingStream<CakeAgent.ExecuteResponse, Error>.Continuation)

class InteractiveShell {
	let name: String
	let rootURL: URL

	private var helper: CakeAgentHelper! = nil
	private var shellStream: CakeAgentExecuteStream! = nil
	private var stream: AsyncThrowingStreamCakeAgentExecuteResponse! = nil
	private var taskQueue: TaskQueue! = nil
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
			shellStream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
		}
	}
	
	func sendDatas(data: ArraySlice<UInt8>) {
		if let shellStream = self.shellStream {
			data.withUnsafeBytes { ptr in
				let message = CakeAgent.ExecuteRequest.with {
					$0.input = Data(bytes: ptr.baseAddress!, count: ptr.count)
				}
				
				try? shellStream.sendMessage(message).wait()
			}
		}
	}
	
	func closeShell(_line: UInt = #line, _file: String = #file,_ completionHandler: (@MainActor () -> Void)? = nil) {
		func closeClient() {
			if let taskQueue {
				self.taskQueue = nil
				taskQueue.close()
			}

			if let helper {
				self.helper = nil
				
				helper.close().whenComplete { _ in
					self.taskQueue = nil

					DispatchQueue.main.async {
						completionHandler?()
					}
				}
			}
		}
		
		guard let shellStream else {
			closeClient()
			return
		}
		
#if DEBUG
self.logger.debug("Close shell: \(self.name) \(_file):\(_line)")
#endif

		self.shellStream = nil
		
		shellStream.sendEof().whenComplete {_ in
			let promise = shellStream.eventLoop.makePromise(of: Void.self)
			
			promise.futureResult.whenComplete { _ in
				closeClient()
			}
			
			shellStream.cancel(promise: promise)
		}
	}

	private func startShell(rows: Int, cols: Int, helper: CakeAgentHelper) -> AsyncThrowingStreamCakeAgentExecuteResponse {
		return taskQueue.dispatchStream { (continuation: AsyncThrowingStream<CakeAgent.ExecuteResponse, Error>.Continuation) in
			do {
				_ = try helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(10))))

				self.logger.debug("Start shell, VM: \(self.name)")

				self.shellStream = helper.client.execute(callOptions: CallOptions(timeLimit: .none)) { response in
					continuation.yield(response)
				}
				
				self.shellStream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
				self.shellStream.sendShell()

				self.logger.debug("Shell started, VM: \(self.name)")
			} catch {
				continuation.finish(throwing: error)
			}
		}
	}

	func runShell(rows: Int, cols: Int, handler: @MainActor @escaping (CakeAgent.ExecuteResponse) -> Void) async {
		guard taskQueue == nil else {
			return
		}

		#if DEBUG
		let debugLogger = self.logger

		debugLogger.debug("Start shell, VM: \(self.name)")
		#endif

		self.taskQueue = .init(label: "CakeAgent.InteractiveShell.\(self.name)")

		await withTaskCancellationHandler(operation: {
			while Task.isCancelled == false && self.taskQueue != nil {
				var helper: CakeAgentHelper! = nil

				do {
					helper = try VirtualMachineDocument.createCakeAgentHelper(rootURL: self.rootURL)

					self.stream = self.startShell(rows: rows, cols: cols, helper: helper)
					self.helper = helper

					for try await response in stream!.stream {
						await handler(response)
					}
					break
				} catch {
					if self.taskQueue != nil {
						if let helper {
							self.helper = nil
							try? await helper.close().get()
						}

						self.stream = nil
						self.shellStream = nil

						guard self.handleAgentHealthCheckFailure(error: error) else {
							return
						}
						#if DEBUG
							debugLogger.debug("Shell not ready, VM: \(self.name), waiting...")
						#endif
						try? await Task.sleep(nanoseconds: 1_000_000_000)
					}
				}
			}

			self.closeShell {
#if DEBUG
				debugLogger.debug("Shell ended, VM: \(self.name)")
#endif
			}

			self.helper = nil
			self.stream = nil
			self.taskQueue = nil

		}, onCancel: {
			self.stream?.continuation.finish()
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

