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
	let fqn: String
	let diskSize: Int
	let totalSize: Int
	let state: String
}

struct ShortVirtualMachineInfos: Codable {
	let type: String
	let fqn: String
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
				type: "vm",
				source: "vms",
				name: name,
				fqn: "vm://\(name)",
				diskSize: try location.diskSize(),
				totalSize: try location.allocatedSize(),
				state: location.status.rawValue
			)
		}

		vmInfos.sort { vm1, vm2 in
			vm1.fqn < vm2.fqn
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
							type: imageCache.location,
							source: purgeable.source(),
							name: purgeable.name(),
							fqn: imageCache.fqn(purgeable),
							diskSize: try purgeable.allocatedSizeBytes(),
							totalSize: try purgeable.allocatedSizeBytes(),
							state: "cached"
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
			return format.renderList(style: Style.grid, uppercased: true, result.map {
				ShortVirtualMachineInfos(type: $0.type,
				fqn: $0.fqn,
				diskSize: ByteCountFormatter.string(fromByteCount: Int64($0.diskSize), countStyle: .file),
				totalSize: ByteCountFormatter.string(fromByteCount: Int64($0.totalSize), countStyle: .file),
				state: $0.state)
			})
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> String {
		try Self.listVM(vmonly: self.vmonly, format: self.format, asSystem: asSystem)
	}
}