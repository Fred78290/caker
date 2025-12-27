import CakeAgentLib
//
//  VirtualMachineInformations.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/12/2025.
//
import CakedLib
import GRPCLib
import SwiftUI

class VirtualMachineInformations: ObservableObject {
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
	@Published var cpuInfos: CpuInformations? = nil
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
		self.cpuInfos = infos.cpuInfo
		self.agentVersion = infos.agentVersion
	}

	func update(from infos: InfoReply) {
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
		self.cpuInfos = infos.cpuInfo
		self.agentVersion = infos.agentVersion
	}
}
