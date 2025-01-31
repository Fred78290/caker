import Foundation
import CakeAgentLib
import NIOCore
import NIOPosix
import NIOSSL
import GRPC
import GRPCLib
import Logging
import CakeAgentLib

class Queue<T> {
	/// A concurrent queue to allow multiple reads at once.
	private var queue = DispatchQueue(label: "chicken.feeder.queue.\(randomUUID())", attributes: .concurrent)
	private var elements: [T] = []
	private var isClosed = false

	func push(_ element: T) {
		queue.sync {
			elements.append(element)
		}
	}

	func pop() -> T? {
		guard !isClosed else { return nil }

		return queue.sync {
			return elements.isEmpty ? nil : elements.removeFirst()
		}
	}

	private static func randomUUID() -> String {
		UUID().uuidString
	}
}

extension Queue: AsyncSequence, AsyncIteratorProtocol {
	func next() async -> T? {
		self.pop()
	}

	nonisolated func makeAsyncIterator() -> Queue<T> {
		self
	}
}

struct CakeAgentConnection {
	let caCert: String?
	let tlsCert: String?
	let tlsKey: String?
	let eventLoop: EventLoopGroup
	let listeningAddress: URL
	let timeout: Int64 = 10

	init(eventLoop: EventLoopGroup, listeningAddress: URL, caCert: String?, tlsCert: String?, tlsKey: String?) {
		self.caCert = caCert
		self.tlsCert = tlsCert
		self.tlsKey = tlsKey
		self.eventLoop = eventLoop
		self.listeningAddress = listeningAddress
	}

	func createClient() throws -> CakeAgentClient {
		return try CakeAgentHelper.createClient(on: self.eventLoop,
		                                        listeningAddress: self.listeningAddress,
		                                        connectionTimeout: self.timeout,
		                                        caCert: self.caCert,
		                                        tlsCert: self.tlsCert,
		                                        tlsKey: self.tlsKey)
	}

	func info(context: GRPCAsyncServerCallContext) async throws -> Caked_InfoReply {
		let client = try createClient()

		do {
			let response = try await client.info(.init()).response.get()

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

			try! await client.close()

			return reply
		} catch {
			try! await client.close()
			throw error
		}
	}

	func execute(request: Caked_ExecuteRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_ExecuteReply {
		let client = try createClient()

		do {
			let response = try await client.execute(Cakeagent_ExecuteRequest.with { req in
				if request.hasInput {
					req.input = Data(request.input)
				}

				req.command = request.command
				req.args = request.args
			}).response.get()

			try! await client.close()

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
			try! await client.close()
			throw error
		}
	}

	func shell(requestStream: GRPCAsyncRequestStream<Caked_ShellRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ShellResponse>, context: GRPCAsyncServerCallContext) async throws {
		let shellQueue = Queue<Caked_ShellResponse>()
		let client = try createClient()
		let result: [Error?]

		do {

			let streamShell = client.shell(callOptions: .init(), handler: { response in
				shellQueue.push(Caked_ShellResponse.with { reply in
					reply.format = .init(rawValue: response.format.rawValue) ?? .end
					reply.datas = response.datas
				})
			})

			result = await withTaskGroup(of: Error?.self, returning: [Error?].self) { group in
				var lastError: [Error?] = []

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
								Logging.Logger(label: "CakeAgentConnection").error("Error reading from shell, \(error)")
								return error
							}
						}
					}

					return nil
				}

				group.addTask {
					do {
						for try await message in shellQueue {
							try await responseStream.send(message)
						}
					} catch {
						if error is CancellationError == false {
							guard let err = error as? ChannelError, err == ChannelError.ioOnClosedChannel else {
								Logging.Logger(label: "CakeAgentConnection").error("Error reading from shell, \(error)")
								return error
							}
						}
					}

					return nil
				}

				for await result in group {
					if let error = result {
						lastError.append(error)
					}
				}

				return lastError
			}

			try await responseStream.send(Caked_ShellResponse.with { $0.format = .end })

			try! await client.close()
		}
		catch {
			try await responseStream.send(Caked_ShellResponse.with { $0.format = .end })
			try! await client.close()
			throw error
		}

		if let error = result.first(where: { $0 != nil }) {
			throw error!
		}
	}

}
