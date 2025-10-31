//
//  VirtualMachineConfig.swift
//  Caker
//
//  Created by Frederic BOLTZ on 27/06/2025.
//

import CakedLib
import Foundation
import GRPCLib
import SwiftUI
import Virtualization
import ArgumentParser

struct VirtualMachineConfig: Hashable {
	var os: VirtualizedOS = .linux
	var cpuCount: Int = 1
	var memorySize: UInt64 = 512
	var macAddress: String = ""
	var autostart: Bool = false
	var suspendable: Bool = false
	var dynamicPortForwarding: Bool = false
	var displayRefit: Bool = true
	var nestedVirtualization: Bool = true
	var display: VMScreenSize = .standard
	var forwardPorts: [TunnelAttachement] = []
	var sockets: [SocketDevice] = []
	var networks: [BridgeAttachement] = []
	var attachedDisks: [DiskAttachement] = []
	var mounts: DirectorySharingAttachments = []
	var vmname: String! = nil
	var agent: Bool = false

	var imageName: String
	var sshAuthorizedKey: String?
	var configuredUser: String
	var configuredPassword: String?
	var mainGroup: String
	var clearPassword: Bool
	var diskSize: UInt16 = 20
	var netIfnames: Bool = false
	var userData: String? = nil
	var networkConfig: String? = nil
	var autoinstall: Bool = false

	var humanReadableDiskSize: String {
		ByteCountFormatter.string(fromByteCount: Int64(self.diskSize) * 1024 * 1024 * 1024, countStyle: .file)
	}

	var humanReadableMemorySize: String {
		ByteCountFormatter.string(fromByteCount: Int64(self.memorySize) * 1024 * 1024, countStyle: .memory)
	}

	init() {
		imageName = OSCloudImage.ubuntu2404LTS.url.absoluteString
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
		display = .standard
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

		if FileManager.default.fileExists(atPath: "~/.ssh/id_rsa.pub".expandingTildeInPath) {
			self.sshAuthorizedKey = "~/.ssh/id_rsa.pub"
		}
	}

	init(location: VMLocation) throws {
		let config = try location.config()

		self.imageName = OSCloudImage.ubuntu2404LTS.url.absoluteString
		self.os = config.os
		self.cpuCount = config.cpuCount
		self.memorySize = config.memorySize / (1024 * 1024)
		self.macAddress = config.macAddress?.string ?? ""
		self.autostart = config.autostart
		self.suspendable = config.suspendable
		self.display = VMScreenSize(width: config.display.width, height: config.display.height)
		self.dynamicPortForwarding = config.dynamicPortForwarding
		self.displayRefit = config.displayRefit
		self.nestedVirtualization = config.nested
		self.forwardPorts = config.forwardedPorts
		self.sockets = config.sockets
		self.networks = config.networks
		self.attachedDisks = config.attachedDisks
		self.mounts = config.mounts
		self.vmname = location.name
		self.configuredUser = config.configuredUser
		self.configuredPassword = config.configuredPassword
		self.mainGroup = "adm"
		self.clearPassword = true
		self.diskSize = UInt16(try location.diskURL.fileSize() / (1024 * 1024 * 1024))
		self.agent = config.agent
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
			screenSize: self.display,
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

	@MainActor
	func notify(name: NSNotification.Name, object: Any?) {
		NotificationCenter.default.post(name: name, object: object)
	}

	func createVirtualMachine(imageSource: VMBuilder.ImageSource, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async {
		await withTaskCancellationHandler(
			operation: {
				do {
					let options = self.buildOptions(image: imageName, sshAuthorizedKey: sshAuthorizedKey)
					var ipswQueue: DispatchQueue!

					#if arch(arm64)
					if imageSource == .ipsw {
						ipswQueue = DispatchQueue(label: "IPSWQueue")
					}
					#endif

					try await BuildHandler.build(name: vmname, options: options, runMode: .app, queue: ipswQueue) { result in
						progressHandler(result)
					}

				} catch {
					progressHandler(.terminated(.failure(error)))
				}
			},
			onCancel: {
				progressHandler(.terminated(.failure(ServiceError("Cancelled"))))
			})
	}
}
