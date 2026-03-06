//
//  VirtualMachineConfig.swift
//  Caker
//
//  Created by Frederic BOLTZ on 27/06/2025.
//

import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib
import SwiftUI
import Virtualization

struct VirtualMachineConfig: VirtualMachineConfiguration, Hashable {
	private var changedFields: Set<PartialKeyPath<Self>>? = nil

	var locationURL: URL
	
	var version: Int = 0
	
	var arch: GRPCLib.Architecture = Architecture.current()
	
	var instanceID: String
	
	var dhcpClientID: String? = nil {
		didSet {
			changedFields?.insert(\.dhcpClientID)
		}
	}

	var dhcpClientIDIfChanged: String? {
		self.changedFields?.contains(\.dhcpClientID) == true ? self.dhcpClientID : nil
	}

	var nested: Bool = true {
		didSet {
			changedFields?.insert(\.nested)
		}
	}
	
	var nestedIfChanged: Bool? {
		self.changedFields?.contains(\.nested) == true ? self.nested : nil
	}

	var useCloudInit: Bool = true {
		didSet {
			changedFields?.insert(\.useCloudInit)
		}
	}
	
	var configuredPlatform: GRPCLib.SupportedPlatform = .unknown {
		didSet {
			changedFields?.insert(\.configuredPlatform)
		}
	}

	var configuredPlatformIfChanged: GRPCLib.SupportedPlatform? {
		self.changedFields?.contains(\.configuredPlatform) == true ? self.configuredPlatform : nil
	}

	var os: VirtualizedOS = .linux {
		didSet {
			changedFields?.insert(\.os)
		}
	}

	var cpuCount: UInt16 = 1 {
		didSet {
			changedFields?.insert(\.cpuCount)
		}
	}

	var cpuCountIfChanged: UInt16? {
		self.changedFields?.contains(\.cpuCount) == true ? UInt16(self.cpuCount) : nil
	}

	var cpuCountMin: UInt16 = 1 {
		didSet {
			changedFields?.insert(\.cpuCountMin)
		}
	}

	var cpuCounMintIfChanged: UInt16? {
		self.changedFields?.contains(\.cpuCountMin) == true ? UInt16(self.cpuCountMin) : nil
	}

	var memorySize: UInt64 = 512 {
		didSet {
			changedFields?.insert(\.memorySize)
		}
	}

	var memorySizeIfChanged: UInt64? {
		self.changedFields?.contains(\.memorySize) == true ? self.memorySize : nil
	}

	var memorySizeMin: UInt64 = 512 {
		didSet {
			changedFields?.insert(\.memorySizeMin)
		}
	}

	var memorySizeMinIfChanged: UInt64? {
		self.changedFields?.contains(\.memorySizeMin) == true ? self.memorySizeMin : nil
	}

	var macAddress: String? = nil {
		didSet {
			changedFields?.insert(\.macAddress)
		}
	}

	var macAddressIfChanged: String? {
		self.changedFields?.contains(\.macAddress) == true ? self.macAddress : nil
	}

	var autostart: Bool = false {
		didSet {
			changedFields?.insert(\.autostart)
		}
	}

	var autostartIfChanged: Bool? {
		self.changedFields?.contains(\.autostart) == true ? self.autostart : nil
	}

	var suspendable: Bool = false {
		didSet {
			changedFields?.insert(\.suspendable)
		}
	}

	var suspendableIfChanged: Bool? {
		self.changedFields?.contains(\.suspendable) == true ? self.suspendable : nil
	}

	var dynamicPortForwarding: Bool = false {
		didSet {
			changedFields?.insert(\.dynamicPortForwarding)
		}
	}

	var dynamicPortForwardingIfChanged: Bool? {
		self.changedFields?.contains(\.dynamicPortForwarding) == true ? self.dynamicPortForwarding : nil
	}

	var displayRefit: Bool = true {
		didSet {
			changedFields?.insert(\.displayRefit)
		}
	}

	var displayRefitIfChanged: Bool? {
		self.changedFields?.contains(\.displayRefit) == true ? self.displayRefit : nil
	}

	var nestedVirtualization: Bool = true {
		didSet {
			changedFields?.insert(\.nestedVirtualization)
		}
	}

	var nestedVirtualizationIfChanged: Bool? {
		self.changedFields?.contains(\.nestedVirtualization) == true ? self.nestedVirtualization : nil
	}

	var display: GRPCLib.ViewSize = .standard {
		didSet {
			changedFields?.insert(\.display)
		}
	}

	var displayIfChanged: GRPCLib.ViewSize? {
		self.changedFields?.contains(\.display) == true ? self.display : nil
	}

	var forwardedPorts: [TunnelAttachement] = [] {
		didSet {
			changedFields?.insert(\.forwardedPorts)
		}
	}

	var forwardedPortsIfChanged: [TunnelAttachement]? {
		self.changedFields?.contains(\.forwardedPorts) == true ? self.forwardedPorts : nil
	}

	var sockets: [SocketDevice] = [] {
		didSet {
			changedFields?.insert(\.sockets)
		}
	}

	var socketsIfChanged: [SocketDevice]? {
		self.changedFields?.contains(\.sockets) == true ? self.sockets : nil
	}

	var networks: [BridgeAttachement] = [] {
		didSet {
			changedFields?.insert(\.networks)
		}
	}

	var networksIfChanged: [BridgeAttachement]? {
		self.changedFields?.contains(\.networks) == true ? self.networks : nil
	}

	var attachedDisks: [DiskAttachement] = [] {
		didSet {
			changedFields?.insert(\.attachedDisks)
		}
	}

	var attachedDisksIfChanged: [DiskAttachement]? {
		self.changedFields?.contains(\.attachedDisks) == true ? self.attachedDisks : nil
	}

	var mounts: DirectorySharingAttachments = [] {
		didSet {
			changedFields?.insert(\.mounts)
		}
	}

	var mountsIfChanged: DirectorySharingAttachments? {
		self.changedFields?.contains(\.mounts) == true ? self.mounts : nil
	}

	var vmname: String! = nil {
		didSet {
			changedFields?.insert(\.vmname)
		}
	}

	var vmnameIfChanged: String? {
		self.changedFields?.contains(\.vmname) == true ? self.vmname : nil
	}

	var agent: Bool = false {
		didSet {
			changedFields?.insert(\.agent)
		}
	}

	var agentIfChanged: Bool? {
		self.changedFields?.contains(\.agent) == true ? self.agent : nil
	}

	var source: ImageSource = .raw {
		didSet {
			changedFields?.insert(\.source)
		}
	}

	var sourceIfChanged: ImageSource? {
		self.changedFields?.contains(\.source) == true ? self.source : nil
	}

	var firstLaunch: Bool = false {
		didSet {
			changedFields?.insert(\.firstLaunch)
		}
	}

	var firstLaunchIfChanged: Bool? {
		self.changedFields?.contains(\.firstLaunch) == true ? self.firstLaunch : nil
	}

	var osName: String? = nil {
		didSet {
			changedFields?.insert(\.osName)
		}
	}

	var osNameIfChanged: String? {
		self.changedFields?.contains(\.osName) == true ? self.osName : nil
	}

	var osRelease: String? = nil {
		didSet {
			changedFields?.insert(\.osRelease)
		}
	}

	var osReleaseIfChanged: String? {
		self.changedFields?.contains(\.osRelease) == true ? self.osRelease : nil
	}

	var imageName: String {
		didSet {
			changedFields?.insert(\.imageName)
		}
	}

	var imageNameIfChanged: String? {
		self.changedFields?.contains(\.imageName) == true ? self.imageName : nil
	}

	var sshPrivateKeyPath: String?

	var sshAuthorizedKey: String? = nil {
		didSet {
			changedFields?.insert(\.sshAuthorizedKey)
		}
	}

	var sshAuthorizedKeyIfChanged: String? {
		self.changedFields?.contains(\.sshAuthorizedKey) == true ? self.sshAuthorizedKey : nil
	}

	var sshPrivateKeyPassphrase: String? = nil {
		didSet {
			changedFields?.insert(\.sshPrivateKeyPassphrase)
		}
	}

	var sshPrivateKeyPassphraseIfChanged: String? {
		self.changedFields?.contains(\.sshPrivateKeyPassphrase) == true ? self.sshPrivateKeyPassphrase : nil
	}

	var configuredUser: String {
		didSet {
			changedFields?.insert(\.configuredUser)
		}
	}

	var configuredUserIfChanged: String? {
		self.changedFields?.contains(\.configuredUser) == true ? self.configuredUser : nil
	}

	var configuredPassword: String? = nil {
		didSet {
			changedFields?.insert(\.configuredPassword)
		}
	}

	var configuredPasswordIfChanged: String? {
		self.changedFields?.contains(\.configuredPassword) == true ? self.configuredPassword : nil
	}

	var configuredGroup: String {
		didSet {
			changedFields?.insert(\.configuredGroup)
		}
	}

	var configuredGroupIfChanged: String? {
		self.changedFields?.contains(\.configuredGroup) == true ? self.configuredGroup : nil
	}

	var configuredGroups: [String]? = nil {
		didSet {
			changedFields?.insert(\.configuredGroups)
		}
	}

	var configuredGroupsIfChanged: [String]? {
		self.changedFields?.contains(\.configuredGroups) == true ? self.configuredGroups : nil
	}

	var clearPassword: Bool = true {
		didSet {
			changedFields?.insert(\.clearPassword)
		}
	}

	var clearPasswordIfChanged: Bool? {
		self.changedFields?.contains(\.clearPassword) == true ? self.clearPassword : nil
	}

	var diskSize: UInt64 = 20 {
		didSet {
			changedFields?.insert(\.diskSize)
		}
	}

	var diskSizeIfChanged: UInt64? {
		self.changedFields?.contains(\.diskSize) == true ? self.diskSize : nil
	}

	var ifname: Bool = false {
		didSet {
			changedFields?.insert(\.ifname)
		}
	}

	var ifnameIfChanged: Bool? {
		self.changedFields?.contains(\.ifname) == true ? self.ifname : nil
	}

	var userData: String? = nil {
		didSet {
			changedFields?.insert(\.userData)
		}
	}

	var userDataIfChanged: String? {
		self.changedFields?.contains(\.userData) == true ? self.userData : nil
	}

	var console: String? = nil {
		didSet {
			changedFields?.insert(\.useCloudInit)
		}
	}

	var consoleIfChanged: String? {
		self.changedFields?.contains(\.console) == true ? self.console : nil
	}

	var networkConfig: String? = nil {
		didSet {
			changedFields?.insert(\.networkConfig)
		}
	}

	var networkConfigIfChanged: String? {
		self.changedFields?.contains(\.networkConfig) == true ? self.networkConfig : nil
	}

	var autoinstall: Bool = false {
		didSet {
			changedFields?.insert(\.autoinstall)
		}
	}

	var autoinstallIfChanged: Bool? {
		self.changedFields?.contains(\.autoinstall) == true ? self.autoinstall : nil
	}

	var vncPassword: String? = nil {
		didSet {
			changedFields?.insert(\.vncPassword)
		}
	}

	var vncPasswordIfChanged: String? {
		self.changedFields?.contains(\.vncPassword) == true ? self.vncPassword : nil
	}

	var ecid: Data? = nil
	var hardwareModel: Data? = nil
	var runningIP: String? = nil

	var humanReadableDiskSize: String {
		ByteCountFormatter.string(fromByteCount: Int64(self.diskSize * GoB), countStyle: .file)
	}

	var humanReadableMemorySize: String {
		ByteCountFormatter.string(fromByteCount: Int64(self.memorySize * MoB), countStyle: .memory)
	}

	init() {
		self.locationURL = URL(fileURLWithPath: "/dev/null")
		self.imageName = OSCloudImage.ubuntu2404LTS.url.absoluteString
		self.arch = Architecture.current()
		self.os = .linux
		self.cpuCount = 1
		self.memorySize = 512
		self.macAddress = ""
		self.autostart = false
		self.suspendable = false
		self.ifname = false
		self.dynamicPortForwarding = false
		self.displayRefit = true
		self.nestedVirtualization = true
		self.display = .standard
		self.forwardedPorts = []
		self.sockets = []
		self.networks = []
		self.attachedDisks = []
		self.mounts = []
		self.configuredUser = "admin"
		self.configuredPassword = nil
		self.configuredGroup = "adm"
		self.configuredGroups = ["sudo"]
		self.clearPassword = true
		self.diskSize = 20
		self.autoinstall = false
		self.firstLaunch = true
		self.instanceID = "i-\(String(format: "%x", Int(Date().timeIntervalSince1970)))"

		if FileManager.default.fileExists(atPath: "~/.ssh/id_rsa.pub".expandingTildeInPath) {
			self.sshPrivateKeyPath = "~/.ssh/id_rsa"
			self.sshAuthorizedKey = "~/.ssh/id_rsa.pub"
		}

		self.changedFields = Set<PartialKeyPath<Self>>()
	}

	init(name: String, config: any VirtualMachineConfiguration) {
		self.imageName = OSCloudImage.ubuntu2404LTS.url.absoluteString
		self.locationURL = config.locationURL
		self.version = config.version
		self.os = config.os
		self.arch = config.arch
		self.cpuCountMin = config.cpuCountMin
		self.suspendable = config.suspendable
		self.diskSize = config.diskSize
		self.cpuCount = config.cpuCount
		self.memorySizeMin = config.memorySizeMin
		self.memorySize = config.memorySize
		self.macAddress = config.macAddress
		self.source = config.source
		self.osName = config.osName
		self.osRelease = config.osRelease
		self.dynamicPortForwarding = config.dynamicPortForwarding
		self.displayRefit = config.displayRefit
		self.instanceID = config.instanceID
		self.dhcpClientID = config.dhcpClientID
		self.sshPrivateKeyPath = config.sshPrivateKeyPath
		self.sshPrivateKeyPassphrase = config.sshPrivateKeyPassphrase
		self.configuredUser = config.configuredUser
		self.configuredPassword = config.configuredPassword
		self.configuredGroup = config.configuredGroup
		self.configuredGroups = config.configuredGroups
		self.configuredPlatform = config.configuredPlatform
		self.clearPassword = config.clearPassword
		self.ifname = config.ifname
		self.autostart = config.autostart
		self.agent = config.agent
		self.firstLaunch = config.firstLaunch
		self.nested = config.nested
		self.attachedDisks = config.attachedDisks
		self.mounts = config.mounts
		self.networks = config.networks
		self.useCloudInit = config.useCloudInit
		self.sockets = config.sockets
		self.console = config.console
		self.forwardedPorts = config.forwardedPorts
		self.runningIP = config.runningIP
		self.display = config.display
		self.vncPassword = config.vncPassword
		self.ecid = config.ecid
		self.hardwareModel = config.hardwareModel
		self.changedFields = Set<PartialKeyPath<Self>>()
	}

	func save() throws {
		guard let vmname = self.vmname else {
			throw ServiceError("Virtual machine name is required to save configuration")
		}

		try self.saveLocally(name: vmname)
	}

	mutating func clearChangedFields() {
		self.changedFields?.removeAll()
	}

	func saveLocally(name: String) throws {
		let location = try StorageLocation(runMode: .app).find(name)
		let config = try location.config()
		let diskSize = config.diskSize / GoB

		config.suspendable = self.suspendable
		config.diskSize = self.diskSize
		config.cpuCount = self.cpuCount
		config.memorySizeMin = self.memorySizeMin
		config.memorySize = self.memorySize
		config.macAddress = self.macAddress
		config.dynamicPortForwarding = self.dynamicPortForwarding
		config.displayRefit = self.displayRefit
		config.instanceID = self.instanceID
		config.dhcpClientID = self.dhcpClientID
		config.sshPrivateKeyPath = self.sshPrivateKeyPath
		config.sshPrivateKeyPassphrase = self.sshPrivateKeyPassphrase
		config.configuredUser = self.configuredUser
		config.configuredPassword = self.configuredPassword
		config.configuredGroup = self.configuredGroup
		config.configuredGroups = self.configuredGroups
		config.configuredPlatform = self.configuredPlatform
		config.clearPassword = self.clearPassword
		config.ifname = self.ifname
		config.autostart = self.autostart
		config.agent = self.agent
		config.nested = self.nested
		config.attachedDisks = self.attachedDisks
		config.mounts = self.mounts
		config.networks = self.networks
		config.useCloudInit = self.useCloudInit
		config.sockets = self.sockets
		config.console = self.console
		config.forwardedPorts = self.forwardedPorts
		config.display = self.display

		try config.save()

		if diskSize != self.diskSize && location.status == .stopped {
			if config.os == .linux {
				try location.resizeDisk(diskSize)
			} else {
				try location.expandDisk(diskSize)
			}
		}
	}

	func buildOptions() -> BuildOptions {
		self.buildOptions(image: self.imageName, sshAuthorizedKey: self.sshAuthorizedKey)
	}

	func configureOptions() -> ConfigureOptions {
		.init(
			name: self.vmname!,
			user: self.configuredUserIfChanged,
			password: self.configuredPasswordIfChanged,
			cpu: UInt16(self.cpuCount),
			memory: self.memorySizeIfChanged,
			diskSize: self.diskSizeIfChanged,
			screenSize: self.displayIfChanged,
			attachedDisks: self.attachedDisksIfChanged,
			autostart: self.autostartIfChanged,
			nested: self.nestedVirtualizationIfChanged,
			suspendable: self.suspendableIfChanged,
			displayRefit: self.displayRefitIfChanged,
			forwardedPorts: self.forwardedPortsIfChanged,
			mounts: self.mountsIfChanged,
			networks: self.networksIfChanged,
			sockets: self.socketsIfChanged,
			consoleURL: .init(self.consoleIfChanged)
		)
	}

	func buildOptions(image: String, sshAuthorizedKey: String?) -> BuildOptions {
		.init(
			name: self.vmname!,
			cpu: UInt16(self.cpuCount),
			memory: self.memorySize,
			diskSize: self.diskSize,
			screenSize: self.display,
			attachedDisks: self.attachedDisks,
			user: self.configuredUser,
			password: self.configuredPassword,
			mainGroup: self.configuredGroup,
			otherGroups: self.configuredGroups ?? ["sudo"],
			clearPassword: self.clearPassword,
			autostart: self.autostart,
			nested: self.nestedVirtualization,
			suspendable: self.suspendable,
			netIfnames: self.ifname,
			image: image,
			sshAuthorizedKey: sshAuthorizedKey,
			userData: self.userData,
			networkConfig: self.networkConfig,
			displayRefit: self.displayRefit,
			forwardedPorts: self.forwardedPorts,
			mounts: self.mounts,
			networks: self.networks,
			sockets: self.sockets,
			autoinstall: self.autoinstall
		)
	}

	@MainActor
	func notify(name: NSNotification.Name, object: Any?) {
		NotificationCenter.default.post(name: name, object: object)
	}
}
