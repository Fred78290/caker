import CakeAgentLib
import Darwin
import Foundation
import NIOCore
import NIOPosix
import Synchronization

/// The protocol logic of the DHCP server of one network, with no socket in it: a request message in, the reply
/// message (if any) out. `DHCPServer` puts it on the wire.
public final class DHCPResponder: Sendable {
	public struct Configuration: Sendable {
		/// The gateway: server identifier, router and (for the compose resolver) DNS server.
		public let gateway: UInt32
		public let netmask: UInt32
		public let dnsServers: [UInt32]
		public let domainName: String?

		public init(gateway: UInt32, netmask: UInt32, dnsServers: [UInt32], domainName: String?) {
			self.gateway = gateway
			self.netmask = netmask
			self.dnsServers = dnsServers
			self.domainName = domainName
		}

		var broadcast: UInt32 {
			(gateway & netmask) | ~netmask
		}
	}

	public let configuration: Configuration
	public let store: DHCPLeaseStore
	private let logger = Logger("DHCPResponder")

	public init(configuration: Configuration, store: DHCPLeaseStore) {
		self.configuration = configuration
		self.store = store
	}

	public func respond(to request: DHCPMessage) -> DHCPMessage? {
		guard request.op == 1, request.hardwareType == 1, request.clientHardwareAddress.count == 6, let type = request.messageType else {
			return nil
		}

		let key = request.hwAddressKey

		switch type {
		case .discover:
			guard let address = self.store.offer(hwAddress: key, requested: request.requestedAddress) else {
				self.logger.warn("DHCP pool exhausted, no address for \(key)")
				return nil
			}

			self.logger.debug("DHCPOFFER \(DHCPAddress.string(address)) to \(key)")

			return self.reply(.offer, to: request, address: address)

		case .request:
			// The client picked another server's offer: forget ours.
			if let server = request.serverIdentifier, server != self.configuration.gateway {
				self.store.release(hwAddress: key)
				return nil
			}

			// SELECTING/INIT-REBOOT carry option 50, RENEWING/REBINDING carry ciaddr.
			guard let address = request.requestedAddress ?? (request.ciaddr != 0 ? request.ciaddr : nil) else {
				return nil
			}

			guard self.store.commit(hwAddress: key, address: address, hostname: request.hostname) else {
				self.logger.debug("DHCPNAK \(DHCPAddress.string(address)) to \(key)")
				return self.reply(.nak, to: request, address: 0, message: "requested address not available")
			}

			self.logger.debug("DHCPACK \(DHCPAddress.string(address)) to \(key)")

			return self.reply(.ack, to: request, address: address)

		case .release:
			self.store.release(hwAddress: key)
			return nil

		case .decline:
			if let address = request.requestedAddress {
				self.store.decline(hwAddress: key, address: address)
			}

			return nil

		default:
			return nil
		}
	}

	private func reply(_ type: DHCPMessage.MessageType, to request: DHCPMessage, address: UInt32, message: String? = nil) -> DHCPMessage {
		var reply = DHCPMessage(op: 2, hardwareType: request.hardwareType, xid: request.xid, flags: request.flags, ciaddr: type == .ack ? request.ciaddr : 0, yiaddr: address, siaddr: type == .nak ? 0 : self.configuration.gateway, giaddr: request.giaddr, clientHardwareAddress: request.clientHardwareAddress, messageType: type)

		reply.serverIdentifier = self.configuration.gateway
		reply.message = message

		if type != .nak {
			let lease = UInt32(min(self.store.leaseTime, Double(UInt32.max)))

			reply.leaseTime = lease
			reply.renewalTime = lease / 2
			reply.rebindingTime = UInt32(UInt64(lease) * 7 / 8)
			reply.subnetMask = self.configuration.netmask
			reply.broadcastAddress = self.configuration.broadcast
			reply.routers = [self.configuration.gateway]
			reply.dnsServers = self.configuration.dnsServers
			reply.domainName = self.configuration.domainName
		}

		return reply
	}
}

public enum DHCPServerError: Error, CustomStringConvertible {
	case interfaceNotFound(String)
	case socket(String)

	public var description: String {
		switch self {
		case .interfaceNotFound(let address):
			return "No network interface has the address \(address)"
		case .socket(let reason):
			return "DHCP socket error: \(reason)"
		}
	}
}

/// Channel handler: decode, ask the responder, send the answer back.
final class DHCPInboundHandler: ChannelInboundHandler {
	typealias InboundIn = AddressedEnvelope<ByteBuffer>
	typealias OutboundOut = AddressedEnvelope<ByteBuffer>

	private let responder: DHCPResponder
	private let logger = Logger("DHCPServer")

	init(responder: DHCPResponder) {
		self.responder = responder
	}

	func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		var buffer = self.unwrapInboundIn(data).data

		guard let bytes = buffer.readBytes(length: buffer.readableBytes), let request = try? DHCPMessage.parse(bytes), let reply = self.responder.respond(to: request) else {
			return
		}

		// Sent to the limited broadcast address on the bound interface: the client has no address yet, so unicast
		// would need an ARP entry for it. A renewing client (ciaddr set) can be answered directly.
		let destinationAddress = reply.messageType != .nak && request.ciaddr != 0 && request.wantsBroadcast == false ? request.ciaddr : 0xffff_ffff

		guard let destination = try? SocketAddress(ipAddress: DHCPAddress.string(destinationAddress), port: DHCPMessage.clientPort) else {
			return
		}

		var out = context.channel.allocator.buffer(capacity: 300)

		out.writeBytes(reply.encode())

		context.writeAndFlush(self.wrapOutboundOut(AddressedEnvelope(remoteAddress: destination, data: out)), promise: nil)
	}

	func errorCaught(context: ChannelHandlerContext, error: Error) {
		self.logger.warn("DHCP channel error: \(error)")
	}
}

/// Binds UDP 67 to the host interface of one network (`IP_BOUND_IF`), so several networks can each run their own
/// server on the same port and never see each other's broadcasts. Needs root for the privileged port.
public final class DHCPServer: Sendable {
	private let group: EventLoopGroup
	private let responder: DHCPResponder
	private let channelBox: Mutex<Channel?> = Mutex(nil)
	private let logger = Logger("DHCPServer")

	/// The address (the network's gateway) assigned to the host interface the server is bound to.
	public let bindAddress: String

	public init(group: EventLoopGroup, responder: DHCPResponder, bindAddress: String) {
		self.group = group
		self.responder = responder
		self.bindAddress = bindAddress
	}

	/// The name of the host interface that carries `address`, `nil` while vmnet hasn't brought it up.
	public static func interfaceName(forIPv4 address: String) -> String? {
		var list: UnsafeMutablePointer<ifaddrs>?

		guard getifaddrs(&list) == 0, let first = list else {
			return nil
		}

		defer { freeifaddrs(list) }

		for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
			guard let sa = pointer.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }

			var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))

			if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0, String(cString: host) == address {
				return String(cString: pointer.pointee.ifa_name)
			}
		}

		return nil
	}

	public func start() throws {
		guard let name = Self.interfaceName(forIPv4: self.bindAddress) else {
			throw DHCPServerError.interfaceNotFound(self.bindAddress)
		}

		let fd = socket(AF_INET, SOCK_DGRAM, 0)

		guard fd >= 0 else {
			throw DHCPServerError.socket("socket: \(String(cString: strerror(errno)))")
		}

		do {
			var one: Int32 = 1
			var index = if_nametoindex(name)

			guard index != 0 else {
				throw DHCPServerError.interfaceNotFound(name)
			}

			let size = socklen_t(MemoryLayout<Int32>.size)

			guard setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, size) == 0,
				setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &one, size) == 0,
				setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &one, size) == 0,
				setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &index, socklen_t(MemoryLayout<UInt32>.size)) == 0
			else {
				throw DHCPServerError.socket("setsockopt: \(String(cString: strerror(errno)))")
			}

			var address = sockaddr_in()

			address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
			address.sin_family = sa_family_t(AF_INET)
			address.sin_port = in_port_t(DHCPMessage.serverPort).bigEndian
			address.sin_addr.s_addr = INADDR_ANY

			let bound = withUnsafePointer(to: &address) {
				$0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
			}

			guard bound == 0 else {
				throw DHCPServerError.socket("bind 0.0.0.0:\(DHCPMessage.serverPort) on \(name): \(String(cString: strerror(errno)))")
			}
		} catch {
			close(fd)
			throw error
		}

		let responder = self.responder
		let channel = try DatagramBootstrap(group: self.group)
			.channelInitializer { channel in
				channel.pipeline.addHandler(DHCPInboundHandler(responder: responder))
			}
			.withBoundSocket(fd).wait()

		self.channelBox.withLock { $0 = channel }
		self.logger.info("DHCP server for \(self.bindAddress) listening on \(name):\(DHCPMessage.serverPort)")
	}

	/// Retries until the gateway interface exists (vmnet brings it up lazily) or the task is cancelled.
	public func startWithRetry(retryDelayNanoseconds: UInt64 = 1_000_000_000) async throws {
		while true {
			try Task.checkCancellation()

			do {
				try self.start()
				return
			} catch DHCPServerError.interfaceNotFound {
				try await Task.sleep(nanoseconds: retryDelayNanoseconds)
			}
		}
	}

	public func shutdown() async {
		let channel = self.channelBox.withLock { value -> Channel? in
			defer { value = nil }
			return value
		}

		try? await channel?.close()
	}
}
