import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib
import NIOCore
import NIOPosix
import SystemConfiguration
import TextTable
import UniformTypeIdentifiers
import Virtualization
import vmnet

struct NetworksHandler: CakedCommand {
	var request: Caked_NetworkRequest

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				switch self.request.command {
				case .infos:
					$0.list = .with {
						$0.reason = error.reason
					}
				case .status:
					$0.status = .with {
						$0.reason = error.reason
					}
				case .new:
					$0.created = .with {
						$0.reason = error.reason
					}
				case .set:
					$0.configured = .with {
						$0.reason = error.reason
					}
				case .start:
					$0.started = .with {
						$0.reason = error.reason
					}
				case .shutdown:
					$0.stopped = .with {
						$0.reason = error.reason
					}
				case .remove:
					$0.delete = .with {
						$0.reason = error.reason
					}
				default:
					$0.delete = .with {
						$0.reason = error.reason
					}
				}
			}
		}
	}

	private func networks(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.list = CakedLib.NetworksHandler.networks(runMode: runMode).caked
			}
		}
	}

	private func status(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.status = CakedLib.NetworksHandler.status(networkName: self.request.name, runMode: runMode).caked
			}
		}
	}

	private func create(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.created = CakedLib.NetworksHandler.create(networkName: self.request.create.name, network: self.request.create.toVZSharedNetwork(), runMode: runMode).caked
			}
		}
	}

	private func stop(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.stopped = CakedLib.NetworksHandler.stop(networkName: self.request.name, checkIfUsed: true, runMode: runMode).caked
			}
		}
	}

	private func start(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.started = CakedLib.NetworksHandler.start(networkName: self.request.name, runMode: runMode).caked
			}
		}
	}

	private func delete(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.delete = CakedLib.NetworksHandler.delete(networkName: self.request.name, runMode: runMode).caked
			}
		}
	}

	private func configure(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.configured = CakedLib.NetworksHandler.configure(network: self.request.configure.toUsedNetworkConfig(), runMode: runMode).caked
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		switch self.request.command {
		case .infos:
			return self.networks(runMode: runMode)
		case .status:
			return self.status(runMode: runMode)
		case .new:
			return self.create(runMode: runMode)
		case .remove:
			return self.delete(runMode: runMode)
		case .start:
			return self.start(runMode: runMode)
		case .shutdown:
			return self.stop(runMode: runMode)
		case .set:
			return self.configure(runMode: runMode)
		case .UNRECOGNIZED(let value):
			return Caked_Reply.with {
				$0.unexpected = String(localized: "Unexpected command \(value)")
			}
		}
	}
}
