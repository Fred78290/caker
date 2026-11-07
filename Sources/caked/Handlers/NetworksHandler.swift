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

	public static func networks(all: Bool = false, runMode: Utils.RunMode) -> ListNetworksReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let networks = try CakedLib.NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.listNetwork(runMode: runMode) }) {
					return ListNetworksReply(networks: networks, success: true, reason: String(localized: "Success"))
				}

				return ListNetworksReply(networks: [], success: false, reason: String(localized: "Internal error"))
			} catch {
				return ListNetworksReply(networks: [], success: false, reason: error.reason)
			}
		#else
			return CakedLib.NetworksHandler.networks(runMode: runMode)
		#endif
	}

	public static func status(networkName: String, runMode: Utils.RunMode) -> NetworkInfoReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let info = try CakedLib.NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.infosNetwork(networkName: networkName, runMode: runMode) }) {

					return NetworkInfoReply(info: info.network, success: true, reason: String(localized: "Success"))
				}

				return NetworkInfoReply(
					info: BridgedNetwork(
						name: networkName,
						mode: .shared,
						description: String.empty,
						gateway: String.empty,
						dhcpLease: String.empty,
						nat66Prefix: String.empty,
						interfaceID: String.empty,
						endpoint: String.empty,
						running: false,
						managed: false,
						dns: false,
						usedBy: BridgedNetwork.NetworkUsage(used: 0, active: 0)), success: false, reason: String(localized: "Internal error"))

			} catch {
				return NetworkInfoReply(
					info: BridgedNetwork(
						name: networkName,
						mode: .shared,
						description: String.empty,
						gateway: String.empty,
						dhcpLease: String.empty,
						nat66Prefix: String.empty,
						interfaceID: String.empty,
						endpoint: String.empty,
						running: false,
						managed: false,
						dns: false,
						usedBy: BridgedNetwork.NetworkUsage(used: 0, active: 0)), success: false, reason: error.reason)
			}
		#else
			CakedLib.NetworksHandler.status(networkName: networkName, runMode: runMode)
		#endif
	}

	public static func create(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) -> CreatedNetworkReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let reply = try CakedLib.NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.createNetwork(networkName: networkName, network: network, runMode: runMode) }) {

					return reply
				}

				return CreatedNetworkReply(name: networkName, created: false, reason: String(localized: "Internal error"))
			} catch {
				return CreatedNetworkReply(name: networkName, created: false, reason: error.reason)
			}
		#else
			CakedLib.NetworksHandler.create(networkName: networkName, network: network, runMode: runMode)
		#endif
	}

	public static func stop(networkName: String, checkIfUsed: Bool, runMode: Utils.RunMode) -> StoppedNetworkReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
			} catch {

			}
		#else
			CakedLib.NetworksHandler.stop(networkName: networkName, checkIfUsed: checkIfUsed, runMode: runMode)
		#endif

		return CakedLib.NetworksHandler.stop(networkName: networkName, checkIfUsed: checkIfUsed, runMode: runMode)
	}

	public static func start(networkName: String, runMode: Utils.RunMode) -> StartedNetworkReply {
		CakedLib.NetworksHandler.start(networkName: networkName, runMode: runMode)
	}

	public static func delete(networkName: String, runMode: Utils.RunMode) -> DeleteNetworkReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let reply = try CakedLib.NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.deleteNetwork(networkName: networkName, runMode: runMode) }) {

					return reply
				}

				return DeleteNetworkReply(name: networkName, deleted: false, reason: String(localized: "Internal error"))

			} catch {
				return DeleteNetworkReply(name: networkName, deleted: false, reason: error.reason)
			}
		#else
			CakedLib.NetworksHandler.delete(networkName: networkName, runMode: runMode)
		#endif
	}

	public static func configure(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) -> ConfiguredNetworkReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let reply = try CakedLib.NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.configureNetwork(networkName: networkName, network: network, runMode: runMode) }) {

					return reply
				}

				return ConfiguredNetworkReply(name: networkName, configured: false, reason: String(localized: "Internal error"))
			} catch {
				return ConfiguredNetworkReply(name: networkName, configured: false, reason: error.reason)
			}
		#else
			CakedLib.NetworksHandler.configure(networkName: networkName, network: network, runMode: runMode)
		#endif
	}

	public static func configure(network: UsedNetworkConfig, runMode: Utils.RunMode) -> ConfiguredNetworkReply {
		guard network.networkName != String.empty else {
			return ConfiguredNetworkReply(name: String.empty, configured: false, reason: String(localized: "Network name is required"))
		}

		guard CakedLib.NetworksHandler.isPhysicalInterface(name: String(network.networkName)) == false else {
			return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Network \(network.networkName) is a physical interface"))
		}

		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				guard let netInfos = try CakedLib.NetworksHandler.viaSandboxHelperSync(runMode: runMode, {
					try await $0.infosNetwork(networkName: network.networkName, runMode: runMode)
				}) else {
					return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Internal error"))
				}

				let exisiting = netInfos.network
				let netmask = network.netmask ?? exisiting.netmask
				// A new start address without an end: default the end to the last address of the network.
				let dhcpEnd = network.dhcpEnd ?? (network.dhcpStart.flatMap { VZSharedNetwork.defaultDhcpEnd(dhcpStart: $0, netmask: netmask) } ?? exisiting.dhcpEnd)

				let changed = VZSharedNetwork(
					mode: netInfos.mode,
					netmask: netmask,
					dhcpStart: network.dhcpStart ?? exisiting.dhcpStart,
					dhcpEnd: dhcpEnd,
					dhcpLease: network.dhcpLease,
					interfaceID: network.interfaceID ?? exisiting.interfaceID,
					nat66Prefix: network.nat66Prefix ?? exisiting.nat66Prefix,
					dns: network.dns == nil ? exisiting.dns : false
				)

				if let reply = try CakedLib.NetworksHandler.viaSandboxHelperSync(runMode: runMode, {
					try await $0.configureNetwork(networkName: network.networkName, network: changed, runMode: runMode)
				}) {
					return reply
				}

				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Internal error"))
			} catch {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: error.reason)
			}
		#else
			do {
				let networkConfig = try CakedLib.NetworksHandler.sharedNetworks(runMode: runMode)

				guard let exisiting = networkConfig.sharedNetworks[network.networkName] else {
					return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Network \(network.networkName) doesn't exists"))
				}

				let netmask = network.netmask ?? exisiting.netmask
				// A new start address without an end: default the end to the last address of the network.
				let dhcpEnd = network.dhcpEnd ?? (network.dhcpStart.flatMap { VZSharedNetwork.defaultDhcpEnd(dhcpStart: $0, netmask: netmask) } ?? exisiting.dhcpEnd)

				let changed = VZSharedNetwork(
					mode: exisiting.mode,
					netmask: netmask,
					dhcpStart: network.dhcpStart ?? exisiting.dhcpStart,
					dhcpEnd: dhcpEnd,
					dhcpLease: network.dhcpLease ?? exisiting.dhcpLease,
					interfaceID: network.interfaceID ?? exisiting.interfaceID,
					nat66Prefix: network.nat66Prefix ?? exisiting.nat66Prefix,
					dns: network.dns ?? exisiting.dns ?? false
				)

				if changed != exisiting {
					try changed.validate(runMode: runMode, excluding: network.networkName)
					networkConfig.userNetworks[network.networkName] = changed
					try home.setSharedNetworks(networkConfig)

					do {
						return ConfiguredNetworkReply(name: network.networkName, configured: true, reason: try CakedLib.NetworksHandler.restartNetworkService(networkName: network.networkName, runMode: runMode))
					} catch {
						return ConfiguredNetworkReply(name: network.networkName, configured: true, reason: error.reason)
					}
				} else {
					return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Network \(network.networkName) unchanged"))
				}
			} catch {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: error.reason)
			}
		#endif
	}

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
				$0.list = Self.networks(runMode: runMode).caked
			}
		}
	}

	private func status(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.status = Self.status(networkName: self.request.name, runMode: runMode).caked
			}
		}
	}

	private func create(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.created = Self.create(networkName: self.request.create.name, network: self.request.create.toVZSharedNetwork(), runMode: runMode).caked
			}
		}
	}

	private func stop(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.stopped = Self.stop(networkName: self.request.name, checkIfUsed: true, runMode: runMode).caked
			}
		}
	}

	private func start(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.started = Self.start(networkName: self.request.name, runMode: runMode).caked
			}
		}
	}

	private func delete(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.delete = Self.delete(networkName: self.request.name, runMode: runMode).caked
			}
		}
	}

	private func configure(runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.networks = Caked_NetworksReply.with {
				$0.configured = Self.configure(network: self.request.configure.toUsedNetworkConfig(), runMode: runMode).caked
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
