import Foundation
import NIOCore
import NIOPosix
import GRPC
import GRPCLib
import NIOPortForwarding

nonisolated(unsafe) var portForwardingServer: PortForwardingServer? = nil

enum PortForwardingServerError: Error {
	case notFound
}

class PortForwardingServer {
	let mainGroup: EventLoopGroup
	let ttl: Int
	let bindAddress: String
	let remoteAddress: String
	var portForwarder: CakedPortForwarder
	var closeFuture: PortForwarderClosure

	deinit {
		try? portForwarder.syncShutdownGracefully()
	}

	private init(group: EventLoopGroup, bindAddress: String = "0.0.0.0", remoteAddress: String, forwardedPorts: [TunnelAttachment], ttl: Int = 5, listeningAddress: URL, asSystem: Bool) throws {
		self.mainGroup = group
		self.bindAddress = bindAddress
		self.remoteAddress = remoteAddress
		self.ttl = ttl
		self.portForwarder = try CakedPortForwarder(group: group, bindAddress: bindAddress,
		                                            remoteHost: remoteAddress,
		                                            forwardedPorts: forwardedPorts,
		                                            ttl: ttl,
		                                            listeningAddress: listeningAddress,
		                                            asSystem: asSystem)
	}

	private func add(forwardedPorts: [ForwardedPort]) throws {
		self.portForwarder.addPortForwardingServer(remoteHost: self.remoteAddress,
		                                           mappedPorts: forwardedPorts.map { MappedPort(host: $0.host, guest: $0.guest, proto: $0.proto) },
		                                           bindAddress: [self.bindAddress],
		                                           udpConnectionTTL: self.ttl)
	}

	private func delete(forwardedPorts: [ForwardedPort]) throws {
		forwardedPorts.forEach {  in
			let bindAddress = try SocketAddress.makeAddress("tcp://\(self.bindAddress):\($0.host)")
			let remoteAddress = try SocketAddress.makeAddress("tcp://\(self.remoteHost):\($0.guest)")

			try? self.portForwarder.removePortForwardingServer(bindAddress: bindAddress, remoteAddress: remoteAddress, proto: $0.proto, ttl: self.ttl)
		}
	}

	static func createPortForwardingServer(group: EventLoopGroup, remoteHost: String, forwardedPorts: [TunnelAttachment], listeningAddress: URL, asSystem: Bool) throws {
		portForwardingServer = CakedPortForwarder(group: group, forwardedPorts: forwardedPorts, listeningAddress: listeningAddress, asSystem: asSystem)
	}

	static func removeForwardedPort(forwardedPorts: [ForwardedPort]) throws {
		if forwardedPorts.count > 0 {
			if let portForwardingServer = portForwardingServer {
				Logger(self).info("Remove forwarded ports \(forwardedPorts.map { $0.description }.joined(separator: ", "))")

				try portForwardingServer.add(forwardedPorts: forwardedPorts)
			}
		}
	}

	static func addForwardedPort(forwardedPorts: [ForwardedPort]) throws {
		if forwardedPorts.count > 0 {
			if let portForwardingServer = portForwardingServer {
				Logger(self).info("Add forwarded ports \(forwardedPorts.map { $0.description }.joined(separator: ", "))")

				try portForwardingServer.delete(forwardedPorts: forwardedPorts)
			}
		}
	}

}
