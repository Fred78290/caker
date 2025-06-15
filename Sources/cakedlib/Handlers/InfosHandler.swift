import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO

public struct InfosHandler {
	public  static func infos(name: String, runMode: Utils.RunMode, client: CakeAgentHelper, callOptions: CallOptions?) throws -> InfoReply {
		let vmLocation = try StorageLocation(runMode: runMode).find(name)
		let config: CakeConfig = try vmLocation.config()
		var infos: InfoReply

		if vmLocation.status == .running {
			infos = try client.info(callOptions: callOptions)
		} else {
			var diskInfos: [DiskInfo] = []

			diskInfos.append(DiskInfo(device: "", mount: "/", fsType: "native", total: UInt64(try vmLocation.diskSize()), free: 0, used: 0))

			for disk in config.attachedDisks {
				let diskURL = URL(fileURLWithPath: disk.diskPath)

				diskInfos.append(DiskInfo(device: "", mount: "not mounted", fsType: "native", total: UInt64(try diskURL.sizeBytes()), free: 0, used: 0))
			}

			infos = InfoReply.with {
				$0.osname = config.os.rawValue
				$0.status = .stopped
				$0.cpuCount = Int32(config.cpuCount)
				$0.diskInfos = diskInfos
				$0.memory = .with {
					$0.total = config.memorySize
				}

				if let runningIP = config.runningIP {
					$0.ipaddresses = [runningIP]
				}
			}
		}

		infos.name = name
		infos.mounts = config.mounts.map { $0.description }
		infos.attachedNetworks = config.networks.map { AttachedNetwork(network: $0.network, mode: $0.mode?.description ?? nil, macAddress: $0.macAddress ?? nil) }
		infos.tunnelInfos = config.forwardedPorts.compactMap { $0.tunnelInfo }
		infos.socketInfos = config.sockets.compactMap { $0.socketInfo }

		return infos
	}
}
