import ArgumentParser
import Foundation
import TextTable
import CakeAgentLib

extension Data {
	func toString() -> String {
		return String(decoding: self, as: UTF8.self)
	}
}

public struct ShortInfoReply: Sendable, Codable {
	public let name: String
	public let ipaddresses: String
	public let cpuCount: String
	public let memory: String

	public init(name: String, ipaddresses: [String], cpuCount: Int32, memory: UInt64) {
		self.name = name
		self.ipaddresses = ipaddresses.joined(separator: ", ")
		self.cpuCount = "\(cpuCount)"
		self.memory = ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory)
	}

	public init(ipaddress: String) {
		self.name = ""
		self.ipaddresses = ipaddress
		self.cpuCount = ""
		self.memory = ""
	}
}

extension InfoReply {
	static func with(infos: Caked_InfoReply) -> InfoReply  {
		var memory: InfoReply.MemoryInfo? = nil

		memory = infos.hasMemory ? InfoReply.MemoryInfo.with {
			let memory = infos.memory

			$0.total = memory.total
			$0.free = memory.hasFree ? memory.free : nil
			$0.used = memory.hasUsed ? memory.used : nil
		} : nil

		return InfoReply.with {
			$0.name = infos.name
			$0.version = infos.hasVersion ? infos.version : nil
			$0.uptime = infos.hasUptime ? infos.uptime : nil
			$0.cpuCount = infos.cpuCount
			$0.ipaddresses = infos.ipaddresses
			$0.osname = infos.osname
			$0.hostname = infos.hasHostname ? infos.hostname : nil
			$0.release = infos.hasRelease ? infos.release : nil
			$0.status = .init(rawValue: infos.status) ?? .unknown
			$0.mounts = infos.mounts
			$0.memory = memory
		}
	}
}

public enum Format: String, ExpressibleByArgument, CaseIterable, Sendable {
	case text, json

	public private(set) static var allValueStrings: [String] = Format.allCases.map { "\($0)"}

	public func renderSingle<T>(style: TextTableStyle.Type = Style.plain, uppercased: Bool = false, _ data: T) -> String where T: Encodable {
		switch self {
		case .text:
			return renderList(style: style, uppercased: uppercased, [data])
		case .json:
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
			return try! encoder.encode(data).toString()
		}
	}

	public func renderList<T>(style: TextTableStyle.Type = Style.plain, uppercased: Bool = false, _ data: Array<T>) -> String where T: Encodable {
		switch self {
		case .text:
			if (data.count == 0) {
				return ""
			}
			let table = TextTable<T> { (item: T) in
				return Mirror(reflecting: item).children.enumerated()
					.map { (_, element) in
						let label = element.label ?? "<unknown>"
						return Column(title: uppercased ? label.uppercased() : label, value: element.value)
					}
			}

			return table.string(for: data, style: style)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		case .json:
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
			return try! encoder.encode(data).toString()
		}
	}
	
	public func render(_ data: [Caked_ImageInfo]) -> String {
		if self == .text {
			return self.renderList(style: Style.grid, uppercased: true, data.map { ShortImageInfo(from: $0) })
		} else {
			return self.renderList(style: Style.grid, uppercased: true, data.map { ImageInfo(from: $0) })
		}
	}

	public func render(_ data: ImageInfos) -> String {
		if self == .json {
			return self.renderList(style: Style.grid, uppercased: true, data)
		} else {
			return self.renderList(style: Style.grid, uppercased: true, data.map { ShortImageInfo(imageInfo: $0) })
		}
	}

	public func render(_ data: ImageInfo) -> String {
		if self == .json {
			return self.renderSingle(style: Style.grid, uppercased: true, data)
		} else {
			return self.renderSingle(style: Style.grid, uppercased: true, ShortImageInfo(imageInfo: data))
		}
	}

	public func render(_ data: Caked_ImageInfo) -> String {
		self.render(ImageInfo(from: data))
	}
	
	public func render(_ data: LinuxContainerImage) -> String {
		if self == .json {
			return self.renderSingle(style: Style.grid, uppercased: true, data)
		} else {
			return self.renderSingle(style: Style.grid, uppercased: true, ShortLinuxContainerImage(image: data))
		}
	}

	public func render(_ data: Caked_PulledImageInfo) -> String {
		self.render(LinuxContainerImage(from: data))
	}
	
	public func render(_ data: InfoReply) -> String {
		if self == .json {
			return self.renderSingle(style: Style.grid, uppercased: true, data)
		} else {
			return self.renderSingle(style: Style.grid, uppercased: true, ShortInfoReply(name: data.name, ipaddresses: data.ipaddresses, cpuCount: data.cpuCount, memory: data.memory?.total ?? 0))
		}
	}

	public func render(_ data: Caked_InfoReply) -> String {
		return self.render(InfoReply.with(infos: data))
	}

	public func render(_ data: [DeleteReply]) -> String {
		return self.renderList(style: Style.grid, uppercased: true, data)
	}

	public func render(_ data: Caked_DeleteReply) -> String {
		return self.render(data.objects.map{ DeleteReply(from: $0) })
	}

	public func render(_ data: VirtualMachineInfos) -> String {
		if self == .json {
			return self.renderList(style: Style.grid, uppercased: true, data)
		} else {
			return self.renderList(style: Style.grid, uppercased: true, data.reduce(into: [ShortVirtualMachineInfo]()) { result, vm in
				if vm.fqn.count > 1 {
					vm.fqn.forEach { fqn in
						result.append(ShortVirtualMachineInfo(from: VirtualMachineInfo(
							type: vm.type,
							source: vm.source,
							name: fqn.stringAfter(after: "//"),
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
					result.append(ShortVirtualMachineInfo(from: vm))
				}
			})
		}
	}

	public func render(_ data: Caked_VirtualMachineInfoReply) -> String {
		return self.render(VirtualMachineInfos(from: data.infos))
	}

	public func render(_ data: [MountVirtioFS]) -> String {
		return self.renderList(style: Style.grid, uppercased: true, data)
	}

	public func render(_ data: MountInfos) -> String {
		return self.render(data.mounts)
	}

	public func render(_ data: Caked_MountReply) -> String {
		return self.render(data.mounts.map { MountVirtioFS(from: $0) })
	}
	
	public func render(_ data: BridgedNetwork) -> String {
		return self.renderSingle(style: Style.grid, uppercased: true, data)
	}

	public func render(_ data: Caked_NetworkInfo) -> String {
		return self.render(BridgedNetwork(from: data))
	}

	public func render(_ data: [BridgedNetwork]) -> String {
		return self.renderList(style: Style.grid, uppercased: true, data)
	}

	public func render(_ data: Caked_ListNetworksReply) -> String {
		return self.render(data.networks.map { BridgedNetwork(from: $0) })
	}
	
	public func render(_ data: [RemoteEntry]) -> String {
		return self.renderList(style: Style.grid, uppercased: true, data)
	}

	public func render(_ data: Caked_ListRemoteReply) -> String {
		return self.render(data.remotes.map { RemoteEntry(from: $0) })
	}
	
	public func render(_ data: CreateTemplateReply) -> String {
		return self.renderSingle(style: Style.grid, uppercased: true, data)
	}

	public func render(_ data: Caked_CreateTemplateReply) -> String {
		return self.renderSingle(style: Style.grid, uppercased: true, CreateTemplateReply(from: data))
	}
	
	public func render(_ data: DeleteTemplateReply) -> String {
		return self.renderSingle(style: Style.grid, uppercased: true, data)
	}

	public func render(_ data: Caked_DeleteTemplateReply) -> String {
		return self.render(DeleteTemplateReply(from: data))
	}

	public func render(_ data: [TemplateEntry]) -> String {
		if self == .json {
			return self.renderList(style: Style.grid, uppercased: true, data)
		} else {
			return self.renderList(style: Style.grid, uppercased: true, data.map { ShortTemplateEntry(from: $0) })
		}
	}

	public func render(_ data: Caked_ListTemplatesReply) -> String {
		if self == .json {
			return self.renderList(style: Style.grid, uppercased: true, data.templates.map { TemplateEntry(from: $0) })
		} else {
			return self.renderList(style: Style.grid, uppercased: true, data.templates.map { ShortTemplateEntry(from: $0) })
		}
	}
}
