import Foundation
import CakeAgentLib
import NIOCore
import NIOPosix
import NIOSSL
@preconcurrency import GRPC
import GRPCLib
import Logging
import CakeAgentLib
import SwiftProtobuf
import Atomics

extension CakeAgentClient {
	static func log(_ error: Error) {
		if let err = error as? GRPCStatus {
			if let message = err.message, err.code != .unavailable {
				Logger(self).error(message)
			}
		} else if String(describing: type(of: error)) != "ConnectionFailure" {
			Logger(self).error(error)
		}
	}

	func info() -> EventLoopFuture<Result<Caked_InfoReply, Error>> {
		let response = self.info(.init(), callOptions: .init(timeLimit: .none)).response

		return response.flatMapThrowing { response in
			return .success(Caked_InfoReply.with {
				$0.version = response.version
				$0.uptime = response.uptime
				$0.cpuCount = response.cpuCount
				$0.ipaddresses = response.ipaddresses
				$0.osname = response.osname
				$0.release = response.release

				if response.hasMemory {
					let mem = response.memory
					$0.memory = .with{ memory in
						memory.total = mem.total
						memory.free = mem.free
						memory.used = mem.used
					}
				}
			})
		}.flatMapErrorWithEventLoop { error, eventLoop in
			Self.log(error)

			return eventLoop.submit {
				return .failure(error)
			}
		}
	}

	func info() throws -> Caked_InfoReply {
		let response = try self.info().wait()

		switch response {
		case .success(let reply):
			return reply
		case .failure(let error):
			throw error
		}
	}

	func run(request: Caked_RunCommand) -> EventLoopFuture<Result<Caked_RunReply, Error>> {
		let response = self.run(Cakeagent_RunCommand.with { req in
			req.input = request.input
			req.command = Cakeagent_Command.with {
				$0.command = request.command.command
				$0.args = request.command.args
			}
		}, callOptions: .init(timeLimit: .none)).response

		return response.flatMapThrowing { response in
			return .success(Caked_RunReply.with { reply in
				reply.exitCode = response.exitCode

				if response.stderr.isEmpty == false {
					reply.stderr = response.stderr
				}

				if response.stdout.isEmpty == false {
					reply.stdout = response.stdout
				}
			})
		}.flatMapErrorWithEventLoop { error, eventLoop in
			Self.log(error)

			return response.eventLoop.submit {
				return .failure(error)
			}
		}
	}

	func run(request: Caked_RunCommand) throws -> Caked_RunReply {
		let response = try self.run(request: request).wait()

		switch response {
		case .success(let reply):
			return reply
		case .failure(let error):
			throw error
		}
	}

	func mount(request: Caked_MountRequest) throws -> Caked_MountReply {
		let response: Cakeagent_MountReply = try self.mount(Cakeagent_MountRequest.with {
			$0.mounts = request.mounts.map { option in
				Cakeagent_MountVirtioFS.with { 
					$0.uid = option.uid
					$0.gid = option.gid
					$0.name = option.name
					$0.target = option.target
				}
			}
		}, callOptions: .init(timeLimit: .none)).response.wait()

		return try Caked_MountReply.with { reply in
			if case Cakeagent_MountReply.OneOf_Response.error(let v)? = response.response {
				throw ServiceError(v)
			} else {
				reply.mounts = response.mounts.map { mount in
					Caked_MountVirtioFSReply.with {
						$0.name = mount.name

						if case Cakeagent_MountVirtioFSReply.OneOf_Response.error(let v)? = mount.response {
							$0.error = v
						} else if case Cakeagent_MountVirtioFSReply.OneOf_Response.success(let v)? = mount.response {
							$0.success = v
						}
					}
				}
			}
		}
	}

	func umount(request: Caked_MountRequest) throws -> Caked_MountReply {
		let response: Cakeagent_MountReply = try self.umount(Cakeagent_MountRequest.with {
			$0.mounts = request.mounts.map { option in
				Cakeagent_MountVirtioFS.with { 
					$0.uid = option.uid
					$0.gid = option.gid
					$0.name = option.name
					$0.target = option.target
				}
			}
		}, callOptions: .init(timeLimit: .none)).response.wait()

		return try Caked_MountReply.with { reply in
			if case Cakeagent_MountReply.OneOf_Response.error(let v)? = response.response {
				throw ServiceError(v)
			} else {
				reply.mounts = response.mounts.map { mount in
					Caked_MountVirtioFSReply.with {
						$0.name = mount.name

						if case Cakeagent_MountVirtioFSReply.OneOf_Response.error(let v)? = mount.response {
							$0.error = v
						} else if case Cakeagent_MountVirtioFSReply.OneOf_Response.success(let v)? = mount.response {
							$0.success = v
						}
					}
				}
			}
		}
	}
}

final class CakeAgentConnection: Sendable {
	let caCert: String?
	let tlsCert: String?
	let tlsKey: String?
	let eventLoop: EventLoopGroup
	let listeningAddress: URL
	let timeout: Int64
	let retries: ConnectionBackoff.Retries

	internal convenience init(eventLoop: EventLoopGroup, listeningAddress: URL, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited) throws {
		let certLocation = try CertificatesLocation.createAgentCertificats(asSystem: runAsSystem)

		self.init(eventLoop: eventLoop, listeningAddress: listeningAddress, certLocation: certLocation, timeout: timeout, retries: retries)
	}

	internal init(eventLoop: EventLoopGroup, listeningAddress: URL, caCert: String?, tlsCert: String?, tlsKey: String?, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited) {	// swiftlint:disable:this function_parameter_count
		self.caCert = caCert
		self.tlsCert = tlsCert
		self.tlsKey = tlsKey
		self.eventLoop = eventLoop
		self.timeout = timeout
		self.listeningAddress = listeningAddress
		self.retries = retries
	}

	internal convenience init(eventLoop: EventLoopGroup, listeningAddress: URL, certLocation: CertificatesLocation, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited) {
		self.init(eventLoop: eventLoop,
		          listeningAddress: listeningAddress,
		          caCert: certLocation.caCertURL.path,
		          tlsCert: certLocation.clientCertURL.path,
		          tlsKey: certLocation.clientKeyURL.path,
		          timeout: timeout,
		          retries: retries)
	}

	internal func createClient(interceptors: CakeAgentInterceptor? = nil) throws -> CakeAgentClient {
		return try CakeAgentHelper.createClient(on: self.eventLoop,
		                                        listeningAddress: self.listeningAddress,
		                                        connectionTimeout: self.timeout,
		                                        caCert: self.caCert,
		                                        tlsCert: self.tlsCert,
		                                        tlsKey: self.tlsKey,
		                                        retries: self.retries,
		                                        interceptors: interceptors)

	}

	public func info() throws -> EventLoopFuture<Result<Caked_InfoReply, Error>> {
		let client = try createClient()
		let response: EventLoopFuture<Result<Caked_InfoReply, Error>> = client.info()

		response.whenComplete { _ in
			client.close(promise: response.eventLoop.makePromise(of: Void.self))
		}

		return response
	}

	public func info() throws -> Caked_InfoReply {
		let response = try self.info().wait()

		switch response {
		case .success(let reply):
			return reply
		case .failure(let error):
			throw error
		}
	}

	public func run(command: String, arguments: [String] = [], input: Data? = nil) throws -> Caked_RunReply {
		let client = try createClient()

		do {
			let response = try client.run(Cakeagent_RunCommand.with { req in
				if let data = input {
					req.input = data
				}

				req.command = Cakeagent_Command.with {
					$0.command = command
					$0.args = arguments
				}
			}).response.wait()

			try? client.close().wait()

			return Caked_RunReply.with { reply in
				reply.exitCode = response.exitCode

				if response.stderr.isEmpty == false {
					reply.stderr = response.stderr
				}

				if response.stdout.isEmpty == false {
					reply.stdout = response.stdout
				}
			}
		} catch {
			try? client.close().wait()
			throw error
		}
	}

	public func run(request: Caked_RunCommand) throws -> Caked_RunReply {
		try self.run(command: String(request.command.command), arguments: request.command.args, input: request.input)
	}

	public func execute(requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>) async throws {
		let errorWasCaught = ManagedAtomic<Bool>(false)
		let (stream, continuation) = AsyncStream.makeStream(of: Caked_ExecuteResponse.self)
		let interceptor = CakeAgentClientInterceptorFactory(responseStream: responseStream) {
			errorWasCaught.store(true, ordering: .sequentiallyConsistent)
		}
		let client = try createClient(interceptors: interceptor)
		var exitCodeSent = false

		let failure = { (error: Error) in
			if errorWasCaught.load(ordering: .sequentiallyConsistent) == false {
				Logger(self).error(error)
				errorWasCaught.store(true, ordering: .sequentiallyConsistent)
				try? await responseStream.send(Caked_ExecuteResponse.with { 
					$0.failure = error.localizedDescription
				})
			}
		}

		let finish = {
			continuation.finish()
			try? await client.close()
		}

		do {

			let streamShell: BidirectionalStreamingCall<Cakeagent_ExecuteRequest, Cakeagent_ExecuteResponse> = client.execute(callOptions: .init(timeLimit: .none), handler: { response in
				continuation.yield(Caked_ExecuteResponse.with { reply in
					switch response.response {
					case .exitCode(let exitCode):
						reply.exitCode = exitCode
						exitCodeSent = true
					case .stdout(let stdout):
						reply.stdout = stdout
					case .stderr(let stderr):
						reply.stderr = stderr
					case .established:
						reply.established = true
					case .none:
						break
					}
				})
			})

			try await withThrowingTaskGroup(of: Void.self, returning: Void.self) { group in
				group.addTask {
					do {
						for try await message: Caked_ExecuteRequest in requestStream {
							try await streamShell.sendMessage(Cakeagent_ExecuteRequest.with{msg in
								switch message.request {
								case .command(let command):
									msg.command = Cakeagent_ExecuteCommand.with{ cmd in
										switch command.execute {
										case .shell:
											cmd.shell = true
										case .command(let execute):
											cmd.command = Cakeagent_Command.with{ cmd in
												cmd.command = execute.command
												cmd.args = execute.args
											}
										case .none:
											break
										}
									}
								case .input(let input):
									msg.input = input
								case .size(let size):
									msg.size = Cakeagent_TerminalSize.with{ termSize in
										termSize.cols = size.cols
										termSize.rows = size.rows
									}
								case .eof(let eof):
									msg.eof = eof
								case .none:
									break
								}
							}).get()
						}
					} catch {
						continuation.finish()
						if error is CancellationError == false {
							guard let err = error as? ChannelError, err == ChannelError.ioOnClosedChannel else {
								await failure(error)
								return
							}
						}
					}
				}

				group.addTask {
					do {
						for try await message in stream {
							try await responseStream.send(message)

							if case .exitCode = message.response {
								break
							}
						}
					} catch {
						continuation.finish()

						if error is CancellationError == false {
							guard let err = error as? ChannelError, err == ChannelError.ioOnClosedChannel else {
								await failure(error)
								return
							}
						}
					}
				}

				try await group.waitForAll()

				if errorWasCaught.load(ordering: .sequentiallyConsistent) == false && exitCodeSent == false {
					try? await responseStream.send(Caked_ExecuteResponse.with { 
						$0.failure = "canceled"
					})
				}

				await finish()
			}
		} catch {
			try? await responseStream.send(Caked_ExecuteResponse.with { 
				$0.failure = error.localizedDescription
			})

			await finish()
			throw error
		}
	}

	func mount(request: Caked_MountRequest) throws -> Caked_MountReply {
		let client = try createClient()

		defer {
			try? client.close().wait()
		}

		return try client.mount(request: request)
	}

	func umount(request: Caked_MountRequest) throws -> Caked_MountReply {
		let client = try createClient()

		defer {
			try? client.close().wait()
		}

		return try client.umount(request: request)
	}

	static func createCakeAgentConnection(on: EventLoop, listeningAddress: URL, timeout: Int, asSystem: Bool, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentConnection {
		return try CakeAgentConnection(eventLoop: on, listeningAddress: listeningAddress, timeout: Int64(timeout), retries: retries)
	}
}
