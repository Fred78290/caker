import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import NIOCore
import TextTable

struct VirtualMachineInfos: Codable {
	let type: String
	let source: String
	let name: String
	let fqn: [String]
	let instanceID: String?
	let diskSize: UInt32
	let totalSize: UInt32
	let state: String
	let ip: String?
	let fingerprint: String?

	func toCaked_VirtualMachineInfo() -> Caked_VirtualMachineInfo {
		Caked_VirtualMachineInfo.with { info in
			info.type = self.type
			info.source = self.source
			info.name = self.name
			info.fqn = self.fqn
			info.diskSize = self.diskSize
			info.totalSize = self.totalSize
			info.state = self.state

			if let instanceID: String = self.instanceID {
				info.instanceID = instanceID
			}

			if let ip = self.ip {
				info.ip = ip
			}

			if let fingerprint = self.fingerprint {
				info.fingerprint = fingerprint
			}
		}
	}
}

struct ShortVirtualMachineInfos: Codable {
	let type: String
	let fqn: String
	let instanceID: String
	let ip: String
	let diskSize: String
	let totalSize: String
	let state: String
	let fingerprint: String

	init(from: VirtualMachineInfos) {
		self.type = from.type
		self.fqn = from.fqn.joined(separator: " ")
		self.ip = from.ip ?? ""
		self.instanceID = from.instanceID ?? ""
		self.diskSize = ByteCountFormatter.string(fromByteCount: Int64(from.diskSize), countStyle: .file)
		self.totalSize = ByteCountFormatter.string(fromByteCount: Int64(from.totalSize), countStyle: .file)
		self.state = from.state
		self.fingerprint = from.fingerprint != nil ? from.fingerprint!.substring(..<12) : ""
	}
}

struct ListHandler: CakedCommand {
	let vmonly: Bool

	static func listVM(vmonly: Bool, asSystem: Bool) throws -> [VirtualMachineInfos] {
		var vmInfos = try StorageLocation(asSystem: asSystem).list().map { (name: String, location: VMLocation) in
			let status = location.status
			let config = try location.config()

			return VirtualMachineInfos(
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
						VirtualMachineInfos(
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

	static func listVM(vmonly: Bool, format: Format, asSystem: Bool) throws -> String {
		let result: [VirtualMachineInfos] = try Self.listVM(vmonly: vmonly, asSystem: asSystem)

		if format == .json {
			return format.renderList(style: Style.grid, uppercased: true, result)
		} else {
			return format.renderList(style: Style.grid, uppercased: true, result.reduce(into: [ShortVirtualMachineInfos]()) { result, vm in
				if vm.fqn.count > 1 {
					vm.fqn.forEach { fqn in
						result.append(ShortVirtualMachineInfos(from: VirtualMachineInfos(
							type: vm.type,
							source: vm.source,
							name: vm.name,
							fqn: [fqn],
							instanceID: vm.instanceID,
							diskSize: vm.diskSize,
							totalSize: vm.totalSize,
							state: vm.state,
							ip: vm.ip,
							fingerprint: vm.fingerprint
						)))
					}
				} else {
					result.append(ShortVirtualMachineInfos(from: vm))
				}
			})
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		let result = try Self.listVM(vmonly: self.vmonly, asSystem: asSystem)

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
