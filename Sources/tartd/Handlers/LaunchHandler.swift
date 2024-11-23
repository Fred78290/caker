import Foundation

protocol LaunchArguments : BuildArguments {
	var dir: [String] { get }
	var netBridged: [String] { get }
	var netSoftnet: Bool { get }
	var netSoftnetAllow: String? { get }
	var netHost: Bool { get }
}
struct LaunchHandler: TartdCommand, LaunchArguments {
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

	static func launch(_ self: LaunchArguments) throws {
		let vmDir = try VMStorageLocal().open(self.name)
		let lock = try vmDir.lock()

		if try !lock.trylock() {
			throw RuntimeError.VMAlreadyRunning("VM \"\(self.name)\" is already running!")
		}

		var arguments: [String] = ["--no-graphics", "--no-audio", "--nested"]

		// now VM state will return "running" so we can unlock
		try lock.unlock()

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

		var config: [String: Any] = try Dictionary(contentsOf: vmDir.configURL) as [String: Any]
		config["runningArguments"] = arguments
		try config.write(to: vmDir.configURL)

		try StartHandler.startVM(vmDir: vmDir)
	}

	static func launchVM(_ self: LaunchArguments) async throws {
		let tmpVMDir: VMDirectory = try VMDirectory.temporary()

		// Lock the temporary VM directory to prevent it's garbage collection
		let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
		try tmpVMDirLock.lock()

		try await withTaskCancellationHandler(
			operation: {
				try await VMBuilder.buildVM(vmName: self.name, vmDir: tmpVMDir, arguments: self)
				try VMStorageLocal().move(self.name, from: tmpVMDir)
				try Self.launch(self)
			},
			onCancel: {
				try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
			})
	}

	func run() async throws  -> String {
		try await Self.launchVM(self)
		return "launched \(name)"
	}

}
