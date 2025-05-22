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
	let bindAddresses: [String]
	let remoteAddress: String
	let portForwarder: CakedPortForwarder
	let dynamicPortFarwarding: Bool
	var closeFuture: PortForwarderClosure? = nil

	deinit {
		try? portForwarder.close()
	}

	private init(group: EventLoopGroup, bindAddresses: [String] = ["0.0.0.0", "[::]"], remoteAddress: String, forwardedPorts: [TunnelAttachement], dynamicPortFarwarding: Bool, ttl: Int = 5, listeningAddress: URL, asSystem: Bool) throws {
		self.mainGroup = group
		self.bindAddresses = bindAddresses
		self.remoteAddress = remoteAddress
		self.ttl = ttl
		self.dynamicPortFarwarding = dynamicPortFarwarding
		self.portForwarder = try CakedPortForwarder(group: group,
		                                            remoteHost: remoteAddress,
		                                            bindAddress: bindAddresses,
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
		Logger(self).info("Closing port forwarder")

		try portForwarder.close()

		Logger(self).info("Waiting for port forwarder to close")
		// Wait for the close future to complete
		try self.closeFuture?.wait()
		Logger(self).info("Port forwarder closed")
	}

	private func add(forwardedPorts: [ForwardedPort]) throws -> [any PortForwarding] {
		try self.portForwarder.addPortForwardingServer(remoteHost: self.remoteAddress,
		                                               mappedPorts: forwardedPorts.map { MappedPort(host: $0.host, guest: $0.guest, proto: $0.proto) },
		                                               bindAddress: self.bindAddresses,
		                                               udpConnectionTTL: self.ttl)
	}

	private func delete(forwardedPorts: [ForwardedPort]) throws {
		try self.bindAddresses.forEach { bindAddress in
			try forwardedPorts.forEach {
				let bindAddress = try SocketAddress.makeAddress("tcp://\(bindAddress):\($0.host)")
				let remoteAddress = try SocketAddress.makeAddress("tcp://\(self.remoteAddress):\($0.guest)")

				do {
					try self.portForwarder.removePortForwardingServer(bindAddress: bindAddress, remoteAddress: remoteAddress, proto: $0.proto, ttl: self.ttl)
				} catch (PortForwardingError.alreadyBinded(let error)) {
					Logger(self).error(error)
				}
			}
		}
	}

	static func createPortForwardingServer(group: EventLoopGroup, remoteAddress: String, forwardedPorts: [TunnelAttachement], dynamicPortFarwarding: Bool, listeningAddress: URL, asSystem: Bool) throws {
		guard let server = portForwardingServer else {
			let server = try PortForwardingServer(group: group, remoteAddress: remoteAddress, forwardedPorts: forwardedPorts, dynamicPortFarwarding: dynamicPortFarwarding, listeningAddress: listeningAddress, asSystem: asSystem)

			try server.bind()

			portForwardingServer = server
			Logger(self).info("Port forwarding server created")
			return
		}

		if case .stopped = server.portForwarder.status {
			Logger(self).info("Port forwarding server is stopped, restarting")
			try server.bind()
		}
	}

	static func removeForwardedPort(forwardedPorts: [ForwardedPort]) throws {
		if forwardedPorts.count > 0 {
			if let server = portForwardingServer {
				Logger(self).info("Remove forwarded ports \(forwardedPorts.map { $0.description }.joined(separator: ", "))")

				try server.delete(forwardedPorts: forwardedPorts)
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
		if let server = portForwardingServer {
			Logger(self).info("Close forwarded ports")

			defer {
				portForwardingServer = nil
			}

			try server.close()
		}
	}
}
