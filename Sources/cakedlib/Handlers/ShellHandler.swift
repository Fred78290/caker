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
		func sendEof()
		func handleResponse(_ handler: @escaping (ExecuteResponse) async -> Void) async throws
		func closeShell(_ completionHandler: (@MainActor () -> Void)?)
		func finish()
	}

	public enum ExecuteResponse: Equatable, Sendable {
		case exitCode(Int32)
		case stdout(Data)
		case stderr(Data)
		case failure(String)
		case established(Bool, String)
		
		public init(_ from: CakeAgent.ExecuteResponse) {
			switch from.response {
			case .exitCode(let v):
				self = .exitCode(v)
			case .stdout(let v):
				self = .stdout(v)
			case .stderr(let v):
				self = .stderr(v)
			case .established(let v):
				self = .established(v.success, v.reason)
			case .none:
				self = .failure("Unknown response from the shell")
			}
		}

		public init(_ from: Caked_ExecuteResponse) {
			switch from.response {
				case .exitCode(let v):
				self = .exitCode(Int32(v))
			case .stdout(let v):
				self = .stdout(Data(v))
			case .stderr(let v):
				self = .stderr(Data(v))
			case .established(let v):
				self = .established(v.success, v.reason)
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
		
		public var established: (Bool, String) {
			get {
				if case .established(let established, let reason) = self {
					return (established, reason)
				}
				return (false, "Internal error")
			}
			set {
				self = .established(newValue.0, newValue.1)
			}
		}
	}
	
	public struct TerminalSize: Sendable, Equatable {
		public let rows: Int32
		public let cols: Int32

		public init(rows: Int32, cols: Int32) {
			self.rows = rows
			self.cols = cols
		}
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
		} else {
			return try ShellCaked(name: name, runMode: runMode).shell(terminalSize: terminalSize, connectionTimeout: connectionTimeout, runMode: runMode)
		}
	}

	internal class ShellCaked: ShellHandlerProtocol {
		private let name: String
		private let runMode: Utils.RunMode = .app
		private let logger = Logger("ShellHandler")
		private var serviceClient: CakedServiceClient! = nil
		private var shellStream: CakedExecuteStream! = nil
		private var stream: AsyncThrowingStreamShellResponse! = nil
		private var taskQueue: TaskQueue! = nil

		init(name: String, runMode: Utils.RunMode) throws {
			self.name = name
		}

		init(rootURL: URL) throws {
			self.name = rootURL.lastPathComponent.deletingPathExtension
		}

		func createCakedServiceClient(connectionTimeout: Int64, runMode: Utils.RunMode) throws -> CakedServiceClient {
			guard ServiceHandler.isAgentRunning(runMode: runMode) else {
				throw ServiceError("Caked service is not running")
			}

			let listenAddress = try Utils.getDefaultServerAddress(runMode: runMode)
			let certs = try ClientCertificatesLocation.getCertificats(runMode: runMode)

			var caCert: String? = nil
			var tlsCert: String? = nil
			var tlsKey: String? = nil

			if certs.exists() {
				caCert = certs.caCertURL.path
				tlsCert = certs.clientCertURL.path
				tlsKey = certs.clientKeyURL.path
			}

			return try Caked.createClient(on: Utilities.group.next(),
										  listeningAddress: URL(string: listenAddress),
										  connectionTimeout: 5,
										  retries: .upTo(1),
										  caCert: caCert,
										  tlsCert: tlsCert,
										  tlsKey: tlsKey)
		}

		public func shell(terminalSize: TerminalSize, connectionTimeout: Int64, runMode: Utils.RunMode) throws -> ShellHandlerProtocol {
			let serviceClient = try self.createCakedServiceClient(connectionTimeout: connectionTimeout, runMode: runMode)
			
			guard taskQueue == nil else {
				return self
			}
			
			self.logger.debug("Start shell, VM: \(self.name)")
			
			self.stream = self.startShell(rows: terminalSize.rows, cols: terminalSize.cols, serviceClient: serviceClient)
			self.serviceClient = serviceClient

			return self
		}

		func sendEof() {
			if let shellStream = self.shellStream {
				shellStream.sendEof()
			}
		}
		
		func sendTerminalSize(rows: Int, cols: Int) {
			if let shellStream = self.shellStream {
				shellStream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
			}
		}
		
		func sendDatas(data: ArraySlice<UInt8>) {
			if let shellStream = self.shellStream {
				data.withUnsafeBytes { ptr in
					let message = Caked_ExecuteRequest.with {
						$0.input = Data(bytes: ptr.baseAddress!, count: ptr.count)
					}
					
					try? shellStream.sendMessage(message).wait()
				}
			}
		}
		
		func handleResponse(_ handler: @escaping (ShellHandler.ExecuteResponse) async -> Void) async throws {
			for try await response in self.stream.stream {
				await handler(response)
			}
		}

		func closeShell(_ completionHandler: (@MainActor () -> Void)?) {
			func closeClient() {
				if let taskQueue {
					self.taskQueue = nil
					taskQueue.close()
				}
				
				if let serviceClient {
					self.serviceClient = nil

					serviceClient.channel.close().whenComplete { _ in
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

		func finish() {
			self.stream?.continuation.finish()
		}

		private func startShell(rows: Int32, cols: Int32, serviceClient: CakedServiceClient) -> AsyncThrowingStreamShellResponse {
			self.taskQueue = .init(label: "CakeAgent.InteractiveShell.\(self.name)")
			
			return taskQueue.dispatchStream { (continuation: AsyncThrowingStream<ExecuteResponse, Error>.Continuation) in
				do {
					_ = try serviceClient.info(.with {
						$0.name = self.name
					}, callOptions: CallOptions(timeLimit: .timeout(.seconds(10)))).response.wait()
					
					self.logger.debug("Start shell, VM: \(self.name)")
					
					self.shellStream = serviceClient.execute(callOptions: CallOptions(timeLimit: .none)) { response in
						continuation.yield(ExecuteResponse(response))
					}
					
					self.shellStream.sendShell()
					self.shellStream.sendTerminalSize(rows: rows, cols: cols)
					self.shellStream.sendShell()
					
					self.logger.debug("Shell started, VM: \(self.name)")
				} catch {
					continuation.finish(throwing: error)
				}
			}
		}
	}

	internal class ShellCakeAgent: ShellHandlerProtocol {
		private let location: VMLocation
		private let runMode: Utils.RunMode = .app
		private let logger = Logger("ShellHandler")
		private var helper: CakeAgentHelper! = nil
		private var shellStream: CakeAgentExecuteStream! = nil
		private var stream: AsyncThrowingStreamShellResponse! = nil
		private var taskQueue: TaskQueue! = nil

		init(name: String) throws {
			self.location = try StorageLocation(runMode: runMode).find(name)
		}

		init(rootURL: URL) throws {
			self.location = try VMLocation.newVMLocation(rootURL: rootURL)
		}

		func createCakeAgentHelper(connectionTimeout: Int64 = 1) throws -> CakeAgentHelper {
			// Create a short-lived client for the health check
			let eventLoop = Utilities.group.next()
			let client = try Utilities.createCakeAgentClient(
				on: eventLoop.next(),
				runMode: runMode,
				listeningAddress: self.location.agentURL,
				connectionTimeout: connectionTimeout,
				retries: .upTo(1)
			)
			
			return CakeAgentHelper(on: eventLoop, client: client)
		}
		
		public func shell(terminalSize: TerminalSize, connectionTimeout: Int64) throws -> ShellHandlerProtocol {
			let cakeHelper = try self.createCakeAgentHelper(connectionTimeout: connectionTimeout)
			
			guard taskQueue == nil else {
				return self
			}
			
			self.logger.debug("Start shell, VM: \(self.location.name)")
			
			self.stream = self.startShell(rows: terminalSize.rows, cols: terminalSize.cols, helper: cakeHelper)
			self.helper = cakeHelper

			return self
		}
		
		func sendEof() {
			if let shellStream = self.shellStream {
				shellStream.sendEof().whenComplete { _ in
					let promise = shellStream.eventLoop.makePromise(of: Void.self)
			  
				  promise.futureResult.whenComplete { _ in
					  try? self.helper.close().wait()
				  }
				  
				  shellStream.cancel(promise: promise)
			  }
			}
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
		
		public func handleResponse(_ handler: @escaping (ExecuteResponse) async -> Void) async throws {
			for try await response in self.stream.stream {
				await handler(response)
			}
		}

		func finish() {
			self.stream?.continuation.finish()
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
			
			self.logger.debug("Close shell: \(self.location.name)")
			
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
			self.taskQueue = .init(label: "CakeAgent.InteractiveShell.\(self.location.name)")
			
			return taskQueue.dispatchStream { (continuation: AsyncThrowingStream<ExecuteResponse, Error>.Continuation) in
				do {
					_ = try helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(10))))
					
					self.logger.debug("Start shell, VM: \(self.location.name)")
					
					self.shellStream = helper.client.execute(callOptions: CallOptions(timeLimit: .none)) { response in
						continuation.yield(ExecuteResponse(response))
					}
					
					self.shellStream.sendShell()
					self.shellStream.sendTerminalSize(rows: rows, cols: cols)
					self.shellStream.sendShell()
					
					self.logger.debug("Shell started, VM: \(self.location.name)")
				} catch {
					continuation.finish(throwing: error)
				}
			}
		}
	}
}
