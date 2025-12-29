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

class CoreInfo: ObservableObject {
	@Published var coreID: Int32 = 0
	@Published var usagePercent: Double = 0
	@Published var user: Double = 0
	@Published var system: Double = 0
	@Published var idle: Double = 0
	@Published var iowait: Double = 0
	@Published var irq: Double = 0
	@Published var softirq: Double = 0
	@Published var steal: Double = 0
	@Published var guest: Double = 0
	@Published var guestNice: Double = 0

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

class CpuInfos: ObservableObject {
	@Published var totalUsagePercent: Double = 0
	@Published var user: Double = 0
	@Published var system: Double = 0
	@Published var idle: Double = 0
	@Published var iowait: Double = 0
	@Published var irq: Double = 0
	@Published var softirq: Double = 0
	@Published var steal: Double = 0
	@Published var guest: Double = 0
	@Published var guestNice: Double = 0
	@Published var cores: [CoreInfo] = []
	
	init() {
		
	}

	init(from infos: CpuInformations?) {
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
	
	func update(from infos: CpuInformations?) {
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

class VirtualMachineInformations: ObservableObject {
	@Published var timestamp: Date = .now
	@Published var name: String? = nil
	@Published var version: String? = nil
	@Published var uptime: UInt64? = nil
	@Published var memory: InfoReply.MemoryInfo? = nil
	@Published var cpuCount: Int32? = nil
	@Published var diskInfos: [DiskInfo]? = nil
	@Published var ipaddresses: [String]? = nil
	@Published var osname: String? = nil
	@Published var hostname: String? = nil
	@Published var release: String? = nil
	@Published var mounts: [String]? = nil
	@Published var status: Status = .unknown
	@Published var attachedNetworks: [AttachedNetwork]? = nil
	@Published var tunnelInfos: [TunnelInfo]? = nil
	@Published var socketInfos: [SocketInfo]? = nil
	@Published var vncURL: String? = nil
	@Published var cpuInfos = CpuInfos()
	@Published var agentVersion: String? = nil

	init() {
	}

	init(from infos: InfoReply) {
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
		self.cpuInfos = CpuInfos(from: infos.cpuInfo)
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
		self.cpuInfos.update(from: infos.cpuInfo)
	}
}
