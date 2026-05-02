import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration
import CakeAgentLib

public struct ListHandler {
	public static func list(vmonly: Bool, includeConfig: Bool, runMode: Utils.RunMode) -> VirtualMachineInfoReply {
		do {
			var vmInfos = try StorageLocation(runMode: runMode).list().map { (name: String, location: VMLocation) in
				let status = location.status
				let config = try location.config()
				var vncInfos = VNCInfos()
				var runningIP: String? = nil

				if case .running = status {
					runningIP = config.runningIP
					if let infos = try? VNCInfosHandler.vncInfos(location: location, runMode: runMode) {
						vncInfos = infos
					}
				}

				return VirtualMachineInfo(
					type: "vm",
					source: "vms",
					name: name,
					fqn: ["\(VMLocation.scheme)://\(name)"],
					vncURL: vncInfos.urls,
					screenSize: vncInfos.screenSize,
					instanceID: config.instanceID,
					diskSize: try location.diskSize(),
					sizeOnDisk: try location.allocatedSize(),
					state: status.description,
					ip: runningIP,
					fingerprint: nil,
					config: includeConfig ? CakedConfiguration(config) : nil
				)
			}

			vmInfos.sort { vm1, vm2 in
				vm1.fqn.joined(separator: ",") < vm2.fqn.joined(separator: ",")
			}

			if vmonly == false {
				let purgeableStorages: [PurgeableStorage] = [
					try TemplateImageCache(runMode: runMode),
					try PurgeableContentStore(runMode: runMode),
					try OCIImageCache(runMode: runMode),
					try CloudImageCache(runMode: runMode),
					try RawImageCache(runMode: runMode),
					try IPSWCache(runMode: runMode),
					try IsoCache(runMode: runMode),
					try SimpleStreamsImageCache(name: String.empty, runMode: runMode),
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
								source: purgeable.source,
								name: purgeable.name,
								fqn: imageCache.fqn(purgeable),
								vncURL: nil,
								screenSize: nil,
								instanceID: String.empty,
								diskSize: try purgeable.sizeBytes(),
								sizeOnDisk: try purgeable.allocatedSizeBytes(),
								state: "cached",
								ip: nil,
								fingerprint: purgeable.fingerprint
							)
						)
					}
				}
			}

			return VirtualMachineInfoReply(infos: vmInfos, success: true, reason: String(localized: "Success"))
		} catch {
			return VirtualMachineInfoReply(infos: [], success: false, reason: error.reason)
		}
	}
}
