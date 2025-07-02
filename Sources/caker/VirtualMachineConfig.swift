//
//  VirtualMachineConfig.swift
//  Caker
//
//  Created by Frederic BOLTZ on 27/06/2025.
//

import Foundation
import SwiftUI
import GRPCLib
import CakedLib
import Virtualization

struct VirtualMachineConfig: Hashable {
	struct ViewSize: Identifiable, Hashable {
		var id: Int {
			width * height
		}
		var width: Int
		var height: Int
		
		init(width: Int, height: Int) {
			self.width = width
			self.height = height
		}
	}
	
	var cpuCount: Int = 1
	var memorySize: UInt64 = 512
	var macAddress: String = ""
	var autostart: Bool = false
	var suspendable: Bool = false
	var dynamicPortForwarding: Bool = false
	var displayRefit: Bool = true
	var nestedVirtualization: Bool = true
	var display: ViewSize = ViewSize(width: 1920, height: 1080)
	var forwardPorts: [TunnelAttachement] = []
	var sockets: [SocketDevice] = []
	var networks: [BridgeAttachement] = []
	var attachedDisks: [DiskAttachement] = []
	var mounts: [DirectorySharingAttachment] = []
	var vmname: String? = nil

	init() {
		cpuCount = 1
		memorySize = 512
		macAddress = ""
		autostart = false
		suspendable = false
		dynamicPortForwarding = false
		displayRefit = true
		nestedVirtualization = true
		display = ViewSize(width: 1920, height: 1080)
		forwardPorts = []
		sockets = []
		networks = []
		attachedDisks = []
		mounts = []
	}

	init(vmname: String, config: CakeConfig) {
		self.cpuCount = config.cpuCount
		self.memorySize = config.memorySize / (1024 * 1024)
		self.macAddress = config.macAddress?.string ?? ""
		self.autostart = config.autostart
		self.suspendable = config.suspendable
		self.dynamicPortForwarding = config.dynamicPortForwarding
		self.displayRefit = config.displayRefit
		self.nestedVirtualization = config.nested
		self.display = ViewSize(width: config.display.width, height: config.display.height)
		self.forwardPorts = config.forwardedPorts
		self.sockets = config.sockets
		self.networks = config.networks
		self.attachedDisks = config.attachedDisks
		self.mounts = config.mounts
		self.vmname = vmname
	}

	func save() throws {
		guard let vmname = self.vmname else {
			throw ServiceError("Virtual machine name is required to save configuration")
		}
		
		try self.save(name: vmname)
	}

	func save(name: String) throws {
		let vmLocation = try StorageLocation(runMode: .app).find(name)
		let config = try vmLocation.config()

		try self.save(config: config)
	}

	func save(config: CakeConfig) throws {
		config.cpuCount = self.cpuCount
		config.memorySize = self.memorySize * (1024 * 1024)
		config.macAddress = self.macAddress.isEmpty ? nil : VZMACAddress(string: self.macAddress)
		config.autostart = self.autostart
		config.suspendable = self.suspendable
		config.dynamicPortForwarding = self.dynamicPortForwarding
		config.displayRefit = self.displayRefit
		config.nested = self.nestedVirtualization
		config.display = DisplaySize(width: self.display.width, height: self.display.height)
		config.forwardedPorts = self.forwardPorts
		config.sockets = self.sockets
		config.networks = self.networks
		config.attachedDisks = self.attachedDisks
		config.mounts = self.mounts
		
		try config.save()
	}
}
