import Foundation

protocol LaunchArguments : BuildArguments {
	var dir: [String] { get }
	var netBridged: [String] { get }
	var netSoftnet: Bool { get }
	var netSoftnetAllow: String? { get }
	var netHost: Bool { get }
	var nested: Bool { get }
	var foreground: Bool { get }
}

struct LaunchHandler: CakedCommand, LaunchArguments {
	var name: String
	var cpu: UInt16 = 1
	var memory: UInt64 = 512
	var diskSize: UInt16 = 20
	var user: String = "admin"
	var mainGroup: String = "adm"
	var insecure: Bool = false
	var cloudImage: String?
	var aliasImage: String?
	var fromImage: String?
	var ociImage: String?
	var sshAuthorizedKey: String?
	var remoteContainerServer: String = defaultSimpleStreamsServer
	var vendorData: String?
	var userData: String?
	var networkConfig: String?
	var dir: [String] = []
	var netBridged: [String] = []
	var netSoftnet: Bool = false
	var netSoftnetAllow: String?
	var netHost: Bool = false
	var nested: Bool = true
	var foreground: Bool = false
	var displayRefit: Bool = true

	static func launch(asSystem: Bool, _ self: LaunchArguments) throws {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(self.name)
		let cdrom = URL(fileURLWithPath: cloudInitIso, relativeTo: vmLocation.diskURL).absoluteURL
		let extras: URL = URL(fileURLWithPath: "extras.json", relativeTo: vmLocation.configURL)
		var config: [String:Any] = [:]
		var arguments: [String] = []

		if self.nested {
			arguments.append("--nested")
		}

		if try cdrom.exists() {
			arguments.append("--disk=\(cdrom.path())")
		}

		for dir in self.dir {
			arguments.append("--dir=\(dir)")
		}

		for net in self.netBridged {
			arguments.append("--net-bridged=\(net)")
		}

		if self.netSoftnet {
			arguments.append("--net-softnet")
		}

		if let netSoftnetAllow = self.netSoftnetAllow {
			arguments.append("--net-softnet-allow=\(netSoftnetAllow)")
		}

		if self.netHost {
			arguments.append("--net-host")
		}

		config["runningArguments"] = arguments

		try config.write(to: extras)

		try StartHandler.startVM(vmLocation: vmLocation, args: arguments, foreground: self.foreground)
	}

	static func launchVM(asSystem: Bool, _ self: LaunchArguments) async throws {
		let tempVMLocation: VMLocation = try VMLocation.tempDirectory()

		// Lock the temporary VM directory to prevent it's garbage collection
		let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
		try tmpVMDirLock.lock()

		try await withTaskCancellationHandler(
			operation: {
				try await VMBuilder.buildVM(vmName: self.name, vmLocation: tempVMLocation, arguments: self)
				try tmpVMDirLock.unlock()
				try StorageLocation(asSystem: asSystem).relocate(self.name, from: tempVMLocation)
				try Self.launch(asSystem: asSystem, self)
			},
			onCancel: {
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			})
	}

	func run(asSystem: Bool) async throws  -> String {
		try await Self.launchVM(asSystem: asSystem, self)
		return "launched \(name)"
	}

}
