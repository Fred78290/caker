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

	var os: VirtualizedOS = .linux
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
	
	var configuredUser: String
	var configuredPassword: String?
	var mainGroup: String
	var clearPassword: Bool
	var diskSize: UInt16 = 20
	var netIfnames: Bool = false
	var userData: String? = nil
	var networkConfig: String? = nil
	var autoinstall: Bool = false

	init() {
		os = .linux
		cpuCount = 1
		memorySize = 512
		macAddress = ""
		autostart = false
		suspendable = false
		netIfnames = false
		dynamicPortForwarding = false
		displayRefit = true
		nestedVirtualization = true
		display = ViewSize(width: 1920, height: 1080)
		forwardPorts = []
		sockets = []
		networks = []
		attachedDisks = []
		mounts = []
		configuredUser = "admin"
		configuredPassword = nil
		mainGroup = "adm"
		clearPassword = true
		diskSize = 20
		autoinstall = false
	}
	
	init(vmname: String, config: CakeConfig) {
		self.os = config.os
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
		self.configuredUser = config.configuredUser
		self.configuredPassword = config.configuredPassword
		self.mainGroup = "adm"
		self.clearPassword = true
		self.diskSize = 20
	}
	
	func save() throws {
		guard let vmname = self.vmname else {
			throw ServiceError("Virtual machine name is required to save configuration")
		}
		
		try self.save(name: vmname)
	}
	
	func save(name: String) throws {
		let location = try StorageLocation(runMode: .app).find(name)
		let config = try location.config()
		
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

	func buildOptions(image: String, sshAuthorizedKey: String?) -> BuildOptions {
		.init(
			name: self.vmname!,
			cpu: UInt16(self.cpuCount),
			memory: self.memorySize,
			diskSize: self.diskSize,
			attachedDisks: self.attachedDisks,
			user: self.configuredUser,
			password: self.configuredPassword,
			mainGroup: self.mainGroup,
			clearPassword: self.clearPassword,
			autostart: self.autostart,
			nested: self.nestedVirtualization,
			suspendable: self.suspendable,
			netIfnames: self.netIfnames,
			image: image,
			sshAuthorizedKey: sshAuthorizedKey,
			userData: self.userData,
			networkConfig: self.networkConfig,
			displayRefit: self.displayRefit,
			forwardedPorts: self.forwardPorts,
			mounts: self.mounts,
			networks: self.networks,
			sockets: self.sockets,
			autoinstall: self.autoinstall
		)
	}
}
