import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import Logging
import NIOCore
import NIOPosix
import SystemConfiguration
import TextTable
import UniformTypeIdentifiers
import Virtualization
import vmnet

struct NetworksHandler: CakedCommandAsync {
	var request: Caked_NetworkRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		on.submit {
			let networkReply: Caked_NetworksReply

			switch self.request.command {
			case .infos:
				networkReply = try Caked_NetworksReply.with {
					$0.list = try Caked_ListNetworksReply.with {
						$0.networks = try CakedLib.NetworksHandler.networks(runMode: runMode).map {
							$0.toCaked_NetworkInfo()
						}
					}
				}

			case .status:
				networkReply = try Caked_NetworksReply.with {
					$0.status = try CakedLib.NetworksHandler.status(networkName: self.request.name, runMode: runMode).toCaked_NetworkInfo()
				}

			case .new:
				networkReply = Caked_NetworksReply.with {
					$0.created = CakedLib.NetworksHandler.create(networkName: self.request.create.name, network: self.request.create.toVZSharedNetwork(), runMode: runMode).caked
				}

			case .remove:
				networkReply = Caked_NetworksReply.with {
					$0.delete = CakedLib.NetworksHandler.delete(networkName: self.request.name, runMode: runMode).caked
				}
			case .start:
				networkReply = Caked_NetworksReply.with {
					$0.started = CakedLib.NetworksHandler.start(networkName: self.request.name, runMode: runMode).caked
				}
			case .shutdown:
				networkReply = Caked_NetworksReply.with {
					$0.stopped = CakedLib.NetworksHandler.stop(networkName: self.request.name, runMode: runMode).caked
				}
			case .set:
				networkReply = Caked_NetworksReply.with {
					$0.configured = CakedLib.NetworksHandler.configure(network: self.request.configure.toUsedNetworkConfig(), runMode: runMode).caked
				}
			default:
				throw ServiceError("Unknown command")
			}

			return Caked_Reply.with {
				$0.networks = networkReply
			}
		}
	}
}
