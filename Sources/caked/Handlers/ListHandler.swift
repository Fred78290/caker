import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import NIOCore
import TextTable

struct ListHandler: CakedCommand {
	let vmonly: Bool

	static func list(vmonly: Bool, asSystem: Bool) throws -> [VirtualMachineInfo] {
		var vmInfos = try StorageLocation(asSystem: asSystem).list().map { (name: String, location: VMLocation) in
			let status = location.status
			let config = try location.config()

			return VirtualMachineInfo(
				type: "vm",
				source: "vms",
				name: name,
				fqn: ["vm://\(name)"],
				instanceID: config.instanceID,
				diskSize: try UInt32(location.diskSize()),
				totalSize: try UInt32(location.allocatedSize()),
				state: status.rawValue,
				ip: status == .running ? config.runningIP : nil,
				fingerprint: nil
			)
		}

		vmInfos.sort { vm1, vm2 in
			vm1.fqn.joined(separator: ",") < vm2.fqn.joined(separator: ",")
		}

		if vmonly == false {
			let purgeableStorages = [try TemplateImageCache(), try OCIImageCache(), try CloudImageCache(), try RawImageCache(), try SimpleStreamsImageCache(name: "")]

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
							diskSize: try UInt32(purgeable.allocatedSizeBytes()),
							totalSize: try UInt32(purgeable.allocatedSizeBytes()),
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

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		let result = try Self.list(vmonly: self.vmonly, asSystem: asSystem)

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
