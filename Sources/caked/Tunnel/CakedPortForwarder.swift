import Foundation
import GRPCLib
import CakeAgentLib
import NIOPortForwarding
import NIOCore

class CakedPortForwarder: PortForwarder, @unchecked Sendable {
	internal let forwardedPorts: [TunnelAttachement]
	internal let cakeAgentClient: CakeAgentClient
	internal let listeningAddress: URL
	internal let asSystem: Bool
	internal var dynamicPorts: [SocketAddress] = []

	init(group: EventLoopGroup, remoteHost: String, bindAddress: String, forwardedPorts: [TunnelAttachement], ttl: Int = 5, listeningAddress: URL, asSystem: Bool) throws {
		let mappedPorts = forwardedPorts.filter { $0.unixDomain == nil }.compactMap{ $0.mappedPort }

		self.asSystem = asSystem
		self.listeningAddress = listeningAddress
		self.forwardedPorts = forwardedPorts
		self.cakeAgentClient = try CakeAgentConnection.createCakeAgentClient(on: group.next(), listeningAddress: listeningAddress, timeout: 5, asSystem: asSystem)

		try super.init(group: group, remoteHost: remoteHost, mappedPorts: mappedPorts, bindAddresses: [bindAddress], udpConnectionTTL: ttl)

		try forwardedPorts.forEach { forwarded in
			if let unixDomain = forwarded.unixDomain {
				_ = try self.addPortForwardingServer(bindAddress: SocketAddress(unixDomainSocketPath: unixDomain.host.expandingTildeInPath), remoteAddress: SocketAddress(unixDomainSocketPath: unixDomain.guest), proto: unixDomain.proto, ttl: ttl)
			}
		}
	}

	func startDynamicPortForwarding() throws {
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
}
