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
	let diskSize: String
	let totalSize: String
	let state: String
}

struct ListHandler: CakedCommand {
	let format: Format
	let vmonly: Bool

	static func listVM(vmonly: Bool, asSystem: Bool) throws -> [VirtualMachineInfos] {
		var vmInfos = try StorageLocation(asSystem: asSystem).list().map { (name: String, location: VMLocation) in
			VirtualMachineInfos(
				type: "local",
				source: "vms",
				name: name,
				diskSize: try ByteCountFormatter.string(fromByteCount: Int64(location.diskSize()), countStyle: .file),
				totalSize: try ByteCountFormatter.string(fromByteCount: Int64(location.allocatedSize()), countStyle: .file),
				state: location.status.rawValue
			)
		}

		vmInfos.sort { vm1, vm2 in
			vm1.name < vm2.name
		}

		if vmonly == false {
			let purgeableStorages = [try OCIImageCache(), try CloudImageCache(), try RawImageCache(), try SimpleStreamsImageCache(name: "")]

			_ = try purgeableStorages.map { imageCache in
				var purgeables = try imageCache.purgeables()

				purgeables.sort { left, right in
					left.url.lastPathComponent < right.url.lastPathComponent
				}

				try purgeables.forEach { purgeable in
					vmInfos.append(
						VirtualMachineInfos(
							type: imageCache.location,
							source: purgeable.source(),
							name: purgeable.name(),
							diskSize: try ByteCountFormatter.string(fromByteCount: Int64(purgeable.allocatedSizeBytes()), countStyle: .file),
							totalSize: try ByteCountFormatter.string(fromByteCount: Int64(purgeable.allocatedSizeBytes()), countStyle: .file),
							state: "cached"
						)
					)
				}
			}
		}

		return vmInfos
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		on.submit {
			return format.renderList(style: Style.grid, uppercased: true, try Self.listVM(vmonly: vmonly, asSystem: asSystem))
		}
	}
}