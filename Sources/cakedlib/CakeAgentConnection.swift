import Atomics
import CakeAgentLib
import Foundation
@preconcurrency import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import NIOSSL
import SwiftProtobuf
import SwiftUI

extension Caked_RunReply {
	private func print(_ out: Data, err: Bool) {
		let output = String(data: out, encoding: .utf8) ?? ""
		let lines = output.split(separator: "\n")

		for line in lines {
			if err {
				Logger(self).error(String(line))
			} else {
				Logger(self).info(String(line))
			}
		}
	}

	public func log() {
		if self.stderr.isEmpty == false {
			self.print(self.stderr, err: true)
		}

		if self.stdout.isEmpty == false {
			self.print(self.stdout, err: false)
		}
	}
}

extension Cakeagent_CakeAgent.InfoReply.CpuCoreInfo {
	var caked: Caked.CpuCoreInfo {
		.with {
			$0.coreID = self.coreID
			$0.usagePercent = self.usagePercent
			$0.user = self.user
			$0.system = self.system
			$0.idle = self.idle
			$0.iowait = self.iowait
			$0.irq = self.irq
			$0.softirq = self.softirq
			$0.steal = self.steal
			$0.guest = self.guest
			$0.guestNice = self.guestNice
		}
	}
}

extension Cakeagent_CakeAgent.InfoReply.CpuInfo {
	var caked: Caked.CpuInfo {
		.with {
			$0.totalUsagePercent = self.totalUsagePercent
			$0.user = self.user
			$0.system = self.system
			$0.idle = self.idle
			$0.iowait = self.iowait
			$0.steal = self.steal
			$0.irq = self.irq
			$0.softirq = self.softirq
			$0.guest = self.guest
			$0.guestNice = self.guestNice
			$0.cores = self.cores.map(\.caked)
		}
	}
}

extension Cakeagent_CakeAgent.InfoReply.DiskInfo {
	var caked: Caked_InfoReply.DiskInfo {
		.with {
			$0.device = self.device
			$0.mount = self.mount
			$0.fsType = self.fsType
			$0.size = self.size
			$0.used = self.used
			$0.free = self.free
		}
	}
}

extension Cakeagent_CakeAgent.InfoReply {
	var caked: Caked_InfoReply {
		.with {
			$0.version = self.version
			$0.uptime = self.uptime
			$0.cpuCount = self.cpuCount
			$0.ipaddresses = self.ipaddresses
			$0.osname = self.osname
			$0.release = self.release
			$0.diskInfos = self.diskInfos.map(\.caked)

			if self.hasCpu {
				let cpu = self.cpu

				$0.cpu = cpu.caked
			}

			if self.hasMemory {
				let mem = self.memory
				$0.memory = .with { memory in
					memory.total = mem.total
					memory.free = mem.free
					memory.used = mem.used
				}
			}
		}
	}
}

extension Caked_ExecuteResponse {
	init(_ from: CakeAgent.ExecuteResponse) {
		self = Caked_ExecuteResponse.with { reply in
			switch from.response {
			case .exitCode(let exitCode):
				reply.exitCode = exitCode
			case .stdout(let stdout):
				reply.stdout = stdout
			case .stderr(let stderr):
				reply.stderr = stderr
			case .established:
				reply.established = .with {
					$0.success = true
					$0.reason = "Established"
				}
			case .none:
				break
			}
		}
	}
}

extension CakeAgent.ExecuteRequest {
	init(_ from: Caked_ExecuteRequest) {
		self = CakeAgent.ExecuteRequest.with { msg in
			switch from.execute {
			   case .command(let command):
				   msg.command = CakeAgent.ExecuteRequest.ExecuteCommand.with { cmd in
					   switch command.execute {
					   case .shell:
						   cmd.shell = true
					   case .command(let execute):
						   cmd.command = CakeAgent.ExecuteRequest.ExecuteCommand.Command.with { cmd in
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
				   msg.size = CakeAgent.ExecuteRequest.TerminalSize.with { termSize in
					   termSize.cols = size.cols
					   termSize.rows = size.rows
				   }
			   case .eof(let eof):
				   msg.eof = eof
			   case .none:
				   break
			   }
		   }
	}
}

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

	public func info(callOptions: CallOptions? = nil) -> EventLoopFuture<Result<Caked_InfoReply, Error>> {
		let response = self.info(.init(), callOptions: callOptions).response

		return response.flatMapThrowing { response in
			return .success(response.caked)
		}.flatMapErrorWithEventLoop { error, eventLoop in
			Self.log(error)

			return eventLoop.submit {
				return .failure(error)
			}
		}
	}

	public func info(callOptions: CallOptions? = nil) throws -> Caked_InfoReply {
		let response = try self.info(callOptions: callOptions).wait()

		switch response {
		case .success(let reply):
			return reply
		case .failure(let error):
			throw error
		}
	}

	public func run(request: Caked_RunCommand, callOptions: CallOptions? = nil) -> EventLoopFuture<Result<Caked_RunReply, Error>> {
		let response = self.run(
			CakeAgent.RunCommand.with { req in
				req.input = request.input
				req.command = CakeAgent.RunCommand.Command.with {
					$0.command = request.command
					$0.args = request.args
				}
			}, callOptions: callOptions
		).response

		return response.flatMapThrowing { response in
			return .success(
				Caked_RunReply.with { reply in
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

	public func run(request: Caked_RunCommand, callOptions: CallOptions? = nil) throws -> Caked_RunReply {
		let response = try self.run(request: request, callOptions: callOptions).wait()

		switch response {
		case .success(let reply):
			return reply
		case .failure(let error):
			throw error
		}
	}

	public func mount(request: Caked_MountRequest, callOptions: CallOptions? = nil) throws -> Caked_MountReply {
		let response: CakeAgent.MountReply = try self.mount(
			CakeAgent.MountRequest.with {
				$0.mounts = request.mounts.map { option in
					CakeAgent.MountRequest.MountVirtioFS.with {
						$0.uid = option.uid
						$0.gid = option.gid
						$0.name = option.name
						$0.target = option.target
					}
				}
			}, callOptions: callOptions
		).response.wait()

		return try Caked_MountReply.with { reply in
			if case CakeAgent.MountReply.OneOf_Response.error(let v)? = response.response {
				throw ServiceError(LocalizedStringKey(stringLiteral: v))
			} else {
				reply.mounts = response.mounts.map { mount in
					Caked_MountVirtioFSReply.with {
						$0.name = mount.name

						if case CakeAgent.MountReply.MountVirtioFSReply.OneOf_Response.error(let v)? = mount.response {
							$0.reason = v
							$0.mounted = false
						} else if case CakeAgent.MountReply.MountVirtioFSReply.OneOf_Response.success(_)? = mount.response {
							$0.mounted = true
						}
					}
				}
			}
		}
	}

	public func umount(request: Caked_MountRequest, callOptions: CallOptions? = nil) throws -> Caked_MountReply {
		let response: CakeAgent.MountReply = try self.umount(
			CakeAgent.MountRequest.with {
				$0.mounts = request.mounts.map { option in
					CakeAgent.MountRequest.MountVirtioFS.with {
						$0.uid = option.uid
						$0.gid = option.gid
						$0.name = option.name
						$0.target = option.target
					}
				}
			}, callOptions: callOptions
		).response.wait()

		return try Caked_MountReply.with { reply in
			if case CakeAgent.MountReply.OneOf_Response.error(let v)? = response.response {
				throw ServiceError(LocalizedStringKey(stringLiteral: v))
			} else {
				reply.mounts = response.mounts.map { mount in
					Caked_MountVirtioFSReply.with {
						$0.name = mount.name

						if case CakeAgent.MountReply.MountVirtioFSReply.OneOf_Response.error(let v)? = mount.response {
							$0.reason = v
						} else if case CakeAgent.MountReply.MountVirtioFSReply.OneOf_Response.success(let v)? = mount.response {
							$0.mounted = v
						}
					}
				}
			}
		}
	}
}

public final class CakeAgentConnection: Sendable {
	let caCert: String?
	let tlsCert: String?
	let tlsKey: String?
	let eventLoop: EventLoopGroup
	let listeningAddress: URL
	let timeout: Int64
	let retries: ConnectionBackoff.Retries
	let logger = Logger("CakeAgentConnection")

	public convenience init(eventLoop: EventLoopGroup, listeningAddress: URL, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited, runMode: Utils.RunMode) throws {
		let certLocation = try CertificatesLocation.createAgentCertificats(runMode: runMode)

		self.init(eventLoop: eventLoop, listeningAddress: listeningAddress, certLocation: certLocation, timeout: timeout, retries: retries)
	}

	public init(eventLoop: EventLoopGroup, listeningAddress: URL, caCert: String?, tlsCert: String?, tlsKey: String?, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited) {  // swiftlint:disable:this function_parameter_count
		self.caCert = caCert
		self.tlsCert = tlsCert
		self.tlsKey = tlsKey
		self.eventLoop = eventLoop
		self.timeout = timeout
		self.listeningAddress = listeningAddress
		self.retries = retries
	}

	public convenience init(eventLoop: EventLoopGroup, listeningAddress: URL, certLocation: CertificatesLocation, timeout: Int64 = 60, retries: ConnectionBackoff.Retries = .unlimited) {
		self.init(
			eventLoop: eventLoop,
			listeningAddress: listeningAddress,
			caCert: certLocation.caCertURL.path,
			tlsCert: certLocation.clientCertURL.path,
			tlsKey: certLocation.clientKeyURL.path,
			timeout: timeout,
			retries: retries)
	}

	public func createClient(interceptors: CakeAgentServiceClientInterceptorFactoryProtocol? = nil) throws -> CakeAgentClient {
		return try CakeAgentHelper.createClient(
			on: self.eventLoop,
			listeningAddress: self.listeningAddress,
			connectionTimeout: self.timeout,
			caCert: self.caCert,
			tlsCert: self.tlsCert,
			tlsKey: self.tlsKey,
			retries: self.retries,
			interceptors: interceptors)

	}

	public func info(callOptions: CallOptions? = nil) throws -> EventLoopFuture<Result<Caked_InfoReply, Error>> {
		let client = try createClient()
		let response: EventLoopFuture<Result<Caked_InfoReply, Error>> = client.info(callOptions: callOptions)

		response.whenComplete { _ in
			client.close(promise: response.eventLoop.makePromise(of: Void.self))
		}

		return response
	}

	public func info(callOptions: CallOptions? = nil) throws -> Caked_InfoReply {
		let response = try self.info(callOptions: callOptions).wait()

		switch response {
		case .success(let reply):
			return reply
		case .failure(let error):
			throw error
		}
	}

	public func shutdown(callOptions: CallOptions? = nil) throws -> Caked_RunReply {
		let client = try createClient()

		defer {
			try? client.close().wait()
		}

		let response = try client.shutdown(.init(), callOptions: callOptions).response.wait()

		return Caked_RunReply.with { reply in
			reply.exitCode = response.exitCode

			if response.stderr.isEmpty == false {
				reply.stderr = response.stderr
			}

			if response.stdout.isEmpty == false {
				reply.stdout = response.stdout
			}
		}
	}

	public func run(command: String, arguments: [String] = [], input: Data? = nil, callOptions: CallOptions? = nil) throws -> Caked_RunReply {
		let client = try createClient()

		defer {
			try? client.close().wait()
		}

		let response = try client.run(
			CakeAgent.RunCommand.with { req in
				if let data = input {
					req.input = data
				}

				req.command = CakeAgent.RunCommand.Command.with {
					$0.command = command
					$0.args = arguments
				}
			}, callOptions: callOptions
		).response.wait()

		return Caked_RunReply.with { reply in
			reply.exitCode = response.exitCode

			if response.stderr.isEmpty == false {
				reply.stderr = response.stderr
			}

			if response.stdout.isEmpty == false {
				reply.stdout = response.stdout
			}
		}
	}

	public func run(request: Caked_RunCommand, callOptions: CallOptions? = nil) throws -> Caked_RunReply {
		try self.run(command: String(request.command), arguments: request.args, input: request.input, callOptions: callOptions)
	}

	public func execute(requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>) async throws {
		struct Message {
			
		}
		let (stream, continuation) = AsyncThrowingStream.makeStream(of: Caked_ExecuteResponse.self)
		let interceptor = CakeAgentClientInterceptorFactory(responseStream: responseStream)
		let client = try createClient(interceptors: interceptor)
		var exitCodeSent = false
		
		func finish() async {
			#if DEBUG
			self.logger.debug("Finish shell")
			#endif
			continuation.finish()
			try? await client.close()
		}

		func handleFailure(_ error: Error) -> Bool {
			continuation.finish(throwing: error)

			if error is CancellationError == false && error is GRPCError.AlreadyComplete == false {
				if interceptor.errorCaught.load() == nil {
					self.logger.error(error)
					_ = interceptor.errorCaught.storeIfNilThenLoad(.init(error: error))
					return true
				}
			}

			return false
		}

		do {
			let streamShell = client.execute(callOptions: .init(timeLimit: .none), handler: { response in
				#if DEBUG
				self.logger.debug("Receive from agent: \(response)")
				#endif

				if case .exitCode = response.response {
					exitCodeSent = true
				}

				continuation.yield(.init(response))
			})

			defer {
				#if DEBUG
				self.logger.debug("Send end to agent")
				#endif
				streamShell.sendEnd(promise: nil)
			}

			try await withThrowingTaskGroup(of: Void.self, returning: Void.self) { group in
				group.addTask {
					#if DEBUG
					var count = 0

					self.logger.debug("Entering forward from client to agent")
					#endif

					do {
						for try await message in requestStream {
							#if DEBUG
							let msgID = count

							count += 1
							self.logger.debug("[\(msgID)] Forward message from client to agent: \(message)")
							#endif

							streamShell.sendMessage(.init(message)).whenComplete { result in
								switch result {
								case .success():
									#if DEBUG
									self.logger.debug("[\(msgID)] Forwarded message from client to agent: \(message)")
									#endif
									break
								case .failure(let error):
									#if DEBUG
									self.logger.debug("[\(msgID)] Failed message from client to agent: \(message), \(error)")
									#endif
									break
								}
							}
						}
					} catch {
						self.logger.error("Error forward task from client to agent: \(error)")

						if handleFailure(error) {
							try? await responseStream.send(.with {
								$0.established = .with {
									$0.success = false
									$0.reason = error.localizedDescription
								}
							})
						}
					}

					#if DEBUG
					self.logger.debug("Leave forward from client to agent")
					#endif
				}

				group.addTask {
					#if DEBUG
					self.logger.debug("Entering forward from agent to client")
					#endif

					do {
						for try await message in stream {
							#if DEBUG
							self.logger.debug("Forward message from agent to client: \(message)")
							#endif

							try await responseStream.send(message)

							#if DEBUG
							self.logger.debug("Done message from agent to client: \(message)")
							#endif

							if case .exitCode = message.response {
								break
							}
						}
					} catch {
						self.logger.error("Error forward from agent to client: \(error)")

						if handleFailure(error) {
							try? await responseStream.send(.with {
								$0.established = .with {
									$0.success = false
									$0.reason = error.localizedDescription
								}
							})
						}
					}

					#if DEBUG
					self.logger.debug("Leave forward from agent to client")
					#endif
				}

				try await group.waitForAll()

				
				if interceptor.errorCaught.load() == nil && exitCodeSent == false {
					try? await responseStream.send(.with {
						$0.established = .with {
							$0.success = false
							$0.reason = "Canceled"
						}
					})
				}

				await finish()
			}

			self.logger.debug("Leave shell")

		} catch {
			self.logger.debug("Leave shell on error: \(error)")

			try? await responseStream.send(.with {
				$0.established = .with {
					$0.success = false
					$0.reason = error.localizedDescription
				}
			})

			await finish()
			throw error
		}
	}

	public func mount(request: Caked_MountRequest, callOptions: CallOptions? = nil) throws -> Caked_MountReply {
		let client = try createClient()

		defer {
			try? client.close().wait()
		}

		return try client.mount(request: request, callOptions: callOptions)
	}

	public func umount(request: Caked_MountRequest, callOptions: CallOptions? = nil) throws -> Caked_MountReply {
		let client = try createClient()

		defer {
			try? client.close().wait()
		}

		return try client.umount(request: request, callOptions: callOptions)
	}

	public static func createCakeAgentConnection(on: EventLoop, listeningAddress: URL, timeout: Int, runMode: Utils.RunMode, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentConnection {
		return try CakeAgentConnection(eventLoop: on, listeningAddress: listeningAddress, timeout: Int64(timeout), retries: retries, runMode: runMode)
	}

	public static func createCakeAgentClient(on: EventLoop, listeningAddress: URL, timeout: Int, runMode: Utils.RunMode, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentClient {
		let certLocation = try CertificatesLocation.createAgentCertificats(runMode: runMode)

		return try CakeAgentHelper.createClient(
			on: on,
			listeningAddress: listeningAddress,
			connectionTimeout: Int64(timeout),
			caCert: certLocation.caCertURL.path,
			tlsCert: certLocation.clientCertURL.path,
			tlsKey: certLocation.clientKeyURL.path,
			retries: retries)
	}
}
