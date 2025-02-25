import ArgumentParser
import Foundation
import GRPCLib
@preconcurrency import GRPC
import NIO
import NIOPosix
import NIOSSL

extension FileHandle {
	func makeRaw() -> termios {
		var term: termios = termios()
		let inputTTY: Bool = isatty(self.fileDescriptor) != 0

		if inputTTY {
			if tcgetattr(self.fileDescriptor, &term) != 0 {
				perror("tcgetattr error")
			}

			var newState: termios = term

			newState.c_iflag &= UInt(IGNBRK) | ~UInt(BRKINT | INPCK | ISTRIP | IXON)
			newState.c_cflag |= UInt(CS8)
			newState.c_lflag &= ~UInt(ECHO | ICANON | IEXTEN | ISIG)
			newState.c_cc.16 = 1
			newState.c_cc.17 = 17

			if tcsetattr(self.fileDescriptor, TCSANOW, &newState) != 0 {
				perror("tcsetattr error")
			}
		}

		return term
	}

	func restoreState(_ term: UnsafePointer<termios>) {
		if tcsetattr(self.fileDescriptor, TCSANOW, term) != 0 {
			perror("tcsetattr error")
		}
	}
}

struct Sh: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "shell", abstract: "Run a shell on a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String = ""

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		var shellStream: BidirectionalStreamingCall<Caked_ShellRequest, Caked_ShellResponse>?
		var pipeChannel: NIOAsyncChannel<ByteBuffer, ByteBuffer>?
		var term = FileHandle.standardInput.makeRaw()
		var callOptions = callOptions ?? CallOptions()

		defer {
			FileHandle.standardInput.restoreState(&term)
		}

		callOptions.timeLimit = .none
		callOptions.customMetadata.add(name: "CAKEAGENT_VMNAME", value: name)

		shellStream = client.shell(callOptions: callOptions, handler: { response in
			if let channel = pipeChannel {					
				if response.format == .end {
					_ = channel.channel.close()
				} else {
					channel.channel.eventLoop.execute {
						do {
							if response.format == .stdout {
								try FileHandle.standardOutput.write(contentsOf: response.datas)
							} else if response.format == .stderr {
								try FileHandle.standardError.write(contentsOf: response.datas)
							}
						} catch {
							if error is CancellationError == false {
								guard let err = error as? ChannelError, err == ChannelError.ioOnClosedChannel else {
									let errMessage = "error: \(error)\n".data(using: .utf8)!

									FileHandle.standardError.write(errMessage)
									return
								}
							}
						}
					}
				}
			}
		})

		if let stream = shellStream {
    		let semaphore = DispatchSemaphore(value: 0)
	
			Task {
				defer {
					semaphore.signal()
				}

				do {
					pipeChannel = try await stream.subchannel.flatMapThrowing { streamChannel in
						return Task {
							return try await NIOPipeBootstrap(group: streamChannel.eventLoop)
								.takingOwnershipOfDescriptor(input: dup(FileHandle.standardInput.fileDescriptor)) { pipeChannel in
									pipeChannel.closeFuture.whenComplete { _ in
										_ = stream.sendEnd()
									}

									return pipeChannel.eventLoop.makeCompletedFuture {
										try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: pipeChannel)
									}
								}
						}
					}.get().value
				} catch {
					FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
					throw error
				}

				try await pipeChannel!.executeThenClose { inbound, outbound in
					do {
						for try await buffer: ByteBuffer in inbound {
							let message = Caked_ShellRequest.with {
								$0.datas = Data(buffer: buffer)
							}

							_ = stream.sendMessage(message)
						}
					} catch {
						if error is CancellationError == false {
							guard let err = error as? ChannelError, err == ChannelError.ioOnClosedChannel else {
								let errMessage = "error: \(error)\n".data(using: .utf8)!

								FileHandle.standardError.write(errMessage)
								return
							}
						}
					}
					_ = stream.sendEnd()
				}
			}

			semaphore.wait()
		}

		return Caked_Reply.with {
			$0.output = ""
		}
	}
}