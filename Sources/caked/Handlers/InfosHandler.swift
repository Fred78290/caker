import Foundation
import NIO
import GRPC
import GRPCLib
import CakeAgentLib
import TextTable

struct InfosHandler: CakedCommand {
	var request: Caked_InfoRequest
	var client: CakeAgentConnection

	static func infos(name: String, asSystem: Bool, client: CakeAgentHelper, callOptions: CallOptions?) throws -> InfoReply {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)
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

		return infos
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		return try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.infos = try Self.infos(name: self.request.name, asSystem: asSystem, client: CakeAgentHelper(on: on, client: client.createClient()), callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5)))).toCaked_InfoReply()
			}
		}
	}
}
