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
import NIO

public typealias AsyncThrowingStreamShellStream = AsyncThrowingStream<ShellHandler.ExecuteResponse, Error>
public typealias AsyncThrowingStreamShellContinuation = AsyncThrowingStream<ShellHandler.ExecuteResponse, Error>.Continuation
public typealias AsyncThrowingStreamShellResponse = (stream: AsyncThrowingStreamShellStream, continuation: AsyncThrowingStreamShellContinuation)

public struct ShellHandler {
	public protocol ShellHandlerProtocol: AsyncSequence where AsyncIterator == AsyncThrowingStream<ShellHandler.ExecuteResponse, Error>.Iterator {

		func sendTerminalSize(rows: Int, cols: Int)
		func sendDatas(data: ArraySlice<UInt8>)
		func sendEof()
		func closeShell(promise: EventLoopPromise<Void>?)
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

	public static func shell(vmURL: URL, terminalSize: TerminalSize, connectionTimeout: Int64 = 1, runMode: Utils.RunMode) throws -> any ShellHandlerProtocol {
		if vmURL.isFileURL {
			return try ShellCakeAgent(vmURL: vmURL, runMode: runMode).shell(terminalSize: terminalSize, connectionTimeout: connectionTimeout)
		} else {
			return try ShellCaked(vmURL: vmURL, runMode: runMode).shell(terminalSize: terminalSize, connectionTimeout: connectionTimeout, runMode: runMode)
		}
	}

	internal class ShellCaked: ShellHandlerProtocol {
		private let name: String
		private let runMode: Utils.RunMode
		private let logger = Logger("ShellHandler")
		private var serviceClient: CakedServiceClient! = nil
		private var cakedShellStream: CakedExecuteStream! = nil
		private var stream: AsyncThrowingStreamShellResponse! = nil
		private var taskQueue: TaskQueue! = nil

		func makeAsyncIterator() -> AsyncThrowingStream<ShellHandler.ExecuteResponse, any Error>.Iterator {
			self.stream.stream.makeAsyncIterator()
		}
		
		init(name: String, runMode: Utils.RunMode) throws {
			self.name = name
			self.runMode = runMode
		}

		init(vmURL: URL, runMode: Utils.RunMode) throws {
			if vmURL.isFileURL {
				throw ServiceError("Cannot create ShellCaked for file URL: \(vmURL)")
			}

			guard let name = vmURL.host(percentEncoded: false) else {
				throw ServiceError("Wrong URL: \(vmURL). Cannot extract name")
			}

			self.name = name
			self.runMode = runMode
		}

		public func shell(terminalSize: TerminalSize, connectionTimeout: Int64, runMode: Utils.RunMode) throws -> Self {
			guard taskQueue == nil else {
				return self
			}

			let serviceClient = try ServiceHandler.createCakedServiceClient(connectionTimeout: connectionTimeout, runMode: runMode)
			
			self.logger.debug("Starting shell, VM: \(self.name)")
			
			self.stream = self.startShell(rows: terminalSize.rows, cols: terminalSize.cols, serviceClient: serviceClient)
			self.serviceClient = serviceClient

			return self
		}

		func sendEof() {
			self.logger.debug("Send EOF shell, VM: \(self.name)")

			if let shellStream = self.cakedShellStream {
				shellStream.sendEof()
			}
		}
		
		func sendTerminalSize(rows: Int, cols: Int) {
			if let shellStream = self.cakedShellStream {
				shellStream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
			}
		}
		
		func sendDatas(data: ArraySlice<UInt8>) {
			if let shellStream = self.cakedShellStream {
				data.withUnsafeBytes { ptr in
					let message = Caked_ExecuteRequest.with {
						$0.input = Data(bytes: ptr.baseAddress!, count: ptr.count)
					}
					
					try? shellStream.sendMessage(message).wait()
				}
			}
		}
		
		func closeShell(promise: EventLoopPromise<Void>?) {
			func closeClient() {
				if let taskQueue {
					self.taskQueue = nil
					taskQueue.close()
				}
				
				if let serviceClient {
					self.serviceClient = nil

					if let promise {
						serviceClient.channel.close(promise: promise)
					} else {
						serviceClient.channel.close().whenComplete { _ in
							self.logger.debug("Service client closed")
						}
					}
				} else if let promise {
					promise.succeed()
				}
			}
			
			guard let cakedShellStream else {
				closeClient()
				return
			}
			
			self.logger.debug("Close shell: \(self.name)")
			
			self.cakedShellStream = nil
			
			cakedShellStream.sendEof().whenComplete {_ in
				let promise = cakedShellStream.eventLoop.makePromise(of: Void.self)
				
				promise.futureResult.whenComplete { _ in
					closeClient()
				}
				
				cakedShellStream.cancel(promise: promise)
			}
		}

		func finish() {
			self.logger.debug("Finish shell stream: \(self.name)")
			self.stream?.continuation.finish()
		}

		private func startShell(rows: Int32, cols: Int32, serviceClient: CakedServiceClient) -> AsyncThrowingStreamShellResponse {
			self.taskQueue = .init(label: "CakeAgent.InteractiveShell.\(self.name)")
			
			return taskQueue.dispatchStream { (continuation: AsyncThrowingStream<ExecuteResponse, Error>.Continuation) in
				do {
					_ = try serviceClient.info(name: self.name)
					
					self.logger.debug("Start shell, VM: \(self.name)")
					
					self.cakedShellStream = try serviceClient.shell(name: self.name, rows: rows, cols: cols) { response in
						continuation.yield(ExecuteResponse(response))
					}
					
					self.logger.debug("Shell started, VM: \(self.name)")
				} catch {
					self.logger.debug("Shell error, VM: \(self.name), \(error)")
					continuation.finish(throwing: error)
				}
			}
		}
	}

	internal class ShellCakeAgent: ShellHandlerProtocol {
		private let location: VMLocation
		private let runMode: Utils.RunMode
		private let logger = Logger("ShellHandler")
		private var helper: CakeAgentHelper! = nil
		private var cakedShellStream: CakeAgentExecuteStream! = nil
		private var stream: AsyncThrowingStreamShellResponse! = nil
		private var taskQueue: TaskQueue! = nil

		func makeAsyncIterator() -> AsyncThrowingStream<ShellHandler.ExecuteResponse, any Error>.Iterator {
			self.stream.stream.makeAsyncIterator()
		}
		
		init(vmURL: URL, runMode: Utils.RunMode) throws {
			self.runMode = runMode
			self.location = try VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode)
		}

		public func shell(terminalSize: TerminalSize, connectionTimeout: Int64) throws -> Self {
			let cakeHelper = try CakeAgentHelper.createCakeAgentHelper(location: self.location, connectionTimeout: connectionTimeout, retries: .upTo(1), runMode: self.runMode)
			
			guard taskQueue == nil else {
				return self
			}
			
			self.logger.debug("Starting shell, VM: \(self.location.name)")
			
			self.stream = self.startShell(rows: terminalSize.rows, cols: terminalSize.cols, helper: cakeHelper)
			self.helper = cakeHelper

			return self
		}
		
		func sendEof() {
			self.logger.debug("Send EOF shell, VM: \(self.location.name)")

			if let shellStream = self.cakedShellStream {
				shellStream.sendEof().whenComplete { _ in
					let promise = shellStream.eventLoop.makePromise(of: Void.self)
					
					promise.futureResult.whenComplete { _ in
						self.logger.debug("Helper closed, VM: \(self.location.name)")
						
						self.helper.close().whenComplete { _ in
							self.logger.debug("Helper closed, VM: \(self.location.name)")
						}
					}
					
					shellStream.cancel(promise: promise)
				}
			}
		}
		
		public func sendTerminalSize(rows: Int, cols: Int) {
			if let shellStream = self.cakedShellStream {
				shellStream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
			}
		}
		
		public func sendDatas(data: ArraySlice<UInt8>) {
			if let shellStream = self.cakedShellStream {
				data.withUnsafeBytes { ptr in
					let message = CakeAgent.ExecuteRequest.with {
						$0.input = Data(bytes: ptr.baseAddress!, count: ptr.count)
					}
					
					try? shellStream.sendMessage(message).wait()
				}
			}
		}

		func finish() {
			self.logger.debug("Finish shell stream: \(self.location.name)")
			self.stream?.continuation.finish()
		}

		public func closeShell(promise: EventLoopPromise<Void>?) {
			func closeClient() {
				if let taskQueue {
					self.taskQueue = nil
					taskQueue.close()
				}
				
				if let helper {
					self.helper = nil

					if let promise {
						helper.close(promise: promise)
					} else {
						helper.close().whenComplete { _ in
							
						}
					}
				} else if let promise {
					promise.succeed()
				}
			}
			
			guard let cakedShellStream else {
				closeClient()
				return
			}
			
			self.logger.debug("Close shell: \(self.location.name)")
			
			self.cakedShellStream = nil
			
			cakedShellStream.sendEof().whenComplete {_ in
				let promise = cakedShellStream.eventLoop.makePromise(of: Void.self)
				
				promise.futureResult.whenComplete { _ in
					closeClient()
				}
				
				cakedShellStream.cancel(promise: promise)
			}
		}
		
		private func startShell(rows: Int32, cols: Int32, helper: CakeAgentHelper) -> AsyncThrowingStreamShellResponse {
			self.taskQueue = .init(label: "CakeAgent.InteractiveShell.\(self.location.name)")
			
			return taskQueue.dispatchStream { (continuation: AsyncThrowingStream<ExecuteResponse, Error>.Continuation) in
				do {
					_ = try helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(10))))
					
					self.logger.debug("Start shell, VM: \(self.location.name)")
					
					self.cakedShellStream = helper.client.execute(callOptions: CallOptions(timeLimit: .none)) { response in
						continuation.yield(ExecuteResponse(response))
					}
					
					self.cakedShellStream.sendTerminalSize(rows: rows, cols: cols)
					self.cakedShellStream.sendShell()
					
					self.logger.debug("Shell started, VM: \(self.location.name)")
				} catch {
					self.logger.debug("Shell error, VM: \(self.location.name), \(error)")
					continuation.finish(throwing: error)
				}
			}
		}
	}
}
