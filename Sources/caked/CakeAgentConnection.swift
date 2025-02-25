import Foundation
import CakeAgentLib
import NIOCore
import NIOPosix
import NIOSSL
import GRPC
import GRPCLib
import Logging
import CakeAgentLib

struct CakeAgentConnection {
	let caCert: String?
	let tlsCert: String?
	let tlsKey: String?
	let eventLoop: EventLoopGroup
	let listeningAddress: URL
	let timeout: Int64
	let retries: ConnectionBackoff.Retries

	init(eventLoop: EventLoopGroup, listeningAddress: URL, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited) throws {
		let certLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: runAsSystem))).createCertificats()
	
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
		          tlsCert: certLocation.serverCertURL.path(),
		          tlsKey: certLocation.serverKeyURL.path(),
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

	func infoFuture() throws -> EventLoopFuture<Caked_InfoReply?> {
		let client = try createClient()
		let response = client.info(.init()).response

		response.whenComplete { _ in
			client.close(promise: response.eventLoop.makePromise(of: Void.self))
		}

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
			return response.eventLoop.submit {
				return nil
			}
		}
	}

	func info() throws -> Caked_InfoReply {
		let client = try createClient()

		do {
			let response = try client.info(.init()).response.wait()

			let reply = Caked_InfoReply.with {reply in
				reply.version = response.version
				reply.uptime = response.uptime
				reply.cpuCount = response.cpuCount
				reply.ipaddresses = response.ipaddresses
				reply.osname = response.osname
				reply.release = response.release

				if response.hasMemory {
					let mem = response.memory
					reply.memory = .with{ memory in
						memory.total = mem.total
						memory.free = mem.free
						memory.used = mem.used
					}
				}
			}

			try? client.close().wait()

			return reply
		} catch {
			try? client.close().wait()
			throw error
		}
	}

	func executeFuture(request: Caked_ExecuteRequest) throws -> EventLoopFuture<Caked_ExecuteReply?> {
		let client = try createClient()
		let response = client.execute(Cakeagent_ExecuteRequest.with { req in
			if request.hasInput {
				req.input = Data(request.input)
			}

			req.command = request.command
			req.args = request.args
		}).response

		response.whenComplete { _ in
			client.close(promise: response.eventLoop.makePromise(of: Void.self))
		}

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
			return response.eventLoop.submit {
				return nil
			}
		}
	}

	func execute(request: Caked_ExecuteRequest) throws -> Caked_ExecuteReply {
		let client = try createClient()

		do {
			let response = try client.execute(Cakeagent_ExecuteRequest.with { req in
				if request.hasInput {
					req.input = Data(request.input)
				}

				req.command = request.command
				req.args = request.args
			}).response.wait()

			try? client.close().wait()

			return Caked_ExecuteReply.with { reply in
				reply.exitCode = response.exitCode

				if response.hasError {
					reply.error = response.error
				}

				if response.hasOutput {
					reply.output = response.output
				}
			}
		} catch {
			try? client.close().wait()
			throw error
		}
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

	static func createCakeAgentConnection(on: EventLoop, listeningAddress: URL, timeout: Int, asSystem: Bool, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentConnection {	
		return try CakeAgentConnection(eventLoop: on, listeningAddress: listeningAddress, timeout: Int64(timeout), retries: retries)
	}
}
