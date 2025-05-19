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
	let portForwarder: CakedPortForwarder
	let dynamicPortFarwarding: Bool
	var closeFuture: PortForwarderClosure? = nil

	deinit {
		try? portForwarder.syncShutdownGracefully()
	}

	private init(group: EventLoopGroup, bindAddress: String = "0.0.0.0", remoteAddress: String, forwardedPorts: [TunnelAttachement], dynamicPortFarwarding: Bool, ttl: Int = 5, listeningAddress: URL, asSystem: Bool) throws {
		self.mainGroup = group
		self.bindAddress = bindAddress
		self.remoteAddress = remoteAddress
		self.ttl = ttl
		self.dynamicPortFarwarding = dynamicPortFarwarding
		self.portForwarder = try CakedPortForwarder(group: group,
		                                            remoteHost: remoteAddress,
		                                            bindAddress: bindAddress,
		                                            forwardedPorts: forwardedPorts,
		                                            ttl: ttl,
		                                            listeningAddress: listeningAddress,
		                                            asSystem: asSystem)
	}

	private func bind() throws {
		self.closeFuture = try self.portForwarder.bind()
		if self.dynamicPortFarwarding {
			try self.portForwarder.startDynamicPortForwarding()
		}
	}

	private func close() throws {
		try portForwarder.syncShutdownGracefully()
		try self.closeFuture?.wait()
	}

	private func add(forwardedPorts: [ForwardedPort]) throws -> [any PortForwarding] {
		try self.portForwarder.addPortForwardingServer(remoteHost: self.remoteAddress,
		                                               mappedPorts: forwardedPorts.map { MappedPort(host: $0.host, guest: $0.guest, proto: $0.proto) },
		                                               bindAddress: [self.bindAddress],
		                                               udpConnectionTTL: self.ttl)
	}

	private func delete(forwardedPorts: [ForwardedPort]) throws {
		try forwardedPorts.forEach {
			let bindAddress = try SocketAddress.makeAddress("tcp://\(self.bindAddress):\($0.host)")
			let remoteAddress = try SocketAddress.makeAddress("tcp://\(self.remoteAddress):\($0.guest)")

			do {
				try self.portForwarder.removePortForwardingServer(bindAddress: bindAddress, remoteAddress: remoteAddress, proto: $0.proto, ttl: self.ttl)
			} catch (PortForwardingError.alreadyBinded(let error)) {
				Logger(self).error(error)
			}
		}
	}

	static func createPortForwardingServer(group: EventLoopGroup, remoteAddress: String, forwardedPorts: [TunnelAttachement], dynamicPortFarwarding: Bool, listeningAddress: URL, asSystem: Bool) throws {
		if portForwardingServer == nil {
			let server = try PortForwardingServer(group: group, remoteAddress: remoteAddress, forwardedPorts: forwardedPorts, dynamicPortFarwarding: dynamicPortFarwarding, listeningAddress: listeningAddress, asSystem: asSystem)

			try server.bind()

			portForwardingServer = server
		}
	}

	static func removeForwardedPort(forwardedPorts: [ForwardedPort]) throws {
		if forwardedPorts.count > 0 {
			if let portForwardingServer = portForwardingServer {
				Logger(self).info("Remove forwarded ports \(forwardedPorts.map { $0.description }.joined(separator: ", "))")

				try portForwardingServer.delete(forwardedPorts: forwardedPorts)
			}
		}
	}

	static func addForwardedPort(forwardedPorts: [ForwardedPort]) throws -> [any PortForwarding] {
		if forwardedPorts.count > 0 {
			if let portForwardingServer = portForwardingServer {
				Logger(self).info("Add forwarded ports \(forwardedPorts.map { $0.description }.joined(separator: ", "))")

				return try portForwardingServer.add(forwardedPorts: forwardedPorts)
			}
		}

		return []
	}

	static func closeForwardedPort() throws {
		if let portForwardingServer = portForwardingServer {
			Logger(self).info("Close forwarded ports")

			try portForwardingServer.close()
		}
	}
}
