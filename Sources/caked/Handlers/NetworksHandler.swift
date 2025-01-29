import ArgumentParser
import Foundation
import GRPCLib
import Virtualization
import NIOCore

struct BridgedNetwork: Codable {
	var name: String
	var description: String?
}

struct NetworksHandler: CakedCommand {
	var format: Format

	static func networks() -> [BridgedNetwork] {
		VZBridgedNetworkInterface.networkInterfaces.map { inf in
			BridgedNetwork(name: inf.identifier, description: inf.localizedDisplayName)
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		on.submit {
			self.format.renderList(Self.networks())
		}
	}
}