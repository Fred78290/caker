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

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				switch self.request.command {
				case .infos:
					$0.list = Caked_ListNetworksReply.with {
						$0.reason = "\(error	)"
					}
				case .status:
					$0.status = .with {
						$0.reason = "\(error)"
					}
				case .new:
					$0.created = .with {
						$0.reason = "\(error)"
					}
				case .set:
					$0.configured = .with {
						$0.reason = "\(error)"
					}
				case .start:
					$0.started = .with {
						$0.reason = "\(error)"
					}
				case .shutdown:
					$0.stopped = .with {
						$0.reason = "\(error)"
					}
				case .remove:
					$0.delete = .with {
						$0.reason = "\(error)"
					}
				default:
					$0.delete = .with {
						$0.reason = "\(error)"
					}
				}
			}
		}
	}

	private func networks(runMode: Utils.RunMode) -> Caked_ListNetworksReply {
		do {
			let networks = try CakedLib.NetworksHandler.networks(runMode: runMode)
			
			return Caked_ListNetworksReply.with {
				$0.success = true
				$0.reason = "Success"
				$0.networks = networks.map {
					$0.caked
				}
			}
		}
		catch {
			return Caked_ListNetworksReply.with {
				$0.success = false
				$0.reason = "\(error)"
			}
		}
	}

	private func status(networkName: String, runMode: Utils.RunMode) -> Caked_NetworkInfoReply {
		do {
			let status = try CakedLib.NetworksHandler.status(networkName: self.request.name, runMode: runMode)

			return Caked_NetworkInfoReply.with {
				$0.success = false
				$0.reason = "Success"
				$0.info = status.caked
			}

		} catch {
			return Caked_NetworkInfoReply.with {
				$0.success = false
				$0.reason = "\(error)"
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		on.submit {
			let networkReply: Caked_NetworksReply

			switch self.request.command {
			case .infos:
				networkReply = Caked_NetworksReply.with {
					$0.list = self.networks(runMode: runMode)
				}

			case .status:
				networkReply = Caked_NetworksReply.with {
					$0.status = self.status(networkName: self.request.name, runMode: runMode)
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
