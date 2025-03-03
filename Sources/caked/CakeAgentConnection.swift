import Foundation
import CakeAgentLib
import NIOCore
import NIOPosix
import NIOSSL
import GRPC
import GRPCLib
import Logging
import CakeAgentLib

extension CakeAgentClient {
	func info() -> EventLoopFuture<Caked_InfoReply?> {
		let response = self.info(.init(), callOptions: .init(timeLimit: .none)).response

		return response.flatMapThrowing { response in
			return Caked_InfoReply.with {
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
			}
		}.flatMapError { error in
			Logger.error(error)
			return response.eventLoop.submit {
				return nil
			}
		}
	}

	func info() throws -> Caked_InfoReply {
		guard let response = try self.info().wait() else {
			throw ServiceError("Failed to get info")
		}

		return response
	}

	func execute(request: Caked_ExecuteRequest) -> EventLoopFuture<Caked_ExecuteReply?> {
		let response = self.execute(Cakeagent_ExecuteRequest.with { req in
			if request.hasInput {
				req.input = Data(request.input)
			}

			req.command = request.command
			req.args = request.args
		}, callOptions: .init(timeLimit: .none)).response

		return response.flatMapThrowing { response in
			return Caked_ExecuteReply.with { reply in
				reply.exitCode = response.exitCode

				if response.hasError {
					reply.error = response.error
				}

				if response.hasOutput {
					reply.output = response.output
				}
			}
		}.flatMapError { error in
			Logger.error(error)
			return response.eventLoop.submit {
				return nil
			}
		}
	}

	func execute(request: Caked_ExecuteRequest) throws -> Caked_ExecuteReply {
		guard let response = try self.execute(request: request).wait() else {
			throw ServiceError("Failed to execute command")
		}

		return response
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

		return Caked_MountReply.with { reply in
			if case Cakeagent_MountReply.OneOf_Response.error(let v)? = response.response {
				reply.error = v
			} else if case Cakeagent_MountReply.OneOf_Response.success(let v)? = response.response {
				reply.success = v
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

		return Caked_MountReply.with { reply in
			if case Cakeagent_MountReply.OneOf_Response.error(let v)? = response.response {
				reply.error = v
			} else if case Cakeagent_MountReply.OneOf_Response.success(let v)? = response.response {
				reply.success = v
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

struct CakeAgentConnection {
	let caCert: String?
	let tlsCert: String?
	let tlsKey: String?
	let eventLoop: EventLoopGroup
	let listeningAddress: URL
	let timeout: Int64
	let retries: ConnectionBackoff.Retries

	init(eventLoop: EventLoopGroup, listeningAddress: URL, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited) throws {
		let certLocation = try CertificatesLocation.createAgentCertificats(asSystem: runAsSystem)

		self.init(eventLoop: eventLoop, listeningAddress: listeningAddress, certLocation: certLocation, timeout: timeout, retries: retries)
	}

	init(eventLoop: EventLoopGroup, listeningAddress: URL, caCert: String?, tlsCert: String?, tlsKey: String?, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited) {	// swiftlint:disable:this function_parameter_count
		self.caCert = caCert
		self.tlsCert = tlsCert
		self.tlsKey = tlsKey
		self.eventLoop = eventLoop
		self.timeout = timeout
		self.listeningAddress = listeningAddress
		self.retries = retries
	}

	init(eventLoop: EventLoopGroup, listeningAddress: URL, certLocation: CertificatesLocation, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited) {
		self.init(eventLoop: eventLoop,
		          listeningAddress: listeningAddress,
		          caCert: certLocation.caCertURL.path(),
		          tlsCert: certLocation.clientCertURL.path(),
		          tlsKey: certLocation.clientKeyURL.path(),
		          timeout: timeout,
		          retries: retries)
	}

	func createClient() throws -> CakeAgentClient {
		return try CakeAgentHelper.createClient(on: self.eventLoop,
		                                        listeningAddress: self.listeningAddress,
		                                        connectionTimeout: self.timeout,
		                                        caCert: self.caCert,
		                                        tlsCert: self.tlsCert,
		                                        tlsKey: self.tlsKey,
		                                        retries: self.retries)

	}

	func info() throws -> EventLoopFuture<Caked_InfoReply?> {
		let client = try createClient()
		let response: EventLoopFuture<Caked_InfoReply?> = client.info()

		response.whenComplete { _ in
			client.close(promise: response.eventLoop.makePromise(of: Void.self))
		}

		return response
	}

	func info() throws -> Caked_InfoReply {
		let client = try createClient()

		defer {
			try? client.close().wait()
		}

		return try client.info()
	}

	func execute(request: Caked_ExecuteRequest) throws -> EventLoopFuture<Caked_ExecuteReply?> {
		let client = try createClient()
		let response: EventLoopFuture<Caked_ExecuteReply?> = client.execute(request: request)

		response.whenComplete { _ in
			client.close(promise: response.eventLoop.makePromise(of: Void.self))
		}

		return response
	}

	func execute(request: Caked_ExecuteRequest) throws -> Caked_ExecuteReply {
		let client = try createClient()

		defer {
			try? client.close().wait()
		}

		return try client.execute(request: request)
	}

	func shell(requestStream: GRPCAsyncRequestStream<Caked_ShellRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ShellResponse>) async throws {
		let (stream, continuation) = AsyncStream.makeStream(of: Caked_ShellResponse.self)
		let client = try createClient()
		let finish = {
			continuation.finish()
			try? await responseStream.send(Caked_ShellResponse.with { $0.format = .end })
			try? await client.close()
		}

		do {

			let streamShell = client.shell(callOptions: .init(timeLimit: .none), handler: { response in
				continuation.yield(Caked_ShellResponse.with { reply in
					reply.format = .init(rawValue: response.format.rawValue) ?? .end
					reply.datas = response.datas
				})
			})

			try await withThrowingTaskGroup(of: Void.self, returning: Void.self) { group in
				group.addTask {
					do {
						for try await message in requestStream {
							try await streamShell.sendMessage(Cakeagent_ShellMessage.with{msg in
								msg.datas = message.datas
							}).get()
						}
					} catch {
						if error is CancellationError == false {
							guard let err = error as? ChannelError, err == ChannelError.ioOnClosedChannel else {
								Logger.error(error)
								throw error
							}
						}
					}
				}

				group.addTask {
					do {
						for try await message in stream {
							try await responseStream.send(message)
						}
					} catch {
						continuation.finish()

						if error is CancellationError == false {
							guard let err = error as? ChannelError, err == ChannelError.ioOnClosedChannel else {
								Logger.error(error)
								throw error
							}
						}
					}
				}

				try await group.waitForAll()

				await finish()
			}
		} catch {
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
