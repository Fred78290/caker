//
//  ShellHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 15/02/2026.
//
import Foundation
import CakeAgentLib
import GRPCLib
import GRPC

typealias AsyncThrowingStreamShellResponse = (stream: AsyncThrowingStream<ShellHandler.ExecuteResponse, Error>, continuation: AsyncThrowingStream<ShellHandler.ExecuteResponse, Error>.Continuation)

public struct ShellHandler {
	public protocol ShellHandlerProtocol {
		func sendTerminalSize(rows: Int, cols: Int)
		func sendDatas(data: ArraySlice<UInt8>)
		func handleResponse(_ handler: @MainActor @escaping (ExecuteResponse) -> Void) async throws
		func closeShell(_ completionHandler: (@MainActor () -> Void)?)
	}

	public enum ExecuteResponse: Equatable, Sendable {
		case exitCode(Int32)
		case stdout(Data)
		case stderr(Data)
		case failure(String)
		case established(Bool)
		
		public init(_ from: CakeAgent.ExecuteResponse) {
			switch from.response {
			case .exitCode(let v):
				self = .exitCode(v)
			case .stdout(let v):
				self = .stdout(v)
			case .stderr(let v):
				self = .stderr(v)
			case .established(let v):
				self = .init(from)
			case .none:
				self = .failure("Unknown response from the shell")
			}
		}
		
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
	
	public struct TerminalSize: Sendable, Equatable {
		public var rows: Int32 = 0
		public var cols: Int32 = 0
	}
	
	public enum ExecuteRequest: Sendable, Equatable {
		public enum ExecuteCommand: Sendable, Equatable {
			public struct Command: Sendable, Equatable {
				public var command: String = String()
				public var args: [String] = []
			}
			
			case command(ExecuteCommand.Command)
			case shell(Bool)
		}
		
		case command(ExecuteCommand)
		case input(Data)
		case size(TerminalSize)
		case eof(Bool)
	}

	public static func shell(name: String, terminalSize: TerminalSize, connectionTimeout: Int64 = 1, runMode: Utils.RunMode) throws -> ShellHandlerProtocol {
		if runMode == .app {
			return try ShellCakeAgent(name: name).shell(terminalSize: terminalSize, connectionTimeout: connectionTimeout)
		}
	}

	internal class ShellCaked: ShellHandlerProtocol {
		func sendTerminalSize(rows: Int, cols: Int) {
			<#code#>
		}
		
		func sendDatas(data: ArraySlice<UInt8>) {
			<#code#>
		}
		
		func handleResponse(_ handler: @escaping @MainActor (ShellHandler.ExecuteResponse) -> Void) async throws {
			<#code#>
		}
		
		func closeShell(_ completionHandler: (@MainActor () -> Void)?) {
			<#code#>
		}
		
	}

	internal class ShellCakeAgent: ShellHandlerProtocol {
		private let name: String
		private let runMode: Utils.RunMode = .app
		private let logger = Logger("ShellHandler")
		private var helper: CakeAgentHelper! = nil
		private var shellStream: CakeAgentExecuteStream! = nil
		private var stream: AsyncThrowingStreamShellResponse! = nil
		private var taskQueue: TaskQueue! = nil

		init(name: String) {
			self.name = name
		}

		func createCakeAgentHelper(name: String, connectionTimeout: Int64 = 1) throws -> CakeAgentHelper {
			// Create a short-lived client for the health check
			let eventLoop = Utilities.group.next()
			let client = try Utilities.createCakeAgentClient(
				on: eventLoop.next(),
				runMode: runMode,
				name: name,
				connectionTimeout: connectionTimeout,
				retries: .upTo(1)
			)
			
			return CakeAgentHelper(on: eventLoop, client: client)
		}
		
		public func shell(terminalSize: TerminalSize, connectionTimeout: Int64) throws -> ShellHandlerProtocol {
			let cakeHelper = try self.createCakeAgentHelper(name: name, connectionTimeout: connectionTimeout)
			
			guard taskQueue == nil else {
				return self
			}
			
			self.logger.debug("Start shell, VM: \(self.name)")
			
			self.stream = self.startShell(rows: terminalSize.rows, cols: terminalSize.cols, helper: cakeHelper)
			self.helper = cakeHelper

			return self
		}
		
		public func sendTerminalSize(rows: Int, cols: Int) {
			if let shellStream = self.shellStream {
				shellStream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
			}
		}
		
		public func sendDatas(data: ArraySlice<UInt8>) {
			if let shellStream = self.shellStream {
				data.withUnsafeBytes { ptr in
					let message = CakeAgent.ExecuteRequest.with {
						$0.input = Data(bytes: ptr.baseAddress!, count: ptr.count)
					}
					
					try? shellStream.sendMessage(message).wait()
				}
			}
		}
		
		public func handleResponse(_ handler: @MainActor @escaping (ExecuteResponse) -> Void) async throws {
			for try await response in self.stream.stream {
				await handler(response)
			}
		}
		
		public func closeShell(_ completionHandler: (@MainActor () -> Void)? = nil) {
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
			
			self.logger.debug("Close shell: \(self.name)")
			
			self.shellStream = nil
			
			shellStream.sendEof().whenComplete {_ in
				let promise = shellStream.eventLoop.makePromise(of: Void.self)
				
				promise.futureResult.whenComplete { _ in
					closeClient()
				}
				
				shellStream.cancel(promise: promise)
			}
		}
		
		private func startShell(rows: Int32, cols: Int32, helper: CakeAgentHelper) -> AsyncThrowingStreamShellResponse {
			self.taskQueue = .init(label: "CakeAgent.InteractiveShell.\(self.name)")
			
			return taskQueue.dispatchStream { (continuation: AsyncThrowingStream<ExecuteResponse, Error>.Continuation) in
				do {
					_ = try helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(10))))
					
					self.logger.debug("Start shell, VM: \(self.name)")
					
					self.shellStream = helper.client.execute(callOptions: CallOptions(timeLimit: .none)) { response in
						continuation.yield(ExecuteResponse(response))
					}
					
					self.shellStream.sendTerminalSize(rows: rows, cols: cols)
					self.shellStream.sendShell()
					
					self.logger.debug("Shell started, VM: \(self.name)")
				} catch {
					continuation.finish(throwing: error)
				}
			}
		}
	}
}
