//
//  VirtualMachineInformations.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/12/2025.
//
import CakeAgentLib
import CakedLib
import GRPCLib
import SwiftUI

@Observable final class CoreInfo {
	var coreID: Int32 = 0
	var usagePercent: Double = 0
	var user: Double = 0
	var system: Double = 0
	var idle: Double = 0
	var iowait: Double = 0
	var irq: Double = 0
	var softirq: Double = 0
	var steal: Double = 0
	var guest: Double = 0
	var guestNice: Double = 0

	init(
		coreID: Int32,
		usagePercent: Double,
		user: Double,
		system: Double,
		idle: Double,
		iowait: Double,
		irq: Double,
		softirq: Double,
		steal: Double,
		guest: Double,
		guestNice: Double
	) {
		self.coreID = coreID
		self.usagePercent = usagePercent
		self.user = user
		self.system = system
		self.idle = idle
		self.iowait = iowait
		self.irq = irq
		self.softirq = softirq
		self.steal = steal
		self.guest = guest
		self.guestNice = guestNice
	}
}

@Observable final class MemoryInfo {
	public var total: UInt64 = 0
	public var free: UInt64 = 0
	public var used: UInt64 = 0
	
	init() {
	}
	
	init(from infos: InfoReply.MemoryInfo) {
		self.total = infos.total ?? 0
		self.free = infos.free ?? 0
		self.used = infos.used ?? 0
	}
	
	init(from infos: CakeAgent.InfoReply.MemoryInfo) {
		self.total = infos.total
		self.free = infos.free
		self.used = infos.used
	}
	
	func update(_ infos: CakeAgent.InfoReply.MemoryInfo?) {
		self.total = infos?.total ?? self.total
		self.free = infos?.free ?? self.free
		self.used = infos?.used ?? self.used
	}
	
	func update(_ infos: Caked_Caked.MemoryInfo) {
		self.total = infos.total
		self.free = infos.free
		self.used = infos.used
	}
	
	func update(_ infos: InfoReply.MemoryInfo?) {
		self.total = infos?.total ?? self.total
		self.free = infos?.free ?? self.free
		self.used = infos?.used ?? self.used
	}
}

@Observable final class CpuInfos {
	var totalUsagePercent: Double = 0
	var user: Double = 0
	var system: Double = 0
	var idle: Double = 0
	var iowait: Double = 0
	var irq: Double = 0
	var softirq: Double = 0
	var steal: Double = 0
	var guest: Double = 0
	var guestNice: Double = 0
	var cores: [CoreInfo] = []
	
	init() {
		
	}

	init(_ infos: CpuInformations?) {
		if let infos {
			self.totalUsagePercent = infos.totalUsagePercent
			self.user = infos.user
			self.system = infos.system
			self.idle = infos.idle
			self.iowait = infos.iowait
			self.irq = infos.irq
			self.softirq = infos.softirq
			self.cores = infos.cores.map {
				CoreInfo(coreID: $0.coreID,
						 usagePercent: $0.usagePercent,
						 user: $0.user,
						 system: $0.system,
						 idle: $0.idle,
						 iowait: $0.iowait,
						 irq: $0.irq,
						 softirq: $0.softirq,
						 steal: $0.steal,
						 guest: $0.guest,
						 guestNice: $0.guestNice)
			}
		}
	}

	init(_ infos: CakeAgent.InfoReply.CpuInfo) {
		self.totalUsagePercent = infos.totalUsagePercent
		self.user = infos.user
		self.system = infos.system
		self.idle = infos.idle
		self.iowait = infos.iowait
		self.irq = infos.irq
		self.softirq = infos.softirq
		self.cores = infos.cores.map {
			CoreInfo(coreID: $0.coreID,
					 usagePercent: $0.usagePercent,
					 user: $0.user,
					 system: $0.system,
					 idle: $0.idle,
					 iowait: $0.iowait,
					 irq: $0.irq,
					 softirq: $0.softirq,
					 steal: $0.steal,
					 guest: $0.guest,
					 guestNice: $0.guestNice)
		}
	}

	func update(_ infos: CakeAgent.InfoReply.CpuInfo) {
		self.totalUsagePercent = infos.totalUsagePercent
		self.user = infos.user
		self.system = infos.system
		self.idle = infos.idle
		self.iowait = infos.iowait
		self.irq = infos.irq
		self.softirq = infos.softirq
		self.cores = infos.cores.map {
			CoreInfo(coreID: $0.coreID,
					 usagePercent: $0.usagePercent,
					 user: $0.user,
					 system: $0.system,
					 idle: $0.idle,
					 iowait: $0.iowait,
					 irq: $0.irq,
					 softirq: $0.softirq,
					 steal: $0.steal,
					 guest: $0.guest,
					 guestNice: $0.guestNice)
		}
	}
	
	func update(_ infos: Caked_InfoReplyCpuInfo) {
		self.totalUsagePercent = infos.totalUsagePercent
		self.user = infos.user
		self.system = infos.system
		self.idle = infos.idle
		self.iowait = infos.iowait
		self.irq = infos.irq
		self.softirq = infos.softirq
		self.cores = infos.cores.map {
			CoreInfo(coreID: $0.coreID,
					 usagePercent: $0.usagePercent,
					 user: $0.user,
					 system: $0.system,
					 idle: $0.idle,
					 iowait: $0.iowait,
					 irq: $0.irq,
					 softirq: $0.softirq,
					 steal: $0.steal,
					 guest: $0.guest,
					 guestNice: $0.guestNice)
		}
	}

	func update(_ infos: CpuInformations?) {
		if let infos {
			self.totalUsagePercent = infos.totalUsagePercent
			self.user = infos.user
			self.system = infos.system
			self.idle = infos.idle
			self.iowait = infos.iowait
			self.irq = infos.irq
			self.softirq = infos.softirq
			self.cores = infos.cores.map {
				CoreInfo(coreID: $0.coreID,
						 usagePercent: $0.usagePercent,
						 user: $0.user,
						 system: $0.system,
						 idle: $0.idle,
						 iowait: $0.iowait,
						 irq: $0.irq,
						 softirq: $0.softirq,
						 steal: $0.steal,
						 guest: $0.guest,
						 guestNice: $0.guestNice)
			}
		}
	}
}

@Observable final class VirtualMachineInformations {
	var timestamp: Date = .now
	var name: String? = nil
	var version: String? = nil
	var uptime: UInt64? = nil
	var memory: InfoReply.MemoryInfo? = nil
	var cpuCount: Int32? = nil
	var diskInfos: [DiskInfo]? = nil
	var ipaddresses: [String]? = nil
	var osname: String? = nil
	var hostname: String? = nil
	var release: String? = nil
	var mounts: [String]? = nil
	var status: Status = .unknown
	var attachedNetworks: [AttachedNetwork]? = nil
	var tunnelInfos: [TunnelInfo]? = nil
	var socketInfos: [SocketInfo]? = nil
	var vncURL: String? = nil
	var cpuInfos = CpuInfos()
	var agentVersion: String? = nil

	init() {
	}

	init(_ infos: VMInformations) {
		self.name = infos.name
		self.version = infos.version
		self.uptime = infos.uptime
		self.memory = infos.memory
		self.cpuCount = infos.cpuCount
		self.diskInfos = infos.diskInfos
		self.ipaddresses = infos.ipaddresses
		self.osname = infos.osname
		self.hostname = infos.hostname
		self.release = infos.release
		self.mounts = infos.mounts
		self.status = infos.status
		self.attachedNetworks = infos.attachedNetworks
		self.tunnelInfos = infos.tunnelInfos
		self.socketInfos = infos.socketInfos
		self.agentVersion = infos.agentVersion
		self.cpuInfos = CpuInfos(infos.cpuInfos)
	}

	init(_ infos: InfoReply) {
		self.name = infos.name
		self.version = infos.version
		self.uptime = infos.uptime
		self.memory = infos.memory
		self.cpuCount = infos.cpuCount
		self.diskInfos = infos.diskInfos
		self.ipaddresses = infos.ipaddresses
		self.osname = infos.osname
		self.hostname = infos.hostname
		self.release = infos.release
		self.mounts = infos.mounts
		self.status = infos.status
		self.attachedNetworks = infos.attachedNetworks
		self.tunnelInfos = infos.tunnelInfos
		self.socketInfos = infos.socketInfos
		self.agentVersion = infos.agentVersion
		self.cpuInfos = CpuInfos(infos.cpuInfo)
	}

	func update(from infos: CakeAgent.CurrentUsageReply) {
		self.timestamp = .now
		self.cpuInfos = CpuInfos(infos.cpuInfos)
		self.memory = .with {
			$0.total = infos.memory.total
			$0.free = infos.memory.free
			$0.used = infos.memory.used
		}
	}
	
	func update(from infos: InfoReply) {
		self.timestamp = .now
		self.name = infos.name
		self.version = infos.version
		self.uptime = infos.uptime
		self.memory = infos.memory
		self.cpuCount = infos.cpuCount
		self.diskInfos = infos.diskInfos
		self.ipaddresses = infos.ipaddresses
		self.osname = infos.osname
		self.hostname = infos.hostname
		self.release = infos.release
		self.mounts = infos.mounts
		self.status = infos.status
		self.attachedNetworks = infos.attachedNetworks
		self.tunnelInfos = infos.tunnelInfos
		self.socketInfos = infos.socketInfos
		self.agentVersion = infos.agentVersion
		self.cpuInfos.update(infos.cpuInfo)
	}
}
