import Foundation
@preconcurrency import GRPC
import GRPCLib
import NIO
import Semaphore

typealias CakedExecuteStream = BidirectionalStreamingCall<Caked_ExecuteRequest, Caked_ExecuteResponse>

extension CakedExecuteStream {
	@discardableResult
	func sendTerminalSize(rows: Int32, cols: Int32) -> EventLoopFuture<Void> {
		let message = Caked_ExecuteRequest.with {
			$0.size = Caked_TerminalSize.with {
				$0.rows = rows
				$0.cols = cols
			}
		}

		return self.sendMessage(message)
	}

	@discardableResult
	func sendCommand(command: String, arguments: [String]) -> EventLoopFuture<Void> {
		let message = Caked_ExecuteRequest.with {
			$0.command = Caked_ExecuteCommand.with {
				$0.command = Caked_Command.with {
					$0.command = command
					$0.args = arguments
				}
			}
		}

		return self.sendMessage(message)
	}

	@discardableResult
	func sendShell() -> EventLoopFuture<Void> {
		let message = Caked_ExecuteRequest.with {
			$0.command = Caked_ExecuteCommand.with {
				$0.shell = true
			}
		}

		return self.sendMessage(message)
	}

	@discardableResult
	func sendBuffer(_ buffer: ByteBuffer) -> EventLoopFuture<Void> {
		let message = Caked_ExecuteRequest.with {
			$0.input = Data(buffer: buffer)
		}

		return self.sendMessage(message)
	}

	@discardableResult
	func sendEof() -> EventLoopFuture<Void> {
		let message = Caked_ExecuteRequest.with {
			$0.eof = true
		}

		return self.sendMessage(message)
	}

	@discardableResult
	func end() -> EventLoopFuture<Void> {
		#if TRACE
			redbold("Send end")
		#endif
		return self.sendEnd()
	}
}

final class CakedChannelStreamer: @unchecked Sendable {
	let inputHandle: FileHandle
	let outputHandle: FileHandle
	let errorHandle: FileHandle
	var pipeChannel: NIOAsyncChannel<ByteBuffer, ByteBuffer>? = nil
	let isTTY: Bool
	var exitCode: Int32 = 0
	var receivedLength: UInt64 = 0
	let semaphore = AsyncSemaphore(value: 0)
	var term: termios? = nil

	enum ExecuteCommand: Equatable, Sendable {
		case execute(String, [String])
		case shell(Bool = true)
	}

	init(inputHandle: FileHandle, outputHandle: FileHandle, errorHandle: FileHandle) {
		self.inputHandle = inputHandle
		self.outputHandle = outputHandle
		self.errorHandle = errorHandle
		self.isTTY = inputHandle.isTTY() && outputHandle.isTTY()
	}

	func redbold(_ string: String) {
		FileHandle.standardError.write("\u{001B}[0;31m\u{001B}[1m\(string)\u{001B}[0m\n".data(using: .utf8)!)
	}

	func printError(_ string: String) {
		let errMessage = "\(string)\n".data(using: .utf8)!

		if FileHandle.standardError.fileDescriptor != self.errorHandle.fileDescriptor {
			FileHandle.standardError.write(errMessage)
		}

		self.errorHandle.write(errMessage)
	}

	func handleResponse(response: Caked_ExecuteResponse) {
		guard let pipeChannel = self.pipeChannel else {
			return
		}

		do {
			if case .failure(let reason) = response.response {
				#if TRACE
					redbold("failure=\(code)")
				#endif
				printError("\(reason)")
				self.exitCode = -1
				_ = pipeChannel.channel.close()
				self.semaphore.signal()
			} else if case .exitCode(let code) = response.response {
				#if TRACE
					redbold("exitCode=\(code)")
				#endif
				self.exitCode = code
				_ = pipeChannel.channel.close()
				self.semaphore.signal()
			} else if case .stdout(let datas) = response.response {
				self.receivedLength += UInt64(datas.count)
				#if TRACE
					redbold("message length: \(datas.count), receivedLength=\(self.receivedLength)")
				#endif
				try self.outputHandle.write(contentsOf: datas)
			} else if case .stderr(let datas) = response.response {
				try self.errorHandle.write(contentsOf: datas)
			} else if case .established = response.response {
				#if TRACE
					redbold("channel established")
				#endif
				if self.inputHandle.isTTY() {
					term = try self.inputHandle.makeRaw()
				}
			}
		} catch {
			if error is CancellationError == false {
				guard let err = error as? ChannelError, err == ChannelError.ioOnClosedChannel else {
					printError("error: \(error)\n")
					return
				}
			}
		}
	}

	@discardableResult
	func setTerminalSize(stream: CakedExecuteStream) -> EventLoopFuture<Void> {
		let size = self.isTTY ? self.outputHandle.getTermSize() : (rows: 0, cols: 0)

		return stream.sendTerminalSize(rows: size.rows, cols: size.cols)
	}

	func stream(command: ExecuteCommand, handler: @escaping () -> CakedExecuteStream) async throws -> Int32 {
		let shellStream: CakedExecuteStream = handler()
		let sigwinch: DispatchSourceSignal?

		defer {
			if var term = self.term {
				try? inputHandle.restoreState(&term)
			}
		}

		if self.isTTY {
			let sig = DispatchSource.makeSignalSource(signal: SIGWINCH)

			sigwinch = sig

			sig.setEventHandler {
				shellStream.eventLoop.execute {
					self.setTerminalSize(stream: shellStream)
				}
			}

			sig.activate()
		} else {
			sigwinch = nil
		}

		self.setTerminalSize(stream: shellStream)

		let fd: CInt
		let fileProxy: Pipe?
		let fileSize: UInt64

		if try self.inputHandle.fileDescriptorIsFile() {
			let proxy = Pipe()
			let currentOffset = try self.inputHandle.offset()

			fd = proxy.fileHandleForReading.fileDescriptor
			fileProxy = proxy
			fileSize = try self.inputHandle.seekToEnd()

			try self.inputHandle.seek(toOffset: currentOffset)
		} else {
			fd = dup(self.inputHandle.fileDescriptor)
			fileProxy = nil
			fileSize = 0
		}

		defer {
			#if TRACE
				redbold("Exit receivedLength=\(self.receivedLength)")
			#endif
			if let sig = sigwinch {
				sig.cancel()
			}
			shellStream.end()

			if let fileProxy = fileProxy {
				fileProxy.fileHandleForWriting.closeFile()
				fileProxy.fileHandleForReading.closeFile()
			}
		}

		self.pipeChannel = try await shellStream.subchannel.flatMapThrowing { streamChannel in
			return Task {
				return try await NIOPipeBootstrap(group: streamChannel.eventLoop)
					.channelOption(.autoRead, value: true)
					.takingOwnershipOfDescriptor(input: fd) { pipeChannel in
						if let proxy = fileProxy {
							proxy.fileHandleForWriting.writeabilityHandler = { handle in
								if let data = try? self.inputHandle.read(upToCount: 1024) {
									if data.isEmpty == false {
										handle.write(data)
									}
								}
							}
						}

						return pipeChannel.eventLoop.makeCompletedFuture {
							try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: pipeChannel)
						}
					}
			}
		}.get().value

		try await pipeChannel!.executeThenClose { inbound, outbound in
			if case .execute(let cmd, let arguments) = command {
				shellStream.sendCommand(command: cmd, arguments: arguments)
			} else if case .shell = command {
				shellStream.sendShell()
			}

			do {
				var bufLength = fileSize

				for try await buffer: ByteBuffer in inbound {
					shellStream.sendBuffer(buffer)

					if fileSize > 0 {
						bufLength -= UInt64(buffer.readableBytes)
						#if TRACE
							redbold("Remains bufLength=\(bufLength), receivedLength=\(self.receivedLength)")
						#endif
						if bufLength <= 0 {
							break
						}
					} else {
						bufLength += UInt64(buffer.readableBytes)
					}
				}

				#if TRACE
					redbold("EOF bufLength=\(bufLength), receivedLength=\(self.receivedLength)")
				#endif

				shellStream.sendEof()
			} catch {
				#if TRACE
					redbold("error: \(error)")
				#endif
				if error is CancellationError == false {
					guard let err = error as? ChannelError, err == ChannelError.ioOnClosedChannel else {
						let errMessage = "error: \(error)\n".data(using: .utf8)!

						if FileHandle.standardError.fileDescriptor != self.errorHandle.fileDescriptor {
							FileHandle.standardError.write(errMessage)
						}

						errorHandle.write(errMessage)
						return
					}
				}
			}
		}

		await self.semaphore.wait()

		return self.exitCode
	}
}
