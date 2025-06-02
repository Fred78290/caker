import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration
import TextTable

struct ListHandler: CakedCommand {
	let vmonly: Bool

	static func list(vmonly: Bool, runMode: Utils.RunMode) throws -> [VirtualMachineInfo] {
		var vmInfos = try StorageLocation(runMode: runMode).list().map { (name: String, location: VMLocation) in
			let status = location.status
			let config = try location.config()

			return VirtualMachineInfo(
				type: "vm",
				source: "vms",
				name: name,
				fqn: ["vm://\(name)"],
				instanceID: config.instanceID,
				diskSize: try location.diskSize(),
				totalSize: try location.allocatedSize(),
				state: status.rawValue,
				ip: status == .running ? config.runningIP : nil,
				fingerprint: nil
			)
		}

		vmInfos.sort { vm1, vm2 in
			vm1.fqn.joined(separator: ",") < vm2.fqn.joined(separator: ",")
		}

		if vmonly == false {
			let purgeableStorages = [
				try TemplateImageCache(runMode: runMode),
				try OCIImageCache(runMode: runMode),
				try CloudImageCache(runMode: runMode),
				try RawImageCache(runMode: runMode),
				try SimpleStreamsImageCache(name: "", runMode: runMode),
			]

			_ = try purgeableStorages.map { imageCache in
				var purgeables = try imageCache.purgeables()

				purgeables.sort { left, right in
					left.url.lastPathComponent < right.url.lastPathComponent
				}

				try purgeables.forEach { purgeable in
					vmInfos.append(
						VirtualMachineInfo(
							type: imageCache.type(),
							source: purgeable.source(),
							name: purgeable.name(),
							fqn: imageCache.fqn(purgeable),
							instanceID: "",
							diskSize: try purgeable.allocatedSizeBytes(),
							totalSize: try purgeable.allocatedSizeBytes(),
							state: "cached",
							ip: nil,
							fingerprint: purgeable.fingerprint()
						)
					)
				}
			}
		}

		return vmInfos
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let result = try Self.list(vmonly: self.vmonly, runMode: runMode)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.list = Caked_VirtualMachineInfoReply.with {
					$0.infos = result.map {
						$0.toCaked_VirtualMachineInfo()
					}
				}
			}
		}
	}
}
