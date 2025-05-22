import Foundation
import GRPCLib
import CakeAgentLib
import NIOPortForwarding
import NIOCore
import GRPC
import Network

extension CakeAgent.TunnelMessage.TunnelProtocol {
	public var description: String {
		switch self {
		case .tcp: return "tcp"
		case .udp: return "udp"
		case .UNRECOGNIZED: return "unknown"
		}
	}
}

extension SocketAddress {
	var isLoopback: Bool {
		if let addr = self.ipAddress {
			switch self.protocol {
			case .inet:
				return Network.IPv4Address(addr)?.isLoopback ?? false
			case .inet6:
				return Network.IPv6Address(addr)?.isLoopback ?? false
			default:
				return false
			}
		}

		return false
	}

	var isLinkLocal: Bool {
		if let addr = self.ipAddress {
			switch self.protocol {
			case .inet:
				return Network.IPv4Address(addr)?.isLinkLocal ?? false
			case .inet6:
				return Network.IPv6Address(addr)?.isLinkLocal ?? false
			default:
				return false
			}
		}

		return false
	}

	var isMulticast: Bool {
		if let addr = self.ipAddress {
			switch self.protocol {
			case .inet:
				return Network.IPv4Address(addr)?.isMulticast ?? false
			case .inet6:
				return Network.IPv6Address(addr)?.isMulticast ?? false
			default:
				return false
			}
		}

		return false
	}

	var isAny: Bool {
		if let addr = self.ipAddress {
			switch self.protocol {
			case .inet:
				return Network.IPv4Address(addr) == .any
			case .inet6:
				return Network.IPv6Address(addr) == .any
			default:
				return false
			}
		}

		return false
	}

}

struct ForwardedSocketAddress: Sendable, Equatable, CustomStringConvertible {
	var description: String {
		"\(proto.rawValue)://\(addr):\(port)"
	}

	let proto: MappedPort.Proto
	let addr: String
	let port: Int

	static func == (lhs: ForwardedSocketAddress, rhs: ForwardedSocketAddress) -> Bool {
		return lhs.proto == rhs.proto && lhs.addr == rhs.addr && lhs.port == rhs.port
	}

	init(proto: CakeAgent.TunnelMessage.TunnelProtocol, addr: String, port: Int) {
		self.proto = proto == .tcp ? .tcp : .udp
		self.addr = addr
		self.port = port
	}
}

class CakedPortForwarder: PortForwarder, @unchecked Sendable {
	internal let forwardedPorts: [TunnelAttachement]
	internal let cakeAgentClient: CakeAgentClient
	internal let listeningAddress: URL
	internal let asSystem: Bool
	internal let bindAddress: [String]
	internal let ttl: Int
	internal var dynamicPorts: [ForwardedSocketAddress] = []
	internal let log: Logger
	internal var eventStream: ServerStreamingCall<Cakeagent_CakeAgent.Empty, CakeAgent.TunnelPortForwardEvent>? = nil
	internal var eventChannel: Channel? = nil
	internal let queue = DispatchQueue(label: "CakedPortForwarder")
	internal var status: Status = .idle

	enum Status: Int {
		case idle = 0
		case starting = 1
		case started = 2
		case stopping = 3
		case stopped = 4
	}

	init(group: EventLoopGroup, remoteHost: String, bindAddress: [String], forwardedPorts: [TunnelAttachement], ttl: Int = 5, listeningAddress: URL, asSystem: Bool) throws {
		let mappedPorts = forwardedPorts.filter { $0.unixDomain == nil }.compactMap{ $0.mappedPort }

		self.bindAddress = bindAddress
		self.ttl = ttl
		self.asSystem = asSystem
		self.listeningAddress = listeningAddress
		self.forwardedPorts = forwardedPorts
		self.cakeAgentClient = try CakeAgentConnection.createCakeAgentClient(on: group.next(), listeningAddress: listeningAddress, timeout: 5, asSystem: asSystem)
		self.log = Logger("CakedPortForwarder")

		try super.init(group: group, remoteHost: remoteHost, mappedPorts: mappedPorts, bindAddresses: bindAddress, udpConnectionTTL: ttl)

		try forwardedPorts.forEach { forwarded in
			if let unixDomain = forwarded.unixDomain {
				_ = try self.addPortForwardingServer(bindAddress: SocketAddress(unixDomainSocketPath: unixDomain.host.expandingTildeInPath, cleanupExistingSocketFile: true), remoteAddress: SocketAddress(unixDomainSocketPath: unixDomain.guest), proto: unixDomain.proto, ttl: ttl)
			}
		}
	}

	func handleEvent(event: CakeAgent.TunnelPortForwardEvent.ForwardEvent) {
		let discardedPort: [Int32] = [ 22, 53, 68 ]
		let addedPorts = event.addedPorts.reduce(into: [ForwardedSocketAddress]()) { addedPorts, port in
			if let remoteAddress = try? SocketAddress(ipAddress: port.ip, port: Int(port.port)) {
				let forward = ForwardedSocketAddress(proto: port.protocol, addr: port.ip, port: Int(port.port))

				if discardedPort.contains(port.port) {
					self.log.info("Discard dynamic port forwarding: \(forward.description) (discarded port)")
				} else  if addedPorts.first(where: { $0.port == port.port && $0.addr == port.ip }) != nil {
					self.log.info("Already binded dynamic port forwarding: \(forward.description)")
				} else {
					if remoteAddress.isLoopback || remoteAddress.isLinkLocal {
						self.log.info("Discard dynamic port forwarding: \(forward.description) (loopback/link local)")
					} else {
						addedPorts.append(forward)

						self.log.info("Candidate dynamic port forwarding: \(forward.description)")
					}
				}
			} else {
				self.log.warn("Invalid dynamic port forwarding: \(port.ip):\(port.port)")
			}
		}

		addedPorts.forEach { forward in
			self.bindAddress.forEach { bindAddress in
				let bindAddress: SocketAddress = try! SocketAddress.makeAddress("tcp://\(bindAddress):\(forward.port)")
				let remoteAddress = try! SocketAddress(ipAddress: forward.addr, port: forward.port)

				if bindAddress.protocol == remoteAddress.protocol {
					self.log.info("Add dynamic port forwarding: \(bindAddress) -> \(remoteAddress)")

					do {
						if try self.addPortForwardingServer(bindAddress: bindAddress, remoteAddress: remoteAddress, proto: forward.proto, ttl: self.ttl).isEmpty {
							self.log.info("Failed to add dynamic port forwarding: \(forward.description)")
						} else {
							self.log.info("Added dynamic port forwarding: \(forward.description)")
							self.dynamicPorts.append(forward)
						}
					} catch {
						self.log.error("Failed to add dynamic port forwarding: \(forward.description), error: \(error)")
					}
				}
			}
		}

		let removedPorts = event.removedPorts.compactMap { port in
			if discardedPort.contains(port.port) == false {
				let forward: ForwardedSocketAddress = ForwardedSocketAddress(proto: port.protocol, addr: port.ip, port: Int(port.port))

				if self.dynamicPorts.contains(forward) {
					self.log.info("Will remove dynamic port forwarding: \(forward.description)")
					return forward
				}

				self.log.info("To be removed dynamic port forwarding not found: \(forward.description)")
			}

			return nil
		}

		removedPorts.forEach { port in
			self.bindAddress.forEach { bindAddress in
				let bindAddress = try! SocketAddress.makeAddress("tcp://\(bindAddress):\(port.port)")
				let remoteAddress = try! SocketAddress(ipAddress: port.addr, port: port.port)

				if bindAddress.protocol == remoteAddress.protocol {
					self.log.info("Will remove dynamic port forwarding: \(port.description)")

					if let _ = try? self.removePortForwardingServer(bindAddress: bindAddress, remoteAddress: remoteAddress, proto: port.proto, ttl: self.ttl) {
						self.log.info("Remove dynamic port forwarding: \(port.description)")

						self.dynamicPorts.removeAll {
							$0 == port
						}

						return
					}

					self.log.info("Didn't remove dynamic port forwarding: \(port.description)")
				}
			}
		}
	}

	func removeDynamicPortForwarding() throws {
		self.log.info("Remove dynamic port forwarding")

		defer {
			self.dynamicPorts.removeAll()
		}

		try self.dynamicPorts.forEach { forward in
			try self.bindAddress.forEach { bindAddress in
				let bindAddress = try! SocketAddress.makeAddress("tcp://\(bindAddress):\(forward.port)")
				let remoteAddress = try! SocketAddress(ipAddress: forward.addr, port: forward.port)

				if bindAddress.protocol == remoteAddress.protocol {
					self.log.info("Remove dynamic port forwarding: \(bindAddress) -> \(remoteAddress)")

					do {
						try self.removePortForwardingServer(bindAddress: bindAddress, remoteAddress: remoteAddress, proto: forward.proto, ttl: self.ttl)
					} catch (PortForwardingError.alreadyBinded(let error)) {
						Logger(self).error(error)
					}
				}
			}
		}
	}

	func startDynamicPortForwarding() throws {
		log.info("Start dynamic port forwarding")

		self.status = .starting

		let stream = self.cakeAgentClient.events(.init(), callOptions: .init(timeLimit: .none)) { event in
			self.queue.async {
				if case let .forwardEvent(event) = event.event {
					self.handleEvent(event: event)
				} else if case let .error(error) = event.event {
					self.log.error("Event error: \(error)")

					//	throw error
					if let subchannel = self.eventChannel {
						subchannel.pipeline.fireErrorCaught(GRPCStatus(code: .internalError, message: error))
					}
				}
			}
		}

		stream.status.whenComplete { result in
			self.queue.sync {
				switch result {
				case .failure(let err):
					Logger(self).error("Dynamic port forwarding stream receive failure: \(err)")
				case .success(let status):
					if status.code != .ok {
						if status.code == .unavailable {
							self.disconnected()
						} else {
							Logger(self).error("Dynamic port forwarding stream status: \(status)")
							self.eventChannel?.close(promise: nil)
						}
					} else {
						Logger(self).info("Dynamic port forwarding stream receive success: \(status)")
					}
				}
			}
		}

		self.eventStream = stream

		_ = stream.subchannel.flatMap { channel in
			self.eventChannel = channel
			self.status = .started

			self.log.info("Started dynamic port forwarding")

			return channel.eventLoop.makeSucceededVoidFuture()
		}
	}

	override func createTCPPortForwardingServer(on: EventLoop, bindAddress: SocketAddress, remoteAddress: SocketAddress) throws -> any PortForwarding {
		if remoteAddress.protocol == .unix {
			return CakedTCPPortForwardingServer(on: on, bindAddress: bindAddress, remoteAddress: remoteAddress, cakeAgentClient: cakeAgentClient)
		}

		return try super.createTCPPortForwardingServer(on: on, bindAddress: bindAddress, remoteAddress: remoteAddress)
	}

	override func createUDPPortForwardingServer(on: EventLoop, bindAddress: SocketAddress, remoteAddress: SocketAddress, ttl: Int) throws -> any PortForwarding {
		if remoteAddress.protocol == .unix {
			return CakedUDPPortForwardingServer(on: on, bindAddress: bindAddress, remoteAddress: remoteAddress, ttl: ttl, cakeAgentClient: cakeAgentClient)
		}

		return try super.createUDPPortForwardingServer(on: on, bindAddress: bindAddress, remoteAddress: remoteAddress, ttl: ttl)
	}

	func close() throws {
		if let subchannel = self.eventChannel {
			let promise = subchannel.eventLoop.makePromise(of: Void.self)

			promise.futureResult.whenComplete { _ in
				self.eventChannel = nil
				self.eventStream = nil
				self.log.info("Event channel closed")
			}

			subchannel.close(promise: promise)
		}

		try self.syncShutdownGracefully()
	}

	func disconnected() {
		Logger(self).info("Dynamic port forwarding stream disconnected")
		self.status = .stopping

		try? self.removeDynamicPortForwarding()

		if let subchannel = self.eventChannel {
			let promise = subchannel.eventLoop.makePromise(of : Void.self)

			promise.futureResult.whenComplete { _ in
				self.status = .stopped
				self.eventChannel = nil
				self.eventStream = nil

				self.log.info("Event channel closed")
			}

			self.close(promise: promise)
		} else {
			self.status = .stopped
			self.eventStream = nil
			self.log.info("Event channel already closed")
		}
	}
}
