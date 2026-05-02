import ArgumentParser
import CakeAgentLib
import Foundation
import NIOPortForwarding
import TextTable

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
	public let vncURL: String

	public init(name: String, ipaddresses: [String], cpuCount: Int32, memory: UInt64, vncURL: String?) {
		self.name = name
		self.ipaddresses = ipaddresses.joined(separator: ", ")
		self.cpuCount = "\(cpuCount)"
		self.memory = ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory)
		self.vncURL = vncURL == nil ? String.empty : vncURL!
	}

	public init(ipaddress: String) {
		self.name = String.empty
		self.ipaddresses = ipaddress
		self.cpuCount = String.empty
		self.memory = String.empty
		self.vncURL = String.empty
	}
}

extension CakeAgentLib.AttachedNetwork {
	init(_ from: Caked_InfoReply.AttachedNetwork) {
		self.init()
		self.network = from.network

		if from.hasMode {
			self.mode = from.mode
		}

		if from.hasMacAddress {
			self.macAddress = from.macAddress
		}
	}
}

extension Caked_InfoReply.AttachedNetwork {
	init(_ from: CakeAgentLib.AttachedNetwork) {
		self.network = from.network

		if let mode = from.mode {
			self.mode = mode
		}

		if let macAddress = from.macAddress {
			self.macAddress = macAddress
		}
	}
}

extension CakeAgentLib.TunnelInfo {
	init?(_ from: Caked_InfoReply.TunnelInfo) {
		if case .forward(let value) = from.tunnel {
			self.init(forward: ForwardedPort(proto: value.protocol.mappedPort, host: Int(value.host), guest: Int(value.guest)))
		} else if case .unixDomain(let value) = from.tunnel {
			self.init(unixDomain: UnixDomainSocket(proto: value.protocol.mappedPort, host: value.host, guest: value.guest))
		} else {
			return nil
		}
	}
}

extension Caked_InfoReply.TunnelInfo.ProtocolEnum {
	var mappedPort: MappedPort.Proto {
		switch self {
		case .tcp: return .tcp
		case .udp: return .udp
		default: return .tcp
		}
	}

	init(_ from: MappedPort.Proto) {
		switch from {
		case .tcp: self = .tcp
		case .udp: self = .udp
		default: fatalError()
		}
	}
}

extension Caked_InfoReply.TunnelInfo {
	init?(_ from: CakeAgentLib.TunnelInfo) {
		if case .forward(let value) = from.oneOf {
			self.forward = Caked_InfoReply.TunnelInfo.ForwardedPort.with {
				$0.protocol = .init(value.proto)
				$0.host = Int32(value.host)
				$0.guest = Int32(value.guest)
			}
		} else if case .unixDomain(let value) = from.oneOf {
			self.unixDomain = Caked_InfoReply.TunnelInfo.Tunnel.with {
				$0.protocol = .init(value.proto)
				$0.host = value.host
				$0.guest = value.guest
			}
		} else {
			return nil
		}
	}
}

extension CakeAgentLib.SocketInfo {
	init(_ from: Caked_InfoReply.SocketInfo) {
		self.init(mode: SocketInfo.Mode(rawValue: from.mode.rawValue) ?? .bind, host: from.host, port: from.port)
	}
}

extension Caked_InfoReply.SocketInfo {
	init(_ from: CakeAgentLib.SocketInfo) {
		self.mode = .init(rawValue: self.mode.rawValue) ?? .bind
		self.host = from.host
		self.port = from.port
	}
}

extension InfoReply {
	static func with(infos: Caked_InfoReply) -> InfoReply {
		var memory: InfoReply.MemoryInfo? = nil

		memory =
			infos.hasMemory
			? InfoReply.MemoryInfo.with {
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
			$0.status = infos.status.agentStatus
			$0.mounts = infos.mounts
			$0.memory = memory
			$0.attachedNetworks = infos.networks.compactMap { CakeAgentLib.AttachedNetwork($0) }
			$0.tunnelInfos = infos.tunnels.compactMap { CakeAgentLib.TunnelInfo($0) }
			$0.socketInfos = infos.sockets.compactMap { CakeAgentLib.SocketInfo($0) }
		}
	}

	public var caked: Caked_InfoReply {
		Caked_InfoReply.with { reply in
			reply.name = self.name
			reply.diskInfos = self.diskInfos.map { diskInfos in
				Caked_InfoReply.DiskInfo.with {
					$0.device = diskInfos.device
					$0.mount = diskInfos.mount
					$0.fsType = diskInfos.fsType
					$0.size = diskInfos.total
					$0.free = diskInfos.free
					$0.used = diskInfos.used
				}
			}

			if let version = self.version {
				reply.version = version
			}

			if let uptime = self.uptime {
				reply.uptime = uptime
			}

			if let memory = self.memory {
				reply.memory = Caked.MemoryInfo.with {
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

			reply.status = .init(agentStatus: self.status)

			if let attachedNetworks = self.attachedNetworks {
				reply.networks = attachedNetworks.map { Caked_InfoReply.AttachedNetwork($0) }
			}

			if let tunnelInfos = self.tunnelInfos {
				reply.tunnels = tunnelInfos.compactMap { Caked_InfoReply.TunnelInfo($0) }
			}

			if let sockets = self.socketInfos {
				reply.sockets = sockets.map { Caked_InfoReply.SocketInfo($0) }
			}
		}
	}
}

extension CakeAgentLib.Format {
	public func render(_ data: [Caked_ImageInfo]) -> String {
		if self == .text {
			return self.renderList(data.map { ShortImageInfo($0) })
		} else {
			return self.renderList(data.map { ImageInfo($0) })
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
			return self.renderList(data.map { ShortImageInfo($0) })
		}
	}

	public func render(_ data: ImageInfo) -> String {
		if self == .json {
			return self.renderSingle(data)
		} else {
			return self.renderSingle(ShortImageInfo(data))
		}
	}

	public func render(_ data: LoginReply) -> String {
		self.renderSingle(data)
	}

	public func render(_ data: Caked_LoginReply) -> String {
		self.renderSingle(LoginReply(data))
	}

	public func render(_ data: LogoutReply) -> String {
		self.renderSingle(data)
	}

	public func render(_ data: Caked_LogoutReply) -> String {
		self.renderSingle(LogoutReply(data))
	}

	public func render(_ data: PullReply) -> String {
		self.renderSingle(data)
	}

	public func render(_ data: Caked_PullReply) -> String {
		self.renderSingle(PullReply(data))
	}

	public func render(_ data: PushReply) -> String {
		self.renderSingle(data)
	}

	public func render(_ data: Caked_PushReply) -> String {
		self.renderSingle(PushReply(data))
	}

	public func render(_ data: Caked_ImageInfo) -> String {
		self.render(ImageInfo(data))
	}

	public func render(_ data: LinuxContainerImage) -> String {
		if self == .json {
			return self.renderSingle(data)
		} else {
			return self.renderSingle(ShortLinuxContainerImage(data))
		}
	}

	public func render(_ data: Caked_PulledImageInfo) -> String {
		self.render(LinuxContainerImage(data))
	}

	public func render(_ data: InfoReply) -> String {
		if self == .json {
			return self.renderSingle(data)
		} else {
			return self.renderSingle(ShortInfoReply(name: data.name, ipaddresses: data.ipaddresses, cpuCount: data.cpuCount, memory: data.memory?.total ?? 0, vncURL: nil))
		}
	}

	public func render(_ data: VMInformations) -> String {
		if self == .json {
			return self.renderSingle(data)
		} else {
			return self.renderSingle(ShortInfoReply(name: data.name, ipaddresses: data.ipaddresses, cpuCount: data.cpuCount, memory: data.memory?.total ?? 0, vncURL: data.vncURL?.first))
		}
	}

	public func render(_ data: Caked_InfoReply) -> String {
		return self.render(InfoReply.with(infos: data))
	}

	public func render(_ data: [DeletedObject]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: [Caked_DeletedObject]) -> String {
		return self.renderList(data.map { DeletedObject($0) })
	}

	public func render(_ data: [RestartedObject]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: [Caked_RestartObject]) -> String {
		return self.renderList(data.map { RestartedObject($0) })
	}

	public func render(_ data: [SuspendedObject]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: [Caked_SuspendedObject]) -> String {
		return self.renderList(data.map { SuspendedObject($0) })
	}

	public func render(_ data: [StoppedObject]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: [Caked_StoppedObject]) -> String {
		return self.renderList(data.map { StoppedObject($0) })
	}

	public func render(_ data: LaunchReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_LaunchReply) -> String {
		return self.renderSingle(LaunchReply(data))
	}

	public func render(_ data: StartedReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_StartedReply) -> String {
		return self.renderSingle(StartedReply(data))
	}

	public func render(_ data: BuildedReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_BuildedReply) -> String {
		return self.renderSingle(BuildedReply(data))
	}

	public func render(_ data: ClonedReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_ClonedReply) -> String {
		return self.renderSingle(ClonedReply(data))
	}

	public func render(_ data: ConfiguredReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_ConfiguredReply) -> String {
		return self.renderSingle(ConfiguredReply(data))
	}

	public func render(_ data: DuplicatedReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_DuplicatedReply) -> String {
		return self.renderSingle(DuplicatedReply(data))
	}

	public func render(_ data: ImportedReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_ImportedReply) -> String {
		return self.renderSingle(ImportedReply(data))
	}

	public func render(_ data: WaitIPReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_WaitIPReply) -> String {
		return self.renderSingle(WaitIPReply(data))
	}

	public func render(_ data: PurgeReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_PurgeReply) -> String {
		return self.renderSingle(PurgeReply(data))
	}

	public func render(_ data: RenameReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_RenameReply) -> String {
		return self.renderSingle(RenameReply(data))
	}

	public func render(_ data: VirtualMachineInfos) -> String {
		if self == .json {
			return self.renderList(data)
		} else {
			return self.renderList(
				data.reduce(into: [ShortVirtualMachineInfo]()) { result, vm in
					if vm.fqn.count > 1 {
						vm.fqn.forEach {
							let fqn = $0.stringAfter(after: "//")

							if fqn.isFingerPrint() == false {
								result.append(
									ShortVirtualMachineInfo(
										VirtualMachineInfo(
											type: vm.type,
											source: vm.source,
											name: fqn.stringAfter(after: "//"),
											fqn: [$0],
											vncURL: vm.vncURL,
											screenSize: vm.screenSize,
											instanceID: vm.instanceID,
											diskSize: vm.diskSize,
											sizeOnDisk: vm.sizeOnDisk,
											state: vm.state,
											mode: vm.mode,
											ip: vm.ip,
											fingerprint: vm.fingerprint
										)))
							}
						}
					} else {
						result.append(ShortVirtualMachineInfo(vm))
					}
				})
		}
	}

	public func render(_ data: [Caked_VirtualMachineInfo]) -> String {
		return self.render(VirtualMachineInfos(data))
	}

	public func render(_ data: [MountVirtioFS]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: [Caked_MountVirtioFSReply]) -> String {
		return self.renderList(data.map { MountVirtioFS($0) })
	}

	public func render(_ data: BridgedNetwork) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_NetworkInfo) -> String {
		return self.renderSingle(BridgedNetwork(data))
	}

	public func render(_ data: [BridgedNetwork]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: [Caked_NetworkInfo]) -> String {
		return self.renderList(data.map { BridgedNetwork($0) })
	}

	public func render(_ data: CreatedNetworkReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_CreatedNetworkReply) -> String {
		return self.renderSingle(CreatedNetworkReply(data))
	}

	public func render(_ data: ConfiguredNetworkReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_ConfiguredNetworkReply) -> String {
		return self.renderSingle(ConfiguredNetworkReply(data))
	}

	public func render(_ data: DeleteNetworkReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_DeleteNetworkReply) -> String {
		return self.renderSingle(DeleteNetworkReply(data))
	}

	public func render(_ data: StartedNetworkReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_StartedNetworkReply) -> String {
		return self.renderSingle(StartedNetworkReply(data))
	}

	public func render(_ data: StoppedNetworkReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_StoppedNetworkReply) -> String {
		return self.render(StoppedNetworkReply(data))
	}

	public func render(_ data: [RemoteEntry]) -> String {
		return self.renderList(data)
	}

	public func render(_ data: [Caked_RemoteEntry]) -> String {
		return self.render(data.map { RemoteEntry($0) })
	}

	public func render(_ data: CreateRemoteReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_CreateRemoteReply) -> String {
		return self.renderSingle(CreateRemoteReply(data))
	}

	public func render(_ data: DeleteRemoteReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_DeleteRemoteReply) -> String {
		return self.renderSingle(DeleteRemoteReply(data))
	}

	public func render(_ data: CreateTemplateReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_CreateTemplateReply) -> String {
		return self.renderSingle(CreateTemplateReply(data))
	}

	public func render(_ data: DeleteTemplateReply) -> String {
		return self.renderSingle(data)
	}

	public func render(_ data: Caked_DeleteTemplateReply) -> String {
		return self.render(DeleteTemplateReply(data))
	}

	public func render(_ data: [TemplateEntry]) -> String {
		if self == .json {
			return self.renderList(data)
		} else {
			return self.renderList(data.map { ShortTemplateEntry($0) })
		}
	}

	public func render(_ data: Caked_ListTemplatesReply) -> String {
		if self == .json {
			return self.renderList(data.templates.map { TemplateEntry($0) })
		} else {
			return self.renderList(data.templates.map { ShortTemplateEntry($0) })
		}
	}
}
