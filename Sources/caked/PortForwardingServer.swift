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
	var portForwarders: [String:PortForwarder] = [:]
	var closures: [String:PortForwarderClosure] = [:]

	deinit {
		_ = portForwarders.values.map { pfw in
			try? pfw.syncShutdownGracefully()
		}

		portForwarders.removeAll()
		closures.removeAll()
	}

	private init(group: EventLoopGroup, bindAddress: String = "0.0.0.0", ttl: Int = 5) {
		self.mainGroup = group
		self.bindAddress = bindAddress
		self.ttl = ttl
	}

	private func exists(uuid: String) -> Bool {
		return self.portForwarders[uuid] != nil
	}

	private func close(uuid: String) throws {
		guard let portForwarder = self.portForwarders[uuid] else {
			throw PortForwardingServerError.notFound
		}

		try portForwarder.syncShutdownGracefully()

		self.portForwarders[uuid] = nil
		self.closures[uuid] = nil
	}

	private func add(remoteHost: String, forwardedPorts: [ForwardedPort]) throws -> String {
		let uuid = UUID().uuidString
		let pfw = PortForwarder(group: mainGroup, remoteHost: remoteHost,
			mappedPorts: forwardedPorts.map { forwarded in
				Logger(self).info("Remote: \(remoteHost), forward port: \(forwarded.proto.rawValue) \(forwarded.guest) to \(forwarded.host)")
				return MappedPort(host: forwarded.host, guest: forwarded.guest, proto: forwarded.proto)
			},
			bindAddress: self.bindAddress,
			udpConnectionTTL: self.ttl)


		let closure = pfw.bind()

		self.portForwarders[uuid] = pfw
		self.closures[uuid] = closure

		return uuid
	}

	static func createPortForwardingServer(group: EventLoopGroup) {
		portForwardingServer = .init(group: group)
	}

	static func closeForwardedPort(identifier: String) throws  {
		if let portForwardingServer = portForwardingServer {
			if portForwardingServer.exists(uuid: identifier) {
				try portForwardingServer.close(uuid: identifier)
			}
		}
	}

	static func createForwardedPort(remoteHost: String, forwardedPorts: [ForwardedPort]) throws -> String? {
		if forwardedPorts.count > 0 {
			if let portForwardingServer = portForwardingServer {
				let details = forwardedPorts.map { port in
					return port.description
				}

				Logger(self).info("Add forwarded ports \(details.joined(separator: ", "))")
	
				return try portForwardingServer.add(remoteHost: remoteHost, forwardedPorts: forwardedPorts)
			}
		}
		
		return nil
	}

}
