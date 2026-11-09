import Foundation
import CakedLib
import GRPCLib
import CakeAgentLib

extension NetworksHandler {
	public static func create(client: CakedServiceClient?, networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) throws -> CreatedNetworkReply {
		guard let client = client else {
			return NetworksWrapper.create(networkName: networkName, network: network, runMode: runMode)
		}
		
		return try CreatedNetworkReply(client.networks(.with {
			$0.command = .new
			$0.create = Caked_NetworkRequest.CreateNetworkRequest.with {
				$0.mode = network.mode == .shared ? .shared : .host
				$0.name = networkName
				$0.gateway = network.dhcpStart
				$0.dhcpEnd = network.dhcpEnd
				$0.netmask = network.netmask
				$0.uuid = network.interfaceID
				$0.nat66Prefix = network.nat66Prefix
				$0.dns = network.dns ?? false
			}
		}).response.wait().networks.created)
	}
	
	public static func configure(client: CakedServiceClient?, network: BridgedNetwork, runMode: Utils.RunMode) -> ConfiguredNetworkReply {
		let config = UsedNetworkConfig(
			mode: network.mode == .shared ? .shared : .host,
			networkName: network.name,
			netmask: network.netmask,
			dhcpStart: network.dhcpStart,
			dhcpEnd: network.dhcpEnd.stringBefore(before: "/"),
			dhcpLease: Int32(network.dhcpLease),
			interfaceID: network.interfaceID,
			dns: network.dns
		)

		guard let client = client else {
			return NetworksWrapper.configure(network: config, runMode: runMode)
		}

		do {
			return try ConfiguredNetworkReply(client.networks(.with {
				$0.command = .set
				$0.configure = Caked_ConfigureNetworkRequest.with {
					$0.name = config.networkName
					$0.gateway = network.dhcpStart
					$0.dhcpEnd = config.dhcpEnd ?? String.empty
					$0.netmask = network.netmask
					$0.uuid = network.interfaceID
					if let dhcpLease = config.dhcpLease {
						$0.dhcpLease = dhcpLease
					}
					$0.dns = network.dns
				}
			}).response.wait().networks.configured)
		} catch {
			return ConfiguredNetworkReply(name: network.name, configured: false, reason: error.reason)
		}
	}

	public static func networks(client: CakedServiceClient?, runMode: Utils.RunMode) throws -> ListNetworksReply {
		guard let client = client else {
			return NetworksWrapper.networks(runMode: runMode)
		}
		
		return try ListNetworksReply(client.networks(.with { $0.command = .infos }).response.wait().networks.list)
	}
	
	public static func start(client: CakedServiceClient?, networkName: String, runMode: Utils.RunMode) -> StartedNetworkReply {
		guard let client = client else {
			return NetworksWrapper.start(networkName: networkName, runMode: runMode)
		}

		do {
			return try StartedNetworkReply(client.networks(.with {
				$0.command = .start
				$0.name = networkName
			}).response.wait().networks.started)
		} catch {
			return StartedNetworkReply(name: networkName, started: false, reason: error.reason)
		}
	}

	public static func status(client: CakedServiceClient?, network: BridgedNetwork, runMode: Utils.RunMode) -> NetworkInfoReply {
		guard let client = client else {
			return NetworksWrapper.status(networkName: network.name, runMode: runMode)
		}

		do {
			return try NetworkInfoReply(client.networks(.with {
				$0.command = .status
				$0.name = network.name
			}).response.wait().networks.status)
		} catch {
			return NetworkInfoReply(info: network, success: false, reason: error.reason)
		}
	}

	public static func stop(client: CakedServiceClient?, networkName: String, runMode: Utils.RunMode) -> StoppedNetworkReply {
		guard let client = client else {
			return NetworksWrapper.stop(networkName: networkName, checkIfUsed: true, runMode: runMode)
		}
		
		do {
			return try StoppedNetworkReply(client.networks(.with {
				$0.command = .shutdown
				$0.name = networkName
			}).response.wait().networks.stopped)
		} catch {
			return StoppedNetworkReply(name: networkName, stopped: false, reason: error.reason)
		}
	}
	
	public static func delete(client: CakedServiceClient?, networkName: String, runMode: Utils.RunMode) -> DeleteNetworkReply {
		guard let client = client else {
			return NetworksWrapper.delete(networkName: networkName, runMode: runMode)
		}

		do {
			return try DeleteNetworkReply(client.networks(.with {
				$0.command = .remove
				$0.name = networkName
			}).response.wait().networks.delete)
		} catch {
			return DeleteNetworkReply(name: networkName, deleted: false, reason: error.reason)
		}
	}
}
