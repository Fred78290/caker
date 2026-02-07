import Foundation
import CakedLib
import GRPCLib

extension NetworksHandler {
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
