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

	init(eventLoop: EventLoopGroup, listeningAddress: URL, caCert: String?, tlsCert: String?, tlsKey: String?, timeout: Int64 = 10, retries: ConnectionBackoff.Retries = .unlimited) {	// swiftlint:disable:this function_parameter_count
		self.caCert = caCert
		self.tlsCert = tlsCert
		self.tlsKey = tlsKey
		self.eventLoop = eventLoop
		self.timeout = timeout
		self.listeningAddress = listeningAddress
		self.retries = retries
	}

	init(eventLoop: EventLoopGroup, listeningAddress: URL, certLocation: CertificatesLocation, timeout: Int64 = 10, retries: ConnectionBackoff.Retries = .unlimited) {
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

			try? client.closeSync()

			return reply
		} catch {
			try? client.closeSync()
			throw error
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

			try? client.closeSync()

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
			try! client.closeSync()
			throw error
		}
	}

	func shell(requestStream: GRPCAsyncRequestStream<Caked_ShellRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ShellResponse>) async throws {
		let (stream, continuation) = AsyncStream.makeStream(of: Caked_ShellResponse.self)
		let client = try createClient()
		let finish = {
			continuation.finish()
			try? await responseStream.send(Caked_ShellResponse.with { $0.format = .end })
			try? client.closeSync()
		}

		do {

			let streamShell = client.shell(callOptions: .init(), handler: { response in
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

}
