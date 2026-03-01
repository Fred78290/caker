import CakeAgentLib
//
//  VMInfos.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//
import Foundation
import TextTable

public typealias VirtualMachineInfos = [VirtualMachineInfo]

extension VirtualMachineInfos {
	public init(from: [Caked_VirtualMachineInfo]) {
		self = from.compactMap {
			VirtualMachineInfo(from: $0)
		}
	}
}

extension Caked_InfoReplyCpuCoreInfo {
	var asCakeAgentLib: CpuInformations.CpuCoreInfo {
		CpuInformations.CpuCoreInfo(
			coreID: self.coreID,
			usagePercent: self.usagePercent,
			user: self.user,
			system: self.system,
			idle: self.idle,
			iowait: self.iowait,
			irq: self.irq,
			softirq: self.softirq,
			steal: self.steal,
			guest: self.guest,
			guestNice: self.guestNice)
	}
}

extension Caked_InfoReplyCpuInfo {
	var asCakeAgentLib: CpuInformations {
		CpuInformations(
			totalUsagePercent: self.totalUsagePercent,
			user: self.user,
			system: self.system,
			idle: self.idle,
			iowait: self.iowait,
			irq: self.irq,
			softirq: self.softirq,
			steal: self.steal,
			guest: self.guest,
			guestNice: self.guestNice,
			cores: self.cores.map(\.asCakeAgentLib))
	}
}

public struct VMInformations: Sendable, Codable {
	public var name: String
	public var version: String?
	public var uptime: UInt64?
	public var memory: InfoReply.MemoryInfo?
	public var cpuCount: Int32
	public var diskInfos: [DiskInfo]
	public var ipaddresses: [String]
	public var osname: String
	public var hostname: String?
	public var release: String?
	public var mounts: [String]?
	public var status: Status
	public var attachedNetworks: [AttachedNetwork]?
	public var tunnelInfos: [TunnelInfo]?
	public var socketInfos: [SocketInfo]?
	public var vncURL: [String]?
	public var cpuInfos: CpuInformations?
	public var agentVersion: String?

	public static func with(
		_ populator: (inout Self) throws -> Void
	) rethrows -> Self {
		var message = Self()
		try populator(&message)
		return message
	}

	public init() {
		self.name = ""
		self.version = nil
		self.uptime = 0
		self.memory = nil
		self.cpuCount = 0
		self.diskInfos = []
		self.ipaddresses = []
		self.osname = ""
		self.hostname = nil
		self.release = nil
		self.status = .stopped
		self.mounts = nil
		self.attachedNetworks = nil
		self.tunnelInfos = nil
		self.socketInfos = nil
		self.cpuInfos = nil
		self.agentVersion = nil
	}

	public init(from: InfoReply) {
		self.name = from.name
		self.version = from.version
		self.uptime = from.uptime
		self.memory = from.memory
		self.cpuCount = from.cpuCount
		self.diskInfos = from.diskInfos
		self.ipaddresses = from.ipaddresses
		self.osname = from.osname
		self.hostname = from.hostname
		self.release = from.release
		self.mounts = from.mounts
		self.status = .running
		self.attachedNetworks = nil
		self.tunnelInfos = nil
		self.socketInfos = nil
		self.cpuInfos = from.cpuInfo
		self.agentVersion = from.agentVersion
	}

	public init(from: Caked_InfoReply) {
		self.name = from.name
		self.version = from.version
		self.uptime = from.uptime
		self.cpuCount = from.cpuCount
		self.ipaddresses = from.ipaddresses
		self.osname = from.osname
		self.hostname = from.hostname
		self.release = from.release
		self.mounts = from.mounts
		self.status = .running
		self.agentVersion = from.agentVersion

		self.attachedNetworks = from.networks.map {
			AttachedNetwork(network: $0.network, mode: $0.mode, macAddress: $0.macAddress)
		}

		self.tunnelInfos = from.tunnels.compactMap {
			switch $0.tunnel {
			case .forward(let v):
				TunnelInfo(forward: .init(proto: v.protocol.mappedPort, host: Int(v.host), guest: Int(v.guest)))
			case .unixDomain(let v):
				TunnelInfo(unixDomain: .init(proto: v.protocol.mappedPort, host: v.host, guest: v.guest))
			case .none:
				nil
			}
		}

		self.socketInfos = from.sockets.map {
			SocketInfo(mode: .init(rawValue: $0.mode.rawValue)!, host: $0.host, port: $0.port)
		}

		self.diskInfos = from.diskInfos.map {
			DiskInfo(device: $0.device, mount: $0.mount, fsType: $0.fsType, total: $0.size, free: $0.free, used: $0.used)
		}

		self.memory = .with {
			$0.total = from.memory.total
			$0.free = from.memory.free
			$0.used = from.memory.used
		}

		if from.hasCpu {
			self.cpuInfos = from.cpu.asCakeAgentLib
		}
	}

	public var caked: Caked_InfoReply {
		Caked_InfoReply.with { reply in
			reply.success = true
			reply.reason = "Success"
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

			reply.status = .init(agentStatus: self.status)

			if let attachedNetworks = self.attachedNetworks {
				reply.networks = attachedNetworks.map { Caked_InfoReply.AttachedNetwork(from: $0) }
			}

			if let tunnelInfos = self.tunnelInfos {
				reply.tunnels = tunnelInfos.compactMap { Caked_InfoReply.TunnelInfo(from: $0) }
			}

			if let sockets = self.socketInfos {
				reply.sockets = sockets.map { Caked_InfoReply.SocketInfo(from: $0) }
			}

			reply.vncURL = self.vncURL ?? []

			if let cpuInfos = self.cpuInfos {
				reply.cpu = .with {
					$0.totalUsagePercent = cpuInfos.totalUsagePercent
					$0.user = cpuInfos.user
					$0.system = cpuInfos.system
					$0.idle = cpuInfos.idle
					$0.iowait = cpuInfos.iowait
					$0.irq = cpuInfos.irq
					$0.softirq = cpuInfos.softirq
					$0.steal = cpuInfos.steal
					$0.guest = cpuInfos.guest
					$0.guestNice = cpuInfos.guestNice
					$0.cores = cpuInfos.cores.map { core in
						.with {
							$0.coreID = core.coreID
							$0.usagePercent = core.usagePercent
							$0.user = core.user
							$0.system = core.system
							$0.idle = core.idle
							$0.iowait = core.iowait
							$0.irq = core.irq
							$0.softirq = core.softirq
							$0.steal = core.steal
							$0.guest = core.guest
							$0.guestNice = core.guestNice
						}
					}
				}
			}
		}
	}
}

public struct SuspendedObject: Codable {
	public let name: String
	public let suspended: Bool
	public let reason: String

	public init(from: Caked_SuspendedObject) {
		self.name = from.name
		self.suspended = from.suspended
		self.reason = from.reason
	}

	public init(name: String, suspended: Bool, reason: String) {
		self.name = name
		self.suspended = suspended
		self.reason = reason
	}

	public var caked: Caked_SuspendedObject {
		Caked_SuspendedObject.with { object in
			object.name = name
			object.suspended = suspended
			object.reason = reason
		}
	}
}

public struct SuspendReply: Codable {
	public let objects: [SuspendedObject]
	public let success: Bool
	public let reason: String

	public init(objects: [SuspendedObject], success: Bool, reason: String) {
		self.objects = objects
		self.reason = reason
		self.success = success
	}

	public init(from: Caked_SuspendReply) {
		self.objects = from.objects.map(SuspendedObject.init(from:))
		self.success = from.success
		self.reason = from.reason
	}

	public var caked: Caked_SuspendReply {
		Caked_SuspendReply.with { object in
			object.objects = self.objects.map(\.caked)
			object.success = self.success
			object.reason = self.reason
		}
	}
}

public struct StoppedObject: Codable {
	public let name: String
	public let stopped: Bool
	public let reason: String

	public init(from: Caked_StoppedObject) {
		self.name = from.name
		self.stopped = from.stopped
		self.reason = from.reason
	}

	public init(name: String, stopped: Bool, reason: String) {
		self.name = name
		self.stopped = stopped
		self.reason = reason
	}

	public var caked: Caked_StoppedObject {
		Caked_StoppedObject.with { object in
			object.name = name
			object.stopped = stopped
			object.reason = reason
		}
	}
}

public struct StopReply: Codable {
	public let objects: [StoppedObject]
	public let success: Bool
	public let reason: String

	public init(objects: [StoppedObject], success: Bool, reason: String) {
		self.objects = objects
		self.reason = reason
		self.success = success
	}

	public init(from: Caked_StopReply) {
		self.objects = from.objects.map(StoppedObject.init(from:))
		self.success = from.success
		self.reason = from.reason
	}

	public var caked: Caked_StopReply {
		Caked_StopReply.with { object in
			object.objects = self.objects.map(\.caked)
			object.success = self.success
			object.reason = self.reason
		}
	}
}

public struct RestartedObject: Codable {
	public var name: String
	public var restarted: Bool
	public var reason: String
	
	public init(from: Caked_RestartObject) {
		self.name = from.name
		self.restarted = from.restarted
		self.reason = from.reason
	}

	public init(name: String, restarted: Bool, reason: String) {
		self.name = name
		self.restarted = restarted
		self.reason = reason
	}

	public var caked: Caked_RestartObject {
		Caked_RestartObject.with { object in
			object.name = name
			object.restarted = restarted
			object.reason = reason
		}
	}
}

public struct RestartReply: Codable {
	public let objects: [RestartedObject]
	public let success: Bool
	public let reason: String

	public init(objects: [RestartedObject], success: Bool, reason: String) {
		self.objects = objects
		self.reason = reason
		self.success = success
	}

	public init(from: Caked_RestartReply) {
		self.objects = from.objects.map(RestartedObject.init(from:))
		self.success = from.success
		self.reason = from.reason
	}

	public var caked: Caked_RestartReply {
		Caked_RestartReply.with { object in
			object.objects = self.objects.map(\.caked)
			object.success = self.success
			object.reason = self.reason
		}
	}
}

public struct DeletedObject: Codable {
	public let source: String
	public let name: String
	public let deleted: Bool
	public let reason: String

	public init(from: Caked_DeletedObject) {
		self.source = from.source
		self.name = from.name
		self.deleted = from.deleted
		self.reason = from.reason
	}

	public init(source: String, name: String, deleted: Bool, reason: String) {
		self.name = name
		self.source = source
		self.deleted = deleted
		self.reason = reason
	}

	public var caked: Caked_DeletedObject {
		Caked_DeletedObject.with { object in
			object.source = source
			object.name = name
			object.deleted = deleted
			object.reason = reason
		}
	}
}

public struct DeleteReply: Codable {
	public let objects: [DeletedObject]
	public let success: Bool
	public let reason: String

	public init(objects: [DeletedObject], success: Bool, reason: String) {
		self.objects = objects
		self.success = success
		self.reason = reason
	}

	public init(from: Caked_DeleteReply) {
		self.success = from.success
		self.reason = from.reason
		self.objects = from.objects.map(DeletedObject.init(from:))
	}

	public var caked: Caked_DeleteReply {
		Caked_DeleteReply.with { object in
			object.success = success
			object.reason = reason
			object.objects = objects.map(\.caked)
		}
	}
}

public struct LaunchReply: Codable {
	public let name: String
	public let ip: String
	public let launched: Bool
	public let reason: String

	public init(from: Caked_LaunchReply) {
		self.name = from.name
		self.ip = from.address
		self.launched = from.launched
		self.reason = from.reason
	}

	public init(name: String, ip: String, launched: Bool, reason: String) {
		self.name = name
		self.ip = ip
		self.launched = launched
		self.reason = reason
	}

	public var caked: Caked_LaunchReply {
		Caked_LaunchReply.with { object in
			object.name = name
			object.launched = launched
			object.reason = reason
		}
	}
}

public struct StartedReply: Codable {
	public let name: String
	public let ip: String
	public let started: Bool
	public let reason: String

	public init(from: Caked_StartedReply) {
		self.name = from.name
		self.ip = from.address
		self.started = from.started
		self.reason = from.reason
	}

	public init(name: String, ip: String, started: Bool, reason: String) {
		self.name = name
		self.ip = ip
		self.started = started
		self.reason = reason
	}

	public var caked: Caked_StartedReply {
		Caked_StartedReply.with { object in
			object.name = name
			object.address = ip
			object.started = started
			object.reason = reason
		}
	}
}

public struct BuildedReply: Codable {
	public let name: String
	public let builded: Bool
	public let reason: String

	public init(from: Caked_BuildedReply) {
		self.name = from.name
		self.builded = from.builded
		self.reason = from.reason
	}

	public init(name: String, builded: Bool, reason: String) {
		self.name = name
		self.builded = builded
		self.reason = reason
	}

	public var caked: Caked_BuildedReply {
		Caked_BuildedReply.with { object in
			object.name = name
			object.builded = builded
			object.reason = reason
		}
	}
}

public struct ClonedReply: Codable {
	public let sourceName: String
	public let targetName: String
	public let cloned: Bool
	public let reason: String

	public init(from: Caked_ClonedReply) {
		self.sourceName = from.sourceName
		self.targetName = from.targetName
		self.cloned = from.cloned
		self.reason = from.reason
	}

	public init(sourceName: String, targetName: String, cloned: Bool, reason: String) {
		self.sourceName = sourceName
		self.targetName = targetName
		self.cloned = cloned
		self.reason = reason
	}

	public var caked: Caked_ClonedReply {
		Caked_ClonedReply.with { object in
			object.sourceName = sourceName
			object.targetName = targetName
			object.cloned = cloned
			object.reason = reason
		}
	}
}

public struct ConfiguredReply: Codable {
	public let name: String
	public let configured: Bool
	public let reason: String

	public init(from: Caked_ConfiguredReply) {
		self.name = from.name
		self.configured = from.configured
		self.reason = from.reason
	}

	public init(name: String, configured: Bool, reason: String) {
		self.name = name
		self.configured = configured
		self.reason = reason
	}

	public var caked: Caked_ConfiguredReply {
		Caked_ConfiguredReply.with { object in
			object.name = name
			object.configured = configured
			object.reason = reason
		}
	}
}

public struct DuplicatedReply: Codable {
	public let from: String
	public let to: String
	public let duplicated: Bool
	public let reason: String

	public init(from: Caked_DuplicatedReply) {
		self.from = from.from
		self.to = from.to
		self.duplicated = from.duplicated
		self.reason = from.reason
	}

	public init(from: String, to: String, duplicated: Bool, reason: String) {
		self.from = from
		self.to = to
		self.duplicated = duplicated
		self.reason = reason
	}

	public var caked: Caked_DuplicatedReply {
		Caked_DuplicatedReply.with { object in
			object.from = from
			object.to = to
			object.duplicated = duplicated
			object.reason = reason
		}
	}
}

public struct ImportedReply: Codable {
	public let source: String
	public let name: String
	public let imported: Bool
	public let reason: String

	public init(from: Caked_ImportedReply) {
		self.source = from.source
		self.name = from.name
		self.imported = from.imported
		self.reason = from.reason
	}

	public init(source: String, name: String, imported: Bool, reason: String) {
		self.source = source
		self.name = name
		self.imported = imported
		self.reason = reason
	}

	public var caked: Caked_ImportedReply {
		Caked_ImportedReply.with { object in
			object.name = name
			object.source = source
			object.imported = imported
			object.reason = reason
		}
	}
}

public struct WaitIPReply: Codable {
	public let name: String
	public let ip: String
	public let success: Bool
	public let reason: String

	public init(from: Caked_WaitIPReply) {
		self.name = from.name
		self.ip = from.ip
		self.success = from.success
		self.reason = from.reason
	}

	public init(name: String, ip: String, success: Bool, reason: String) {
		self.name = name
		self.ip = ip
		self.success = success
		self.reason = reason
	}

	public var caked: Caked_WaitIPReply {
		Caked_WaitIPReply.with { object in
			object.name = name
			object.ip = ip
			object.success = success
			object.reason = reason
		}
	}
}

public struct PurgeReply: Codable {
	public let purged: Bool
	public let reason: String

	public init(from: Caked_PurgeReply) {
		self.purged = from.purged
		self.reason = from.reason
	}

	public init(purged: Bool, reason: String) {
		self.purged = purged
		self.reason = reason
	}

	public var caked: Caked_PurgeReply {
		Caked_PurgeReply.with { object in
			object.purged = purged
			object.reason = reason
		}
	}
}

public struct RenameReply: Codable {
	public let newName: String
	public let oldName: String
	public let renamed: Bool
	public let reason: String

	public init(from: Caked_RenameReply) {
		self.oldName = from.oldName
		self.newName = from.newName
		self.renamed = from.renamed
		self.reason = from.reason
	}

	public init(oldName: String, newName: String, renamed: Bool, reason: String) {
		self.oldName = oldName
		self.newName = newName
		self.renamed = renamed
		self.reason = reason
	}

	public var caked: Caked_RenameReply {
		Caked_RenameReply.with { object in
			object.oldName = oldName
			object.newName = newName
			object.renamed = renamed
			object.reason = reason
		}
	}
}

public struct VirtualMachineInfo: Codable, Identifiable, Hashable {
	public typealias ID = String

	public let type: String
	public let source: String
	public let name: String
	public let fqn: [String]
	public let instanceID: String?
	public let diskSize: Int
	public let sizeOnDisk: Int
	public let state: String
	public let ip: String?
	public let fingerprint: String?

	public var id: String {
		self.instanceID ?? self.name
	}

	public init(from: Caked_VirtualMachineInfo) {
		self.type = from.type
		self.source = from.source
		self.name = from.name
		self.fqn = from.fqn
		self.instanceID = from.instanceID
		self.diskSize = Int(from.diskSize)
		self.sizeOnDisk = Int(from.sizeOnDisk)
		self.state = from.state
		self.ip = from.ip
		self.fingerprint = from.fingerprint
	}

	public init(
		type: String = "",
		source: String = "",
		name: String = "",
		fqn: [String] = [],
		instanceID: String? = nil,
		diskSize: Int = 0,
		sizeOnDisk: Int = 0,
		state: String = "unknown",
		ip: String? = nil,
		fingerprint: String? = nil
	) {
		self.type = type
		self.source = source
		self.name = name
		self.fqn = fqn
		self.instanceID = instanceID
		self.diskSize = diskSize
		self.sizeOnDisk = sizeOnDisk
		self.state = state
		self.ip = ip
		self.fingerprint = fingerprint
	}

	public var caked: Caked_VirtualMachineInfo {
		Caked_VirtualMachineInfo.with { info in
			info.type = self.type
			info.source = self.source
			info.name = self.name
			info.fqn = self.fqn
			info.diskSize = UInt64(self.diskSize)
			info.sizeOnDisk = UInt64(self.sizeOnDisk)
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

public struct ShortVirtualMachineInfo: Codable {
	public let type: String
	public let name: String
	public let fqn: String
	public let instanceID: String
	public let ip: String
	public let diskSize: String
	public let sizeOnDisk: String
	public let state: String
	public let fingerprint: String

	public init(from: VirtualMachineInfo) {
		self.type = from.type
		self.name = from.name
		self.fqn = from.fqn.joined(separator: " ")
		self.ip = from.ip ?? ""
		self.instanceID = from.instanceID ?? ""
		self.diskSize = ByteCountFormatter.string(fromByteCount: Int64(from.diskSize), countStyle: .file)
		self.sizeOnDisk = ByteCountFormatter.string(fromByteCount: Int64(from.sizeOnDisk), countStyle: .file)
		self.state = from.state
		self.fingerprint = from.fingerprint != nil ? from.fingerprint!.substring(..<12) : ""
	}
}

public struct VirtualMachineStatusReply: Codable {
	public let status: VMInformations
	public let success: Bool
	public let reason: String

	public init(status: VMInformations, success: Bool, reason: String) {
		self.status = status
		self.success = success
		self.reason = reason
	}

	public init(from: Caked_VirtualMachineStatusReply) throws {
		self.success = from.success
		self.reason = from.reason
		self.status = VMInformations(from: from.status)
	}

	public var caked: Caked_VirtualMachineStatusReply {
		Caked_VirtualMachineStatusReply.with {
			$0.status = self.status.caked
			$0.success = self.success
			$0.reason = self.reason
		}
	}
}

public struct VirtualMachineInfoReply: Codable {
	public let infos: [VirtualMachineInfo]
	public let success: Bool
	public let reason: String

	public init(infos: [VirtualMachineInfo], success: Bool, reason: String) {
		self.infos = infos
		self.success = success
		self.reason = reason
	}

	public init(from: Caked_VirtualMachineInfoReply) throws {
		self.success = from.success
		self.reason = from.reason
		self.infos = from.infos.map(VirtualMachineInfo.init(from:))
	}

	public var caked: Caked_VirtualMachineInfoReply {
		Caked_VirtualMachineInfoReply.with {
			$0.infos = self.infos.map(\.caked)
			$0.success = self.success
			$0.reason = self.reason
		}
	}
}

public struct ScreenSizeReply: Codable {
	public let width: Int
	public let height: Int
	public let success: Bool
	public let reason: String
	
	public init(width: Int, height: Int, success: Bool, reason: String) {
		self.width = width
		self.height = height
		self.success = success
		self.reason = reason
	}

	public init(from: Caked_ScreenSizeReply) {
		self.width = Int(from.screenSize.width)
		self.height = Int(from.screenSize.height)
		self.success = from.success
		self.reason = from.reason
	}

	public var caked: Caked_ScreenSizeReply {
		Caked_ScreenSizeReply.with {
			$0.screenSize = .with {
				$0.width = Int32(self.width)
				$0.height = Int32(self.height)
			}
			$0.success = self.success
			$0.reason = self.reason
		}
	}
}

public struct InstalledAgentReply {
	public let name: String
	public let installed: Bool
	public let reason: String
	
	public init(name: String, installed: Bool, reason: String) {
		self.name = name
		self.installed = installed
		self.reason = reason
	}
	
	public var caked: Caked_InstalledAgentReply {
		Caked_InstalledAgentReply.with {
			$0.name = self.name
			$0.installed = self.installed
			$0.reason = self.reason
		}
	}
}
