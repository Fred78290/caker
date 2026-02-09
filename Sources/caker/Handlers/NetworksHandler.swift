import Foundation
import CakedLib
import GRPCLib

extension NetworksHandler {
	public static func create(client: CakedServiceClient?, networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) throws -> CreatedNetworkReply {
		guard let client = client, runMode != .app else {
			return self.create(networkName: networkName, network: network, runMode: runMode)
		}

		return try CreatedNetworkReply(from: client.networks(.with {
			$0.command = .new
			$0.create = Caked_NetworkRequest.CreateNetworkRequest.with {
				$0.mode = network.mode == .shared ? .shared : .host
				$0.name = networkName
				$0.gateway = network.dhcpStart
				$0.dhcpEnd = network.dhcpEnd
				$0.netmask = network.netmask
				$0.uuid = network.interfaceID
				if let nat66Prefix = network.nat66Prefix {
					$0.nat66Prefix = nat66Prefix
				}
			}
		}).response.wait().networks.created)
	}

	public static func networks(client: CakedServiceClient?, runMode: Utils.RunMode) throws -> ListNetworksReply {
		guard let client = client, runMode != .app else {
			return self.networks(runMode: runMode)
		}
		
		return try ListNetworksReply(from: client.networks(.with { $0.command = .infos }).response.wait().networks.list)
	}
	
	public static func start(client: CakedServiceClient?, networkName: String, runMode: Utils.RunMode) -> StartedNetworkReply {
		guard let client = client, runMode != .app else {
			return self.start(networkName: networkName, runMode: runMode)
		}
		
		do {
			return try StartedNetworkReply(from: client.networks(.with {
				$0.command = .start
				$0.name = networkName
			}).response.wait().networks.started)
		} catch {
			return StartedNetworkReply(name: networkName, started: false, reason: "\(error)")
		}
	}
	
	public static func stop(client: CakedServiceClient?, networkName: String, runMode: Utils.RunMode) -> StoppedNetworkReply {
		guard let client = client, runMode != .app else {
			return self.stop(networkName: networkName, runMode: runMode)
		}

		do {
			return try StoppedNetworkReply(from: client.networks(.with {
				$0.command = .start
				$0.name = networkName
			}).response.wait().networks.stopped)
		} catch {
			return StoppedNetworkReply(name: networkName, stopped: false, reason: "\(error)")
		}
	}
}
