import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Virtualization
import NIOPortForwarding

public struct InfosHandler {
	public static func infos(rootURL: URL, runMode: Utils.RunMode, client: CakeAgentHelper, callOptions: CallOptions?) throws -> (infos: VMInformations, config: any VirtualMachineConfiguration) {		
		return try InfosHandler.infos(location: try VMLocation.newVMLocation(rootURL: rootURL).validate(), runMode: runMode, client: client, callOptions: callOptions)
	}

	public static func infos(name: String, runMode: Utils.RunMode, client: CakeAgentHelper, callOptions: CallOptions?) throws -> (infos: VMInformations, config: any VirtualMachineConfiguration) {
		return try InfosHandler.infos(location: StorageLocation(runMode: runMode).find(name), runMode: runMode, client: client, callOptions: callOptions)
	}

	public static func infos(location: VMLocation, runMode: Utils.RunMode, client: CakeAgentHelper, callOptions: CallOptions?) throws -> (infos: VMInformations, config: any VirtualMachineConfiguration) {
		let config: CakeConfig = try location.config()
		var infos: VMInformations

		if location.status == .running {
			infos = .init(try client.info(callOptions: callOptions))
			if let vncURL = try? createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).vncURL {
				infos.vncURL = vncURL.map(\.absoluteString)
			} else {
				infos.vncURL = nil
			}
		} else {
			var diskInfos: [DiskInfo] = []

			diskInfos.append(DiskInfo(device: URL(fileURLWithPath: "disk.img", relativeTo: config.location).absoluteURL.path, mount: "/", fsType: "native", total: UInt64(try location.diskSize()), free: 0, used: 0))

			for disk in config.attachedDisks {
				let diskURL = URL(fileURLWithPath: disk.diskPath, relativeTo: config.location).absoluteURL

				diskInfos.append(DiskInfo(device: diskURL.path, mount: "not mounted", fsType: "native", total: UInt64(try diskURL.sizeBytes()), free: 0, used: 0))
			}

			infos = VMInformations.with {
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

		infos.name = location.name
		infos.mounts = config.mounts.map { $0.description }
		infos.attachedNetworks = config.networks.map { AttachedNetwork(network: $0.network, mode: $0.mode?.description ?? nil, macAddress: $0.macAddress ?? nil) }
		infos.tunnelInfos = config.forwardedPorts.compactMap { $0.tunnelInfo }
		infos.socketInfos = config.sockets.compactMap { $0.socketInfo }

		return (infos, config)
	}
}
