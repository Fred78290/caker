//
//  NetworksWrapper.swift
//  CakerAppStore
//
//  Created by Frederic BOLTZ on 07/11/2026.
//

import Foundation
import GRPCLib
import vmnet

public struct NetworksWrapper {
	public static func validateNetwork(networkName: String, runMode: Utils.RunMode) throws -> BridgedNetwork.NetworkUsage {
		// Validate the network name
		if NetworksHandler.isPhysicalInterface(name: networkName) == false {
			let networkConfig = try NetworksHandler.sharedNetworks(runMode: runMode)

			if networkConfig.sharedNetworks[networkName] == nil {
				throw ServiceError(String(localized: "Network \(networkName) does not exist"))
			}
		}

		return NetworksHandler.referencedNetwork(networkName: networkName, runMode: runMode)
	}

	public static func isRunningNetwork(networkName: String, runMode: Utils.RunMode) throws -> Bool {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			let infos = Self.status(networkName: networkName, runMode: runMode)

			guard infos.success else {
				throw ServiceError(String(localized: "Unable to get network status for \(networkName): \(infos.reason)"))
			}

			return infos.info.running
		#else
			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: runMode)

			guard socketURL.pidFile.isCakedRunning() else {
				return false
			}

			guard let pid = socketURL.pidFile.readPID() else {
				return false
			}

			return true
		#endif
	}

	@available(macOS 26.0, *)
	public static func createVMNetwork(networkName: String, runMode: Utils.RunMode) throws -> vmnet_network_ref {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			if try self.isRunningNetwork(networkName: networkName, runMode: runMode) == false {
				let result = self.start(networkName: networkName, runMode: runMode)

				guard result.started else {
					throw ServiceError(result.reason)
				}
			}

			guard let serialization = try CakedLib.NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.getSerialization(networkName: networkName, runMode: runMode) }) else {
				throw ServiceError(String(localized: "Unable to decode network serialization buffer"))
			}
		#else
			var socketURL = try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: runMode)

			if socketURL.pidFile.isPIDRunning().running == false {
				if Bundle.mustUseUnixTask {
					try NetworksHandler.startNetworkSandboxed(networkName: networkName, runMode: runMode)
				} else {
					socketURL = try NetworksHandler.startNetwork(networkName: networkName, runMode: runMode)
				}
			}

			let client = try NetworksHandler.getVMNetControlClient(socketURL.socket, runMode: runMode)

			defer {
				_ = try? client.channel.close().wait()
			}

			let reply = try client.getSerialization(Vmnet_Empty()).response.wait()

			guard reply.success else {
				throw ServiceError(String(localized: "VMNet serialization failed: \(reply.reason)"))
			}

			let serialization = try decodeXPCObject(reply.data)
		#endif

		var status: vmnet_return_t = vmnet_return_t.VMNET_SUCCESS

		guard let network = vmnet_network_create_with_serialization(serialization, &status) else {
			throw ServiceError(String(localized: "Failed to create vmnet network with serialization, status: \(status.description)"))
		}

		return network
	}

	public static func restartNetworkService(networkName: String, runMode: Utils.RunMode) throws -> String {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			if let reason = try CakedLib.NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.restartNetwork(networkName: networkName, runMode: runMode) }) {
				return reason
			}

		#endif

		return try NetworksHandler.restartNetworkService(networkName: networkName, runMode: runMode)
	}

	public static func networks(all: Bool = false, runMode: Utils.RunMode) -> ListNetworksReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let networks = try NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.listNetwork(runMode: runMode) }) {
					let networks = networks.map { network in
						var network = network
						// In AppStore with helper, the network configuration can not access VM home, so we cannot know if the network is used by a VM. We can only check if the network is running or not.
						network.usedBy = NetworksHandler.referencedNetwork(networkName: network.name, runMode: runMode)
						return network
					}

					return ListNetworksReply(networks: networks, success: true, reason: String(localized: "Success"))
				}
			} catch {
				return ListNetworksReply(networks: [], success: false, reason: error.reason)
			}
		#endif

		return NetworksHandler.networks(all: all, runMode: runMode)
	}

	public static func status(networkName: String, runMode: Utils.RunMode) -> NetworkInfoReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let info = try NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.infosNetwork(networkName: networkName, runMode: runMode) }) {

					var network = info.network
					// In AppStore with helper, the network configuration can not access VM home, so we cannot know if the network is used by a VM. We can only check if the network is running or not.
					network.usedBy = NetworksHandler.referencedNetwork(networkName: networkName, runMode: runMode)

					return NetworkInfoReply(info: network, success: true, reason: String(localized: "Success"))
				}
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
		#endif

		return NetworksHandler.status(networkName: networkName, runMode: runMode)
	}

	public static func create(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) -> CreatedNetworkReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let reply = try NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.createNetwork(networkName: networkName, network: network, runMode: runMode) }) {

					return reply
				}
			} catch {
				return CreatedNetworkReply(name: networkName, created: false, reason: error.reason)
			}
		#endif

		return NetworksHandler.create(networkName: networkName, network: network, runMode: runMode)
	}

	/// Stops what runs and isn't used by a virtual machine, as `NetworksHandler.stopAll` does.
	public static func stopAll(runMode: Utils.RunMode) -> [StoppedNetworkReply] {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				let replies: [StoppedNetworkReply]? = try NetworksHandler.viaSandboxHelperSync(runMode: runMode) { helper in
					var replies: [StoppedNetworkReply] = []

					for network in try await helper.listNetwork(runMode: runMode) where network.running {
						if network.usedBy.active == 0 {
							replies.append(try await helper.stopNetwork(networkName: network.name, runMode: runMode))
						} else {
							replies.append(StoppedNetworkReply(name: network.name, stopped: false, reason: String(localized: "Network \(network.name) is currently in use by one or more virtual machines")))
						}
					}

					return replies
				}

				if let replies {
					return replies
				}
			} catch {
				return [StoppedNetworkReply(name: "<all>", stopped: false, reason: error.reason)]
			}
		#endif

		return NetworksHandler.stopAll(runMode: runMode)
	}

	public static func stop(networkName: String, checkIfUsed: Bool, runMode: Utils.RunMode) -> StoppedNetworkReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let reply = try NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.stopNetwork(networkName: networkName, runMode: runMode) }) {
					return reply
				}
			} catch {
				return StoppedNetworkReply(name: networkName, stopped: false, reason: error.reason)
			}
		#endif

		return NetworksHandler.stop(networkName: networkName, checkIfUsed: checkIfUsed, runMode: runMode)
	}

	public static func start(networkName: String, runMode: Utils.RunMode) -> StartedNetworkReply {
		NetworksHandler.start(networkName: networkName, runMode: runMode)
	}

	public static func delete(networkName: String, runMode: Utils.RunMode) -> DeleteNetworkReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let reply = try NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.deleteNetwork(networkName: networkName, runMode: runMode) }) {
					return reply
				}
			} catch {
				return DeleteNetworkReply(name: networkName, deleted: false, reason: error.reason)
			}
		#endif

		return NetworksHandler.delete(networkName: networkName, runMode: runMode)
	}

	public static func configure(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) -> ConfiguredNetworkReply {
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				if let reply = try NetworksHandler.viaSandboxHelperSync(runMode: runMode, { try await $0.configureNetwork(networkName: networkName, network: network, runMode: runMode) }) {
					return reply
				}
			} catch {
				return ConfiguredNetworkReply(name: networkName, configured: false, reason: error.reason)
			}
		#endif

		return NetworksHandler.configure(networkName: networkName, network: network, runMode: runMode)
	}

	public static func configure(network: UsedNetworkConfig, runMode: Utils.RunMode) -> ConfiguredNetworkReply {
		guard network.networkName != String.empty else {
			return ConfiguredNetworkReply(name: String.empty, configured: false, reason: String(localized: "Network name is required"))
		}

		guard NetworksHandler.isPhysicalInterface(name: String(network.networkName)) == false else {
			return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Network \(network.networkName) is a physical interface"))
		}

		#if APPSTORE && USE_AUTHORIZATION_HELPER
			do {
				guard
					let netInfos = try NetworksHandler.viaSandboxHelperSync(
						runMode: runMode,
						{
							try await $0.infosNetwork(networkName: network.networkName, runMode: runMode)
						})
				else {
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

				if let reply = try NetworksHandler.viaSandboxHelperSync(
					runMode: runMode,
					{
						try await $0.configureNetwork(networkName: network.networkName, network: changed, runMode: runMode)
					})
				{
					return reply
				}
			} catch {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: error.reason)
			}
		#endif

		do {
			var networkConfig = try NetworksHandler.sharedNetworks(runMode: runMode)

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
				try NetworksHandler.setSharedNetworks(networkConfig, runMode: runMode)

				do {
					return ConfiguredNetworkReply(name: network.networkName, configured: true, reason: try NetworksHandler.restartNetworkService(networkName: network.networkName, runMode: runMode))
				} catch {
					return ConfiguredNetworkReply(name: network.networkName, configured: true, reason: error.reason)
				}
			} else {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Network \(network.networkName) unchanged"))
			}
		} catch {
			return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: error.reason)
		}
	}

}
