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
			let message: String

			switch self.request.command {
			case .infos:
				let result = try CakedLib.NetworksHandler.networks(runMode: runMode)

				return Caked_Reply.with {
					$0.networks = Caked_NetworksReply.with {
						$0.list = Caked_ListNetworksReply.with {
							$0.networks = result.map {
								$0.toCaked_NetworkInfo()
							}
						}
					}
				}
			case .status:
				let result = try CakedLib.NetworksHandler.status(networkName: self.request.name, runMode: runMode)

				return Caked_Reply.with {
					$0.networks = Caked_NetworksReply.with {
						$0.status = result.toCaked_NetworkInfo()
					}
				}
			case .new:
				message = try CakedLib.NetworksHandler.create(networkName: self.request.create.name, network: self.request.create.toVZSharedNetwork(), runMode: runMode)
			case .remove:
				message = try CakedLib.NetworksHandler.delete(networkName: self.request.name, runMode: runMode)
			case .start:
				_ = try CakedLib.NetworksHandler.start(networkName: self.request.name, runMode: runMode)
				message = "Network \(self.request.name) started"
			case .shutdown:
				message = try CakedLib.NetworksHandler.stop(networkName: self.request.name, runMode: runMode)
			case .set:
				message = try CakedLib.NetworksHandler.configure(network: self.request.configure.toUsedNetworkConfig(), runMode: runMode)
			default:
				throw ServiceError("Unknown command")
			}

			return Caked_Reply.with {
				$0.networks = Caked_NetworksReply.with {
					$0.message = message
				}
			}
		}
	}
}
