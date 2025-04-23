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

	public func toCaked_InfoReply() -> Caked_InfoReply {
		Caked_InfoReply.with { reply in
			reply.name = self.name

			if let version = self.version {
				reply.version = version
			}

			if let uptime = self.uptime {
				reply.uptime = uptime
			}

			if let memory = self.memory {
				reply.memory = Caked_InfoReply.MemoryInfo.with {
					if let total = memory.total {
						$0.total = total
					}

					if let free = memory.free {
						$0.free = free
					}

					if let used = memory.used {
						$0.used = used
					}
				}
			}

			reply.cpuCount = self.cpuCount
			reply.ipaddresses = self.ipaddresses
			reply.osname = self.osname

			if let release = self.release {
				reply.release = release
			}

			if let hostname = self.hostname {
				reply.hostname = hostname
			}

			if let mounts = self.mounts {
				reply.mounts = mounts
			}

			reply.status = self.status.rawValue
		}
	}
}

public enum Format: String, ExpressibleByArgument, CaseIterable, Sendable, Codable, EnumerableFlag {
	case text, json

	public private(set) static var allValueStrings: [String] = Format.allCases.map { "\($0)"}

	public func renderSingle<T>(style: TextTableStyle.Type = Style.grid, uppercased: Bool = true, _ data: T) -> String where T: Encodable {
		switch self {
		case .text:
			return renderList(style: style, uppercased: uppercased, [data])
		case .json:
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
			return try! encoder.encode(data).toString()
		}
	}

	public func renderList<T>(style: TextTableStyle.Type = Style.grid, uppercased: Bool = true, _ data: Array<T>) -> String where T: Encodable {
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
			return self.renderList(data.map { ShortImageInfo(from: $0) })
		} else {
			return self.renderList(data.map { ImageInfo(from: $0) })
		}
	}

	public func render(_ data: String) -> String {
		if self == .json {
			return self.renderSingle(["output": data])
		} else {
			return data
		}
	}

	public func render(_ data: ImageInfos) -> String {
		if self == .json {
			return self.renderList(data)
		} else {
			return self.renderList(data.map { ShortImageInfo(imageInfo: $0) })
		}
	}

	public func render(_ data: ImageInfo) -> String {
		if self == .json {
			return self.renderSingle(data)
		} else {
			return self.renderSingle(ShortImageInfo(imageInfo: data))
		}
	}

	public func render(_ data: Caked_ImageInfo) -> String {
		self.render(ImageInfo(from: data))
	}

	public func render(_ data: LinuxContainerImage) -> String {
		if self == .json {
			return self.renderSingle(data)
		} else {
			return self.renderSingle(ShortLinuxContainerImage(image: data))
		}
	}

	public func render(_ data: Caked_PulledImageInfo) -> String {
		self.render(LinuxContainerImage(from: data))
	}

	public func render(_ data: InfoReply) -> String {
		if self == .json {
			return self.renderSingle(data)
		} else {
			return self.renderSingle(ShortInfoReply(name: data.name, ipaddresses: data.ipaddresses, cpuCount: data.cpuCount, memory: data.memory?.total ?? 0))
		}
	}

	public func render(_ data: Caked_InfoReply) -> String {
		return self.render(InfoReply.with(infos: data))
	}

	public func render(_ data: [DeleteReply]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: Caked_DeleteReply) -> String {
		return self.render(data.objects.map{ DeleteReply(from: $0) })
	}

	public func render(_ data: [StopReply]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: Caked_StopReply) -> String {
		return self.render(data.objects.map{ StopReply(from: $0) })
	}

	public func render(_ data: VirtualMachineInfos) -> String {
		if self == .json {
			return self.renderList(data)
		} else {
			return self.renderList(data.reduce(into: [ShortVirtualMachineInfo]()) { result, vm in
				if vm.fqn.count > 1 {
					vm.fqn.forEach {
						let fqn = $0.stringAfter(after: "//")

						if fqn.isFingerPrint() == false {
							result.append(ShortVirtualMachineInfo(from: VirtualMachineInfo(
								type: vm.type,
								source: vm.source,
								name: fqn.stringAfter(after: "//"),
								fqn: [$0],
								instanceID: vm.instanceID,
								diskSize: vm.diskSize,
								totalSize: vm.totalSize,
								state: vm.state,
								ip: vm.ip,
								fingerprint: vm.fingerprint
							)))
						}
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
		return self.renderList(data)
	}

	public func render(_ data: MountInfos) -> String {
		return self.render(data.mounts)
	}

	public func render(_ data: Caked_MountReply) -> String {
		return self.render(data.mounts.map { MountVirtioFS(from: $0) })
	}

	public func render(_ data: BridgedNetwork) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_NetworkInfo) -> String {
		return self.render(BridgedNetwork(from: data))
	}

	public func render(_ data: [BridgedNetwork]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: Caked_ListNetworksReply) -> String {
		return self.render(data.networks.map { BridgedNetwork(from: $0) })
	}

	public func render(_ data: [RemoteEntry]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: Caked_ListRemoteReply) -> String {
		return self.render(data.remotes.map { RemoteEntry(from: $0) })
	}

	public func render(_ data: CreateTemplateReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_CreateTemplateReply) -> String {
		return self.renderSingle(CreateTemplateReply(from: data))
	}

	public func render(_ data: DeleteTemplateReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_DeleteTemplateReply) -> String {
		return self.render(DeleteTemplateReply(from: data))
	}

	public func render(_ data: [TemplateEntry]) -> String {
		if self == .json {
			return self.renderList(data)
		} else {
			return self.renderList(data.map { ShortTemplateEntry(from: $0) })
		}
	}

	public func render(_ data: Caked_ListTemplatesReply) -> String {
		if self == .json {
			return self.renderList(data.templates.map { TemplateEntry(from: $0) })
		} else {
			return self.renderList(data.templates.map { ShortTemplateEntry(from: $0) })
		}
	}
}
