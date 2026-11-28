import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Shout
import Socket
import Virtualization

extension URL {
	public var vmName: String {
		let name = self.name

		guard name.isEmpty else {
			return name
		}

		return self.host(percentEncoded: false)!
	}
}

public final class VMLocation: @unchecked Sendable, Hashable, Equatable, Purgeable {
	public static let defaultAgentListenPort = 5000
	public static let scheme = "caked-vm"
	public static let supportedSchemes: Set<String?> = ["caked-vm", "caked-vms"]

	public enum VMRunMode: Sendable {
		case none
		case caked
		case caker
		case provision
		case restart

		init(_ from: String) {
			switch from {
			case Home.cakedCommandName:
				self = .caked
			case Home.cakerCommandName:
				self = .caker
			default:
				self = .none
			}
		}

		var isAllowed: Bool {
			switch self {
			case .caked:
				return true
			case .caker:
				return ProcessInfo.processInfo.processName == Home.cakerCommandName
			case .none, .provision, .restart:
				return false
			}
		}
	}

	public enum Status: Sendable, Equatable, CustomStringConvertible {
		public var description: String {
			switch self {
			case .running(let mode):
				if mode == .provision {
					return "provisioning"
				} else if mode == .restart {
					return "restarting"
				}
				return "running"
			case .paused:
				return "paused"
			case .stopped:
				return "stopped"
			}
		}

		public var mode: String {
			if case .running(let mode) = self {
				switch mode {
				case .caked:
					return "caked"
				case .caker:
					return "caker"
				default:
					break
				}
			}

			return ""
		}

		case running(VMRunMode)
		case paused
		case stopped

		public var isProvisioning: Bool {
			if case .running(.provision) = self {
				return true
			} else {
				return false
			}
		}

		public var isRestarting: Bool {
			if case .running(.restart) = self {
				return true
			} else {
				return false
			}
		}

		public var isRunning: Bool {
			if case .running = self {
				return true
			} else {
				return false
			}
		}
	}

	public var rootURL: URL
	public let template: Bool
	public var source: String {
		self.template ? "template" : "vm"
	}

	private var cachedConfig: CakeConfig?

	public static func newVMLocation(vmURL: URL, runMode: Utils.RunMode) throws -> VMLocation {
		if vmURL.isFileURL {
			let location = VMLocation(rootURL: vmURL, template: false)

			try location.validate().rootURL.updateAccessDate()

			return location
		} else if supportedSchemes.contains(vmURL.scheme) {
			if let location = try? StorageLocation(runMode: runMode).find(vmURL.vmName) {
				return location
			}

			throw ServiceError(String(localized: "VM not found"))
		}

		throw ServiceError(String(localized: "Unsupported scheme"))
	}

	public init(rootURL: URL, template: Bool = false) {
		self.rootURL = rootURL
		self.template = template
	}

	public static func == (lhs: VMLocation, rhs: VMLocation) -> Bool {
		lhs.rootURL == rhs.rootURL
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(rootURL)
	}

	private func buildURL(_ path: String) -> URL {
		return rootURL.appendingPathComponent(path).resolvingSymlinksInPath().absoluteURL
	}

	public var configURL: URL {
		buildURL("config.json")
	}

	public var cakeURL: URL {
		buildURL("cake.json")
	}

	public var diskURL: URL {
		guard let config = try? CakeConfig(location: self.rootURL), let rootDisk = config.rootDisk, rootDisk.isEmpty == false else {
			return buildURL("disk.img")
		}

		let expanded = rootDisk.expandingTildeInPath
		if expanded.hasPrefix("/") {
			return URL(fileURLWithPath: expanded).resolvingSymlinksInPath().absoluteURL
		}
		return buildURL(expanded)
	}

	public var restartURL: URL {
		buildURL("run.restart")
	}

	public var nvramURL: URL {
		buildURL("nvram.bin")
	}

	public var stateURL: URL {
		buildURL("state.vzvmsave")
	}

	public var manifestURL: URL {
		buildURL("manifest.json")
	}

	public var cdromISO: URL {
		buildURL(cloudInitIso)
	}

	public var screenshotURL: URL {
		buildURL("screenshot.png")
	}

	public var outputLogURL: URL {
		buildURL("output.log")
	}

	public var provisionningURL: URL {
		buildURL("run.provision")
	}

	/// Debug recording of the periodic screenshots taken while PackerLite provisioning is
	/// in progress (see `ProvisioningVideoRecorder`) — deleted automatically when
	/// provisioning succeeds, kept around for inspection when it fails. Lives directly
	/// under `rootURL` like `screenshotURL`, so whole-VM removal (`delete()`) cleans it up
	/// for free without any dedicated handling.
	public var provisioningVideoURL: URL {
		buildURL("provision.mp4")
	}

	/// `provisioningVideoURL` only if a recording actually exists on disk — used to decide
	/// whether to mention it in a provisioning-failure message.
	public var existingProvisioningVideoURL: URL? {
		let url = provisioningVideoURL

		return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
	}

	/// Default `--output` destination for `caked record` (RecordHandler/Record.swift) when the
	/// operator doesn't pass an explicit path — lives directly under `rootURL` like
	/// `provisioningVideoURL`/`screenshotURL`, so it's swept up for free by whole-VM `delete()`.
	public var recordedTemplateURL: URL {
		buildURL("record.packerlite.yaml")
	}

	public func logURL(named fileName: String) -> URL? {
		guard fileName.isEmpty == false else {
			return nil
		}

		guard fileName == URL(fileURLWithPath: fileName).lastPathComponent else {
			return nil
		}

		return buildURL(fileName)
	}

	public var agentURL: URL {
		return rootURL.resolvingSymlinksInPath().socketPath(name: "agent")
	}

	public var serviceURL: URL {
		return rootURL.resolvingSymlinksInPath().socketPath(name: "svc")
	}

	public var seamlessSocketURL: URL {
		return rootURL.resolvingSymlinksInPath().socketPath(name: "smls")
	}

	public var name: String {
		rootURL.deletingPathExtension().lastPathComponent
	}

	public var url: URL {
		rootURL
	}

	public var fingerprint: String? {
		nil
	}

	public var inited: Bool {
		if self.template {
			return FileManager.default.fileExists(atPath: diskURL.path(percentEncoded: false))
		}

		return FileManager.default.fileExists(atPath: configURL.path(percentEncoded: false)) && FileManager.default.fileExists(atPath: diskURL.path(percentEncoded: false))
			&& FileManager.default.fileExists(atPath: nvramURL.path(percentEncoded: false))
	}

	public func reloadConfig() throws -> CakeConfig {
		let config = try loadConfig()

		if let cachedConfig = self.cachedConfig {
			cachedConfig.update(config)
		} else {
			self.cachedConfig = config
		}

		return config
	}

	public func loadConfig() throws -> CakeConfig {
		let config = try CakeConfig(location: rootURL)
		let diskURL: URL

		if let rootDisk = config.rootDisk, rootDisk.isEmpty == false {
			let expanded = rootDisk.expandingTildeInPath
			diskURL = expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded).resolvingSymlinksInPath() : buildURL(expanded)
		} else {
			diskURL = buildURL("disk.img")
		}

		config.diskSize = diskURL.diskSize

		return config
	}

	public func config() throws -> CakeConfig {
		guard let cachedConfig else {
			let config = try loadConfig()

			self.cachedConfig = config

			return config
		}

		return cachedConfig
	}

	public var status: Status {
		switch self.isPIDRunning() {
		case .caked:
			if FileManager.default.fileExists(atPath: self.provisionningURL.path(percentEncoded: false)) {
				return .running(.provision)
			}

			if FileManager.default.fileExists(atPath: self.restartURL.path(percentEncoded: false)) {
				return .running(.restart)
			}

			return .running(.caked)
		case .caker:
			if FileManager.default.fileExists(atPath: self.provisionningURL.path(percentEncoded: false)) {
				return .running(.provision)
			}

			if FileManager.default.fileExists(atPath: self.restartURL.path(percentEncoded: false)) {
				return .running(.restart)
			}

			return .running(.caker)
		case .provision:
			return .running(.provision)
		case .restart:
			return .running(.restart)
		case .none:
			if FileManager.default.fileExists(atPath: stateURL.path(percentEncoded: false)) {
				return .paused
			} else {
				return .stopped
			}
		}
	}

	public var macAddress: VZMACAddress? {
		if let config = try? CakeConfig(location: rootURL) {
			return config.getMacAddress()
		}

		return nil
	}

	public var pidFile: URL {
		buildURL("run.pid")
	}

	public func creationDate() throws -> Date {
		try self.rootURL.creationDate()
	}

	public func updatedDate() throws -> Date {
		try self.rootURL.updatedDate()
	}

	public func accessDate() throws -> Date {
		try self.rootURL.accessDate()
	}

	public func sizeBytes() throws -> UInt64 {
		try self.diskSize()
	}

	public func allocatedSizeBytes() throws -> UInt64 {
		try self.allocatedSize()
	}

	public func diskSize() throws -> UInt64 {
		var sizeBytes: UInt64 = 0

		try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsSubdirectoryDescendants).forEach {
			sizeBytes += $0.diskSize
		}

		return sizeBytes
	}

	public func allocatedSize() throws -> UInt64 {
		var allocatedSize: UInt64 = 0

		try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsSubdirectoryDescendants).forEach {
			allocatedSize += try $0.allocatedSizeBytes()
		}

		return allocatedSize
	}

	public func lock() -> Bool {
		let fd = open(configURL.path(percentEncoded: false), O_RDWR)

		if fd != -1 {
			close(fd)
		}

		return fd != -1
	}

	@discardableResult
	public func templateTo(_ target: VMLocation) throws -> VMLocation {
		guard DiskAttachement.isBlockingDevice(diskURL.path(percentEncoded: false)) == false else {
			throw ServiceError(String(localized: "Cannot create a template from a VM that uses a physical block device as its root disk"))
		}
		try FileManager.default.copyItem(at: self.diskURL, to: target.diskURL)
		try FileManager.default.copyItem(at: self.nvramURL, to: target.nvramURL)
		try FileManager.default.copyItem(at: self.configURL, to: target.configURL)
		try FileManager.default.copyItem(at: self.cakeURL, to: target.cakeURL)

		let templateConfig = try target.config()

		// Clear existing config
		templateConfig.attachedDisks = []
		templateConfig.mounts = []
		templateConfig.networks = []
		templateConfig.console = nil
		templateConfig.forwardedPorts = []
		templateConfig.firstLaunch = true
		templateConfig.instanceID = "i-\(String(format: "%x", Int(Date().timeIntervalSince1970)))"

		try templateConfig.save()

		return target
	}

	@discardableResult
	public func copyTo(_ target: VMLocation) throws -> VMLocation {
		guard DiskAttachement.isBlockingDevice(diskURL.path(percentEncoded: false)) == false else {
			throw ServiceError(String(localized: "Cannot copy a VM that uses a physical block device as its root disk"))
		}
		try FileManager.default.copyItem(at: self.diskURL, to: target.diskURL)
		try FileManager.default.copyItem(at: self.nvramURL, to: target.nvramURL)
		try FileManager.default.copyItem(at: self.configURL, to: target.configURL)
		try FileManager.default.copyItem(at: self.cakeURL, to: target.cakeURL)
		if FileManager.default.fileExists(atPath: self.cdromISO.path(percentEncoded: false)) {
			try FileManager.default.copyItem(at: self.cdromISO, to: target.cdromISO)
		}

		return target
	}

	@discardableResult
	public func duplicateTemporary(runMode: Utils.RunMode) throws -> VMLocation {
		return try self.copyTo(try Self.tempDirectory(runMode: runMode))
	}

	public static func tempDirectory(_ identifier: UUID = UUID(), runMode: Utils.RunMode) throws -> VMLocation {
		let tmpDir = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent(identifier.uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

		return VMLocation(rootURL: tmpDir, template: false)
	}

	@discardableResult
	public func validate() throws -> VMLocation {
		if !FileManager.default.fileExists(atPath: rootURL.path(percentEncoded: false)) {
			throw ServiceError(String(localized: "VM not found \(rootURL.lastPathComponent.deletingPathExtension)"))
		}

		if self.inited == false {
			throw ServiceError(String(localized: "VM is not correctly inited, missing files: (\(configURL.lastPathComponent), \(diskURL.lastPathComponent) or \(nvramURL.lastPathComponent))"))
		}

		_ = try self.config()

		return self
	}

	public func expandDisk(_ sizeGB: UInt64, format: SupportedDiskFormat) throws {
		let wantedFileSize = sizeGB * GiB
		let logger = Logger(self)

		if FileManager.default.fileExists(atPath: diskURL.path(percentEncoded: false)) {
			if format == .raw {
				try Bundle.execSandboxed("/usr/bin/hdiutil", with: ["resize", "-sectors", String("\(wantedFileSize / 512)"), diskURL.path(percentEncoded: false)]) { (exitCode, stdout, stderr) in
					guard exitCode == 0 else {
						throw ServiceError(String(localized: "Failed to resize disk with hdiutil: \(stderr)"))
					}

					logger.debug(stdout)

					return stdout
				}

			} else if #available(macOS 26.0, *) {
				try Bundle.execSandboxed("/usr/sbin/diskutil", with: ["image", "resize", "--size=\(sizeGB)G", diskURL.path(percentEncoded: false)]) { (exitCode, stdout, stderr) in
					guard exitCode == 0 else {
						throw ServiceError(String(localized: "Failed to resize disk with diskutil: \(stderr)"))
					}

					logger.debug(stdout)

					return stdout
				}
			} else {
				throw ServiceError(String(localized: "ASIF format is supported only on macOS 26.0+"))
			}
		} else if format == .raw {
			FileManager.default.createFile(atPath: diskURL.path(percentEncoded: false), contents: nil, attributes: nil)

			let diskFileHandle = try FileHandle.init(forWritingTo: diskURL)
			let curFileSize = try diskFileHandle.seekToEnd()

			defer {
				try? diskFileHandle.close()
			}

			if wantedFileSize < curFileSize {
				let curFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(curFileSize))
				let wantedFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(wantedFileSize))
				throw ServiceError(String(localized: "the new file size \(wantedFileSizeHuman) is lesser than the current disk size of \(curFileSizeHuman)"))
			} else if wantedFileSize > curFileSize {
				try diskFileHandle.truncate(atOffset: wantedFileSize)
			}
		} else if #available(macOS 26.0, *) {
			try Bundle.execSandboxed("/usr/sbin/diskutil", with: ["image", "create", "blank", "--format=ASIF", "--fs=none", "--size=\(sizeGB)G", diskURL.path(percentEncoded: false)]) { (exitCode, stdout, stderr) in
				guard exitCode == 0 else {
					throw ServiceError(String(localized: "Failed to create disk with diskutil: \(stderr)"))
				}

				logger.debug(stdout)

				return stdout
			}
		} else {
			throw ServiceError(String(localized: "ASIF format is supported only on macOS 26.0+"))
		}
	}

	public func resizeDisk(_ sizeGB: UInt64, format: SupportedDiskFormat, ignoreSmaller: Bool = false) throws {
		if format == .raw {
			let wantedFileSize = sizeGB * GiB

			if !FileManager.default.fileExists(atPath: diskURL.path(percentEncoded: false)) {
				FileManager.default.createFile(atPath: diskURL.path(percentEncoded: false), contents: nil, attributes: nil)
			}

			let diskFileHandle = try FileHandle.init(forWritingTo: diskURL)

			defer {
				do {
					try diskFileHandle.close()
				} catch {

				}
			}

			let curFileSize = try diskFileHandle.seekToEnd()

			if wantedFileSize < curFileSize {
				guard ignoreSmaller == false else {
					return
				}

				let curFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(curFileSize))
				let wantedFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(wantedFileSize))

				throw ServiceError(String(localized: "the new file size \(wantedFileSizeHuman) is lesser than the current disk size of \(curFileSizeHuman)"))

			} else if wantedFileSize > curFileSize {
				try diskFileHandle.truncate(atOffset: wantedFileSize)
			}
		} else if #available(macOS 26.0, *) {
			if FileManager.default.fileExists(atPath: diskURL.path(percentEncoded: false)) {
				let logger = Logger(self)

				try Bundle.execSandboxed("/usr/sbin/diskutil", with: ["image", "resize", "--size=\(sizeGB)G", diskURL.path(percentEncoded: false)]) { (exitCode, stdout, stderr) in
					guard exitCode == 0 else {
						throw ServiceError(String(localized: "Failed to resize disk with diskutil: \(stderr)"))
					}

					logger.debug(stdout)

					return stdout
				}
			} else {
				let logger = Logger(self)

				try Bundle.execSandboxed("/usr/sbin/diskutil", with: ["image", "create", "blank", "--fs=none", "--format=ASIF", "--size=\(sizeGB)G", diskURL.path(percentEncoded: false)]) { (exitCode, stdout, stderr) in
					guard exitCode == 0 else {
						throw ServiceError(String(localized: "Failed to create disk with diskutil: \(stderr)"))
					}

					logger.debug(stdout)

					return stdout
				}
			}
		} else {
			throw ServiceError(String(localized: "ASIF format is supported only on macOS 26.0+"))
		}
	}

	public func deletePID() throws {
		try pidFile.delete()
	}

	public func writeProvisionning() throws {
		FileManager.default.createFile(atPath: self.provisionningURL.path(percentEncoded: false), contents: nil)

		try self.writePID()
	}

	public func writePID() throws {
		try pidFile.writePID()
	}

	public func readPID() -> Int32? {
		pidFile.readPID()
	}

	public func isPIDRunning() -> VMRunMode {
		let result = pidFile.isPIDRunning([Home.cakedCommandName, Home.cakerCommandName])

		guard result.running else {
			return .none
		}

		if self.provisionningURL.fileExists {
			return .provision
		}

		if self.restartURL.fileExists {
			return .restart
		}

		return .init(result.processName)
	}

	public func removePID() {
		try? self.pidFile.delete()
		try? self.provisionningURL.delete()
	}

	public func delete() throws {
		try FileManager.default.removeItem(at: rootURL)
	}

	public func restartVirtualMachine(startMode: StartHandler.StartMode, gcd: Bool, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) throws {
		let config = try self.config()
		let home = try Home(runMode: runMode)

		func killVMRun() throws {
			let pid = pidFile.isPIDRunning()

			if pid.0 && pid.1 == Home.cakedCommandName {
				if let pid = pid.2 {
					if Bundle.isApplicationSandboxed {
						guard let client = try VMRunHandler.serviceMode.client(location: self, runMode: runMode) else {
							throw ServiceError(String(localized: "VM service is not running"))
						}

						let reply = try client.signal(signal: .shutdown)

						if reply.success == false {
							throw ServiceError(String(localized: "Failed to stop VM \(name), \(reply.reason)"))
						}
					} else {
						if kill(pid, SIGINT) != 0 {
							throw ServiceError(String(localized: "Failed to stop VM \(name), \(String(cString: strerror(errno)))"))
						}

						removePID()
					}

					_ = StartHandler.startVM(
						location: self,
						screenSize: nil,
						vncPassword: nil,
						vncPort: nil,
						waitIPTimeout: waitIPTimeout,
						startMode: startMode,
						gcd: gcd,
						recoveryMode: false,
						runMode: runMode,
						promise: nil)
				}
			}
		}

		// `reboot` returns as soon as the guest has been asked to restart, while the guest being replaced (and its agent) may
		// still answer: the restart marker must stay until the replacement guest is back, so the old agent is never taken
		// for the new one. Wait for the old one to go away (a failed call, or an uptime that starts over), then for the new
		// one. Best effort: a slow boot is not a failed restart, the marker is removed and agent monitoring takes over.
		func waitForRebootedAgent(previousUptime: UInt64?) {
			guard let conn = try? CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: 5, runMode: runMode, retries: .none) else {
				return
			}

			let downDeadline = Date().addingTimeInterval(60)
			var wentDown = false

			while wentDown == false && Date() < downDeadline {
				if case .success(let infos)? = try? conn.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(2)))).wait() {
					if let previousUptime, infos.hasUptime, infos.uptime < previousUptime {
						wentDown = true
					} else {
						Thread.sleep(forTimeInterval: 0.5)
					}
				} else {
					wentDown = true
				}
			}

			if wentDown == false {
				Logger(self).warn("VM \(self.name): the guest agent kept answering after reboot")
			}

			do {
				_ = try self.waitIPWithAgent(wait: waitIPTimeout, runMode: runMode)
			} catch {
				Logger(self).warn("VM \(self.name): the guest agent is not back after reboot: \(error)")
			}
		}

		// Same for a guest restarted over SSH, which has no agent to ask: its SSH server goes away, then comes back.
		func waitForRebootedSSH(host: String) {
			let downDeadline = Date().addingTimeInterval(60)
			var wentDown = false

			while wentDown == false && Date() < downDeadline {
				// Each connect is bounded by what is left of the window: a guest that drops attempts can't stretch it
				let remaining = downDeadline.timeIntervalSinceNow

				guard remaining > 0 else {
					break
				}

				if let socket = try? Socket.create(host: host, port: 22, timeout: UInt(max(1, min(remaining, 5) * 1000))) {
					socket.close()
					Thread.sleep(forTimeInterval: 0.5)
				} else {
					wentDown = true
				}
			}

			if wentDown == false {
				Logger(self).warn("VM \(self.name): the guest SSH server kept answering after reboot")
			}

			if Utilities.waitPortReady(host: host, port: 22, timeout: TimeInterval(waitIPTimeout)) == false {
				Logger(self).warn("VM \(self.name): the guest SSH server is not back after reboot")
			}
		}

		guard case .running = self.status else {
			throw ServiceError(String(localized: "VM \(name) is not running"))
		}

		defer {
			try? self.restartURL.delete()
		}

		try self.restartURL.writePID()

		if force || config.agent == false {
			try killVMRun()
		} else if try self.agentURL.exists() {
			let client = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: 60, runMode: runMode)
			var previousUptime: UInt64? = nil

			if case .success(let infos)? = try? client.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(5)))).wait(), infos.hasUptime {
				previousUptime = infos.uptime
			}

			_ = try client.run(
				request: Caked_RunCommand.with {
					$0.command = "reboot"
					$0.vmname = self.name
				})

			waitForRebootedAgent(previousUptime: previousUptime)
		} else {
			let reply = WaitIPHandler.waitIP(name: name, wait: 60, runMode: runMode)

			if reply.success {
				let ssh = try SSH(host: reply.ip)

				try ssh.authenticate(username: config.configuredUser, privateKey: home.sshPrivateKey.path(percentEncoded: false), publicKey: home.sshPublicKey.path(percentEncoded: false), passphrase: String.empty)
				try self.restartURL.writePID()
				try ssh.execute("sudo reboot")

				waitForRebootedSSH(host: reply.ip)
			} else {
				try killVMRun()
			}
		}
	}

	public func suspendVirtualMachine(runMode: Utils.RunMode) throws {
		guard case .running = self.status else {
			throw ServiceError(String(localized: "VM \(name) is not running"))
		}

		let pid = pidFile.isPIDRunning()

		if pid.0 && pid.1 == Home.cakedCommandName {
			if Bundle.isApplicationSandboxed {
				guard let client = try VMRunHandler.serviceMode.client(location: self, runMode: runMode) else {
					throw ServiceError(String(localized: "VM service is not running"))
				}

				let reply = try client.signal(signal: .suspend)

				if reply.success == false {
					throw ServiceError(String(localized: "Failed to suspend VM \(name), \(reply.reason)"))
				}
			} else if let pid = pid.2 {
				if kill(pid, SIGUSR1) != 0 {
					throw ServiceError(String(localized: "Failed to suspend VM \(name), \(String(cString: strerror(errno)))"))
				}
				removePID()
			}
		}
	}

	public func stopVirtualMachine(force: Bool, runMode: Utils.RunMode) throws {
		let config = try self.config()
		let home = try Home(runMode: runMode)

		guard case .running = self.status else {
			throw ServiceError(String(localized: "VM \(name) is not running"))
		}

		let pid = pidFile.isPIDRunning()

		func killVMRun() throws {
			if pid.0 && pid.1 == Home.cakedCommandName {
				if Bundle.isApplicationSandboxed {
					guard let client = try VMRunHandler.serviceMode.client(location: self, runMode: runMode) else {
						throw ServiceError(String(localized: "VM service is not running"))
					}

					let reply = try client.signal(signal: .shutdown)

					if reply.success == false {
						throw ServiceError(String(localized: "Failed to stop VM \(name), \(reply.reason)"))
					}
				} else if let pid = pid.2 {
					if kill(pid, SIGINT) != 0 {
						throw ServiceError(String(localized: "Failed to stop VM \(name), \(String(cString: strerror(errno)))"))
					}
					removePID()
				}
			}
		}

		if force || config.agent == false {
			try killVMRun()
		} else if try self.agentURL.exists() {
			let client = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: 60, runMode: runMode)

			do {
				try client.shutdown().log()
			} catch {
				try killVMRun()
			}
		} else {
			let reply = WaitIPHandler.waitIP(name: name, wait: 60, runMode: runMode)

			if reply.success {
				let ssh = try SSH(host: reply.ip)
				try ssh.authenticate(username: config.configuredUser, privateKey: home.sshPrivateKey.path(percentEncoded: false), publicKey: home.sshPublicKey.path(percentEncoded: false), passphrase: String.empty)
				try ssh.execute("sudo shutdown now")
			} else {
				try killVMRun()
			}
		}

		if pid.pid != getpid() {
			while case .running = self.status {
				Thread.sleep(forTimeInterval: 1)
			}
		}

		removePID()
	}

	@MainActor
	public func startVirtualMachine(
		_ serviceMode: VMRunServiceMode,
		on: EventLoop,
		config: CakeConfig,
		screenSize: CGSize,
		display: VMRunHandler.DisplayMode,
		vncPassword: String,
		vncPort: Int,
		mode: VirtualMachine.Mode,
		runMode: Utils.RunMode,
		queue: DispatchQueue?,
		promise: EventLoopPromise<Void>? = nil,
		completionHandler: VirtualMachine.StartCompletionHandler? = nil
	) throws -> (address: EventLoopFuture<String?>, vm: VirtualMachine) {
		let vm = try VirtualMachine(
			location: self,
			config: config,
			display: display,
			screenSize: screenSize,
			mode: mode,
			runMode: runMode,
			queue: queue)

		let runningIP = try vm.runInBackground(
			serviceMode,
			on: on,
			promise: promise,
			completionHandler: completionHandler)

		try self.writePID()

		return (runningIP, vm)
	}

	public func waitIPWithLease(config: CakeConfig, wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let start: Date = Date.now
		let macAddress = config.macAddress ?? String.empty
		let clientID = config.dhcpClientID ?? macAddress
		var leases: DHCPLeaseProvider
		var count = 0

		guard macAddress.isEmpty == false && clientID.isEmpty == false else {
			throw ShellError(terminationStatus: -1, error: String(localized: "Unable to get MAC address for VM \(self.name)"), message: String(localized: "Any mac address or client ID is not configured"))
		}

		// Only the VM's own networks: a lease left on a network it no longer uses must not win.
		let networkNames = config.qualifiedNetworks.map(\.network)

		repeat {
			if let startedProcess = startedProcess, startedProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: String(localized: "Caked vmrun process is not running"), message: String.empty)
			}

			// Try also arp if dhcp is disabled
			if count & 1 == 1 {
				leases = try ARPParser()

				if let runningIP = leases[macAddress] {
					return runningIP
				}
			} else {
				// No lease table yet (a fresh host, or caked's DHCP server hasn't granted a lease): keep waiting.
				if let parser = try? DHCPLeaseParser(runMode: runMode, networks: networkNames) {
					if let runningIP = parser[clientID] {
						return runningIP
					}
				}

				// Either no table yet or no lease for this client yet: don't rescan every table in a tight loop.
				Thread.sleep(forTimeInterval: 0.25)
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: String(localized: "Unable to get IP for VM \(self.name)"), message: String(localized: "Timeout"))
	}

	func vmInfos(wait: Int = 5, retries: ConnectionBackoff.Retries = .none, runMode: Utils.RunMode, _ completion: @escaping (Result<Caked_InfoReply, Error>) -> Void) {
		do {
			let conn = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: wait, runMode: runMode, retries: retries)
			let result: EventLoopFuture<Result<Caked_InfoReply, Error>> = try conn.info()

			result.whenComplete { result in
				switch result {
				case .failure(let error):
					completion(.failure(error))
				case .success(let value):
					completion(value)
				}
			}
		} catch {
			completion(.failure(error))
		}
	}

	public func waitIPWithAgent(wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let conn = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: 5, runMode: runMode, retries: .none)
		let start: Date = Date.now
		var count = 0

		repeat {
			if let startedProcess = startedProcess, startedProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: String(localized: "Caked vmrun process is not running"), message: String.empty)
			}

			// A call made while the agent isn't listening yet (Windows Server starts it some seconds after boot) can wait forever:
			// each one gets a deadline, so `wait` is honored and the next one reconnects.
			let attemptStart = Date.now

			do {
				switch try conn.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(5)))).wait() {
				case .success(let infos):
					if let runningIP = infos.ipaddresses.first {
						return runningIP
					}

					Logger(self).debug("Agent of VM \(self.name) answered with no IP address yet, attempt \(count)")
				case .failure(let error):
					Logger(self).trace("Agent of VM \(self.name) failed, attempt \(count): \(error)")
				}
			} catch {
				Logger(self).debug("Agent of VM \(self.name) not reachable, attempt \(count): \(error)")
			}

			// Don't spin while the connection is refused at once
			if Date.now.timeIntervalSince(attemptStart) < 1 {
				Thread.sleep(forTimeInterval: 0.5)
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: String(localized: "Unable to get IP for VM \(self.name)"), message: String.empty)
	}

	public func waitIP(config: CakeConfig, wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		if startedProcess == nil {
			guard case .running = self.status else {
				throw ServiceError(String(localized: "VM \(name) is not running"))
			}
		}

		if config.firstLaunch && config.source.supportProvisionning {
			return try waitIPWithLease(config: config, wait: wait, runMode: runMode, startedProcess: startedProcess)
		} else if config.agent {
			return try waitIPWithAgent(wait: wait, runMode: runMode, startedProcess: startedProcess)
		} else {
			return try waitIPWithLease(config: config, wait: wait, runMode: runMode, startedProcess: startedProcess)
		}
	}

	public func waitIP(wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		return try self.waitIP(config: self.config(), wait: wait, runMode: runMode, startedProcess: startedProcess)
	}

	public func waitIP(on: EventLoop, config: CakeConfig, wait: Int, runMode: Utils.RunMode) throws -> EventLoopFuture<String?> {
		if config.source == .iso && config.firstLaunch {
			return on.submit {
				try? self.waitIPWithLease(config: config, wait: wait, runMode: runMode)
			}
		}

		if config.agent {
			return try CakeAgentConnection.createCakeAgentConnection(on: on, listeningAddress: self.agentURL, timeout: wait, runMode: runMode).info().flatMap { response in
				switch response {
				case .success(let infos):
					return on.makeSucceededFuture(infos.ipaddresses.first)
				case .failure:
					return on.makeSucceededFuture(nil)
				}
			}
		} else {
			return on.submit {
				try? self.waitIPWithLease(config: config, wait: wait, runMode: runMode)
			}
		}
	}

	internal func createSSH(host: String, timeout: UInt) throws -> SSH {
		let start: Date = Date.now

		repeat {
			do {
				return try SSH(host: host, timeout: timeout * 1000)
			} catch {
				if Date.now.timeIntervalSince(start) > TimeInterval(timeout) {
					throw error
				}

				Thread.sleep(forTimeInterval: 1)
			}
		} while true
	}

	func getPublicSSHKeys(config: CakeConfig, runMode: Utils.RunMode) throws -> [String] {
		let sharedPublicKey = try Home(runMode: runMode).getSharedPublicKey()

		if let sshPrivateKeyPath = config.sshPrivateKeyPath {
			if let content = try? String(contentsOf: URL(fileURLWithPath: sshPrivateKeyPath.expandingTildeInPath, relativeTo: self.configURL), encoding: .utf8) {
				return [sharedPublicKey, content]
			}
		}

		return [sharedPublicKey]
	}

	public func installAgent(updateAgent: Bool, config: CakeConfig, runningIP: String, timeout: UInt = 120, runMode: Utils.RunMode) async throws -> Bool {
		Logger(self).info("Installing agent on \(self.name), version=\(CAKEAGENT_VERSION)")

		// A Windows guest has no shell like the others: PowerShell over its OpenSSH server (installed with the guest)
		if config.isWindowsGuest {
			return try await installWindowsAgent(config: config, runningIP: runningIP, timeout: timeout, runMode: runMode)
		}

		let home = try Home(runMode: runMode)
		let imageSource = config.source
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let caCert = try String(contentsOf: certificates.caCertURL, encoding: .ascii).base64EncodedString()
		let serverKey: String = try String(contentsOf: certificates.serverKeyURL, encoding: .ascii).base64EncodedString()
		let serverPem = try String(contentsOf: certificates.serverCertURL, encoding: .ascii).base64EncodedString()
		let sshPublicKeys = try getPublicSSHKeys(config: config, runMode: runMode).joined(separator: "\n")
		// The flags are read once: the host keyboard layout in them can change while the agent is installed, and what is
		// recorded as installed must be what the script registered.
		let serviceFlags = config.agentServiceFlags
		let ssh = try createSSH(host: runningIP, timeout: timeout)
		// One file per invocation: a fixed name let two concurrent installs overwrite each other's script, so one could upload
		// and run the other's flags/VM, and record the wrong `agentInstalledFlags`.
		let tempFileURL = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent("install-agent-\(UUID().uuidString).sh")
		let install_agent = String(
			format: try loadBundledShellScript(named: "ssh-install-cakeagent", runMode: runMode),
			config.configuredUser,
			CAKEAGENT_VERSION,
			"\(VMLocation.defaultAgentListenPort)",
			serviceFlags,
			sshPublicKeys,
			caCert,
			serverPem,
			serverKey,
			AppStoreGuestDNS.sshFragment(
				domain: ComposeDNS.domainSuffix,
				ip: BridgeAttachement.defaultNetworkGateway.stringBefore(before: "/"),
				port: "\(ComposeDNS.internalBindPort)")
		)

		// The script embeds the agent's TLS private key: create it private (0600) from the start, never world-readable
		guard FileManager.default.createFile(atPath: tempFileURL.path(percentEncoded: false), contents: Data(install_agent.utf8), attributes: [.posixPermissions: 0o600]) else {
			throw ServiceError(String(localized: "Unable to write the agent install script"))
		}

		defer {
			// Kept for inspection at debug level (or below), like before
			if Logger.Level() < .debug {
				try? tempFileURL.delete()
			}
		}

		let agentBinary = try await Utilities.cakeagentBinary(os: config.os, runMode: runMode)

		if imageSource.isMacOS {
			try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
		} else if let sshPrivateKeyPath = config.sshPrivateKeyPath {
			try ssh.authenticate(
				username: config.configuredUser, privateKey: URL(fileURLWithPath: sshPrivateKeyPath.expandingTildeInPath, relativeTo: self.configURL).absoluteURL.path(percentEncoded: false), passphrase: config.sshPrivateKeyPassphrase)
		} else if let exists = try? home.sshPrivateKey.exists(), exists && (config.clearPassword == false || config.configuredPassword == nil) {
			// This key is only tried opportunistically (the VM never selected it): when the guest rejects it, fall back to the password
			do {
				try ssh.authenticate(username: config.configuredUser, privateKey: home.sshPrivateKey.path(percentEncoded: false), publicKey: home.sshPublicKey.path(percentEncoded: false))
			} catch {
				Logger(self).debug("SSH key authentication rejected on \(self.name), falling back to password: \(error)")

				try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
			}
		} else {
			try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
		}

		_ = try ssh.sendFile(localURL: agentBinary, remotePath: "/tmp/cakeagent", permissions: .init(rawValue: 0o755))
		_ = try ssh.sendFile(localURL: tempFileURL, remotePath: "/tmp/install-agent.sh", permissions: .init(rawValue: 0o755))

		// The installer's own exit status is the command's: `| tee` would replace it with tee's (sh has no pipefail).
		let cmd = "echo \(config.configuredPassword ?? config.configuredUser)|sudo -S sh -c '/tmp/install-agent.sh > ~/install-agent.log 2>&1; status=$?; cat ~/install-agent.log; exit $status'"
		let result = try ssh.capture(cmd)

		if result.status == 0 {
			Logger(self).info("Agent installed on \(self.name), exit code: \(result.status)")
			Logger(self).debug(result.output)

			// The caller saves the config; this is what a later start compares with to know the service must be re-registered
			config.agentInstalledFlags = serviceFlags
		} else {
			Logger(self).error("Agent installation failed on \(self.name), exit code: \(result.status)\n\(result.output)")

			throw ServiceError(String(localized: "Agent installation failed on \(self.name)"))
		}

		return true
	}

	/// Registers the agent service of a Linux guest again with the flags the config asks for (`agentServiceFlags`: mounts,
	/// seamless windows), through the agent itself over vsock: nothing depends on the guest's network being reachable from
	/// the host, as SSH does, and the agent binary is already there. Stopping the service kills the agent that is running the
	/// command, so the work is handed to a transient systemd unit (or a detached shell where there is no systemd) that
	/// outlives it. Returns once the work is started, the service is back a few seconds later.
	public func updateAgentService(config: CakeConfig, runMode: Utils.RunMode) throws {
		let certs = "/etc/cakeagent/ssl"
		let work = #"""
			sleep 1
			bin=/usr/local/bin/cakeagent
			certs=\#(certs)
			flags=$1
			port=$2
			backup=$(mktemp -d /run/cakeagent-reflag.XXXXXX) || exit 1

			register() {
				# $1 is deliberately unquoted: it is a list of flags
				$bin service install --listen="vsock://any:$port" --ca-cert=$certs/ca.pem --tls-cert=$certs/server.pem --tls-key=$certs/server.key $1
			}

			# What is in place now, kept so that a failed update can put it back
			oldflags=$(cat /etc/cakeagent/service-flags 2>/dev/null || true)
			had_sysconfig=0
			if [ -f /etc/sysconfig/cakeagent ]; then
				cp -p /etc/sysconfig/cakeagent "$backup/sysconfig" && had_sysconfig=1
			fi
			[ -f /etc/systemd/system/cakeagent.service ] && cp -p /etc/systemd/system/cakeagent.service "$backup/systemd"
			[ -f /etc/init.d/cakeagent ] && cp -p /etc/init.d/cakeagent "$backup/initd"

			rollback() {
				echo "$1: restoring the previous CakeAgent service"
				$bin service stop >/dev/null 2>&1 || true
				if [ "$had_sysconfig" = 1 ]; then
					cp -p "$backup/sysconfig" /etc/sysconfig/cakeagent
				else
					rm -f /etc/sysconfig/cakeagent
				fi
				[ -f "$backup/systemd" ] && cp -p "$backup/systemd" /etc/systemd/system/cakeagent.service
				[ -f "$backup/initd" ] && cp -p "$backup/initd" /etc/init.d/cakeagent
				command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload >/dev/null 2>&1
				if ! $bin service start; then
					# The files did not bring it back (another registration layout): register it again with the previous flags
					register "$oldflags" && $bin service start || echo "CakeAgent previous service could not be restarted"
				fi
				rm -rf "$backup"
				exit 1
			}

			$bin service stop || true
			mkdir -p /etc/sysconfig
			echo "EXTRA_FLAGS=" > /etc/sysconfig/cakeagent || rollback "CakeAgent service configuration failed"
			chmod 644 /etc/sysconfig/cakeagent
			register "$flags" || rollback "CakeAgent service reinstall reported an error"
			$bin service start || rollback "CakeAgent service did not start"
			rm -rf "$backup"
			# Only a registration that worked is recorded: the host reads this back before it trusts the update
			mkdir -p /etc/cakeagent
			printf '%s' "$flags" > /etc/cakeagent/service-flags
			"""#
		// Checked before anything is touched, and in the command itself (not the detached script) so a bad request is reported
		// to the caller at once instead of leaving the service stopped
		let validation = #"""
			case "$2" in ''|*[!0-9]*) echo "Invalid agent port"; exit 1;; esac
			if [ -n "$(printf '%s' "$1" | tr -d 'A-Za-z0-9 _=,:/.@+%-')" ]; then
				echo "Invalid agent service flags"
				exit 1
			fi
			[ -x /usr/local/bin/cakeagent ] || { echo "CakeAgent is not installed"; exit 1; }
			for f in ca.pem server.pem server.key; do
				[ -r \#(certs)/$f ] || { echo "CakeAgent certificate $f is missing"; exit 1; }
			done
			"""#
		// What the SSH installer (`ssh-install-cakeagent.sh`) sets up when seamless windows are a service flag: X11 applications
		// show through Xwayland. Kept in step with that script, but not best effort here: this runs in the command itself, before
		// anything is touched, so a guest where the package can't be installed reports it at once and is never registered with
		// `--seamless` (and so never recorded as updated), instead of looking enabled while X11 applications can't show.
		let prerequisites = #"""
			case "$1" in
			*--seamless*)
				# The script arrives on this shell's standard input: nothing run below may read it
				if ! command -v Xwayland >/dev/null 2>&1 && [ ! -x /usr/bin/Xwayland ]; then
					if command -v apt-get >/dev/null 2>&1; then
						DEBIAN_FRONTEND=noninteractive apt-get install -y xwayland </dev/null >&2
					elif command -v dnf >/dev/null 2>&1; then
						dnf install -y xorg-x11-server-Xwayland </dev/null >&2
					elif command -v yum >/dev/null 2>&1; then
						yum install -y xorg-x11-server-Xwayland </dev/null >&2
					elif command -v zypper >/dev/null 2>&1; then
						zypper --non-interactive --gpg-auto-import-keys install -y xwayland </dev/null >&2
					elif command -v apk >/dev/null 2>&1; then
						apk add --no-cache xwayland </dev/null >&2
					elif command -v pacman >/dev/null 2>&1; then
						pacman -S --noconfirm xorg-xwayland </dev/null >&2
					fi

					if ! command -v Xwayland >/dev/null 2>&1 && [ ! -x /usr/bin/Xwayland ]; then
						echo "Xwayland is not installed and could not be installed: install the Xwayland package in the guest (apt install xwayland, dnf install xorg-x11-server-Xwayland, ...) and start the VM again" >&2
						exit 1
					fi
				fi
				;;
			esac
			"""#
		let launcher = #"""
			\#(validation)
			\#(prerequisites)
			cat > /run/cakeagent-reflag.sh <<'CAKEAGENT_EOS'
			\#(work)
			CAKEAGENT_EOS
			if command -v systemd-run >/dev/null 2>&1; then
				systemd-run --no-block --unit=cakeagent-reflag sh /run/cakeagent-reflag.sh "$1" "$2"
			else
				setsid sh /run/cakeagent-reflag.sh "$1" "$2" >/dev/null 2>&1 </dev/null &
			fi
			"""#

		// One snapshot for the script and for the record (the host keyboard layout in the flags can change meanwhile)
		let serviceFlags = config.agentServiceFlags

		Logger(self).info("Updating the agent service of \(self.name), flags: \(serviceFlags.isEmpty ? "none" : serviceFlags)")

		let client = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: 30, runMode: runMode, retries: .upTo(10))

		// The agent runs `/bin/sh -c "<command> <arguments joined by a space>"`: one properly quoted command line, with the
		// script base64 encoded so that nothing in it can be taken apart by that join.
		func quoted(_ value: String) -> String {
			"'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
		}

		let script = Data(launcher.utf8).base64EncodedString()
		// The launcher can install a package (Xwayland) before it hands the work over, so it gets a generous deadline, but not an
		// unlimited one: an agent that never answers must not hold the VM start forever.
		let reply = try client.run(
			command: "echo \(script) | base64 -d | sh -s -- \(quoted(serviceFlags)) \(quoted("\(VMLocation.defaultAgentListenPort)"))",
			callOptions: CallOptions(timeLimit: .timeout(.seconds(300))))

		guard reply.exitCode == 0 else {
			let details = reply.stderr.isEmpty ? String(format: String(localized: "exit code %d"), Int(reply.exitCode)) : String(decoding: reply.stderr, as: UTF8.self)

			throw ServiceError(String(format: String(localized: "Agent service update failed on %@: %@"), self.name, details))
		}

		// A zero exit only says the work was handed over. The guest writes `service-flags` once the service is registered
		// and started again: wait for the agent to come back and read it, so a failed registration stays eligible for a retry.
		let expected = serviceFlags
		let deadline = Date().addingTimeInterval(60)

		while Date() < deadline {
			Thread.sleep(forTimeInterval: 2)

			// Each probe is capped by what is left of the 60 seconds, so a hung agent can't stretch the wait past it
			let remaining = deadline.timeIntervalSinceNow

			guard remaining >= 1 else {
				break
			}

			let probeTimeout = min(10, Int(remaining))

			guard let probe = try? CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: probeTimeout, runMode: runMode, retries: .upTo(1)),
				let recorded = try? probe.run(command: "cat /etc/cakeagent/service-flags", callOptions: CallOptions(timeLimit: .timeout(.seconds(Int64(probeTimeout))))), recorded.exitCode == 0
			else {
				continue
			}

			if String(decoding: recorded.stdout, as: UTF8.self) == expected {
				// The caller saves the config; this is what a later start compares with
				config.agentInstalledFlags = expected
				return
			}
		}

		throw ServiceError(String(format: String(localized: "Agent service update was not confirmed on %@: the service did not come back with the new flags"), self.name))
	}

	/// Installs the agent in a Windows guest, or replaces it when its service is already there (the installer's first boot
	/// does the first install, this is what updates it, or installs it in a guest where it is missing). The executable and a
	/// PowerShell script go over SSH to `C:\ProgramData\caker` and the script runs elevated: an administrator's SSH session
	/// is. `installAgent` is true only when the agent runs with the version this build asks for.
	private func installWindowsAgent(config: CakeConfig, runningIP: String, timeout: UInt, runMode: Utils.RunMode) async throws -> Bool {
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let script = WindowsInstallResources.agentUpdatePowerShell(
			version: CAKEAGENT_VERSION, port: UInt16(VMLocation.defaultAgentListenPort),
			caCert: try String(contentsOf: certificates.caCertURL, encoding: .ascii),
			serverCert: try String(contentsOf: certificates.serverCertURL, encoding: .ascii),
			serverKey: try String(contentsOf: certificates.serverKeyURL, encoding: .ascii))
		let agentBinary = try await Utilities.cakeagentWindowsBinary(runMode: runMode)
		let tempFileURL = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent(WindowsInstallResources.agentUpdateScript)
		let ssh = try createSSH(host: runningIP, timeout: timeout)

		try script.write(to: tempFileURL, atomically: true, encoding: .utf8)

		defer {
			if Logger.Level() < .debug {
				try? tempFileURL.delete()
			}
		}

		if let sshPrivateKeyPath = config.sshPrivateKeyPath {
			try ssh.authenticate(
				username: config.configuredUser, privateKey: URL(fileURLWithPath: sshPrivateKeyPath.expandingTildeInPath, relativeTo: self.configURL).absoluteURL.path(percentEncoded: false), passphrase: config.sshPrivateKeyPassphrase)
		} else {
			try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
		}

		let directory = WindowsInstallResources.agentUpdateDirectory

		// Not sendFile (SCP): libssh2 quotes the path with single quotes, which Windows' cmd.exe takes literally
		let sftp = try ssh.openSftp()

		try sftp.upload(localURL: agentBinary, remotePath: "\(directory)/\(WindowsInstallResources.agentUpdateExecutable)")
		try sftp.upload(localURL: tempFileURL, remotePath: "\(directory)/\(WindowsInstallResources.agentUpdateScript)")

		let result = try ssh.capture("powershell -NoProfile -ExecutionPolicy Bypass -File \(directory.replacingOccurrences(of: "/", with: "\\"))\\\(WindowsInstallResources.agentUpdateScript)")

		if result.status == 0 {
			Logger(self).info("Agent installed on \(self.name), exit code: \(result.status)")
			Logger(self).debug(result.output)
		} else {
			Logger(self).error("Agent installation failed on \(self.name), exit code: \(result.status)\n\(result.output)")

			throw ServiceError(String(localized: "Agent installation failed on \(self.name)"))
		}

		return true
	}

	public func executePostBootCommand(_ commands: PackerLiteTemplate.PostCommand, config: CakeConfig, runningIP: String, timeout: UInt = 120, runMode _: Utils.RunMode, progressHandler: @escaping ProvisionHandler.ProvisionProgressHandler)
		async throws
	{
		Logger(self).info("Running post-boot commands on \(self.name)")

		let imageSource = config.source
		let ssh = try createSSH(host: runningIP, timeout: timeout)

		ssh.ptyType = .xterm

		if imageSource.isMacOS {
			try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
		} else if let sshPrivateKeyPath = config.sshPrivateKeyPath, commands.useSshKey {
			try ssh.authenticate(
				username: config.configuredUser, privateKey: URL(fileURLWithPath: sshPrivateKeyPath.expandingTildeInPath, relativeTo: self.configURL).absoluteURL.path(percentEncoded: false), passphrase: config.sshPrivateKeyPassphrase)
		} else {
			try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
		}

		// Commands/output are only logged at .debug — post_boot_command entries are author-supplied
		// shell commands that can reasonably embed secrets (tokens, passwords), and .error-level logs
		// are far more likely to be captured/retained than .debug ones. The thrown ServiceError (and
		// its Localizable.xcstrings entry) intentionally identifies the failing step by index only,
		// never by command content, for the same reason.
		for (index, command) in commands.commands.enumerated() {
			Logger(self).debug("Running post-boot command #\(index + 1) on \(self.name): \(command)")

			progressHandler(.substep(command))

			let result = try ssh.execute(command) { output in
				print(output, terminator: "")
			}

			if result != 0 {
				Logger(self).error("Post-boot command #\(index + 1) failed on \(self.name), exit code: \(result)")
				throw ServiceError(String(format: String(localized: "Post-boot command #%d failed on %@"), index + 1, self.name))
			}
		}
	}

}

// MARK: - Temporary copies (duplicate, create template, push)

/// Lets an operation built on a temporary VM copy (duplicate, create template, push) be cancelled from
/// another thread: `cancel()` kills the temporary VM it may have booted (to reset cloud-init) so a step
/// blocked on it returns at once, and the operation then destroys that copy instead of using it.
public final class TemporaryVMCancellation: @unchecked Sendable {
	private let lock = NSLock()
	private var cancelled = false
	private var committed = false
	private var temporary: VMLocation?
	private let runMode: Utils.RunMode

	public init(runMode: Utils.RunMode) {
		self.runMode = runMode
	}

	/// The reason a cancelled duplicate, template creation or push reports.
	public static var cancelledReason: String {
		String(localized: "Cancelled")
	}

	public var isCancelled: Bool {
		self.lock.withLock { self.cancelled }
	}

	/// Asks the operation to stop. Does nothing once it has committed: it is finished and reports success.
	public func cancel() {
		let temporary: VMLocation? = self.lock.withLock {
			guard self.committed == false, self.cancelled == false else {
				return nil
			}

			self.cancelled = true

			return self.temporary
		}

		if let temporary {
			let runMode = self.runMode

			// Not on the caller's thread: a task cancellation handler must return quickly.
			DispatchQueue.global(qos: .userInitiated).async {
				temporary.killTemporaryVirtualMachine(runMode: runMode)
			}
		}
	}

	func register(_ temporary: VMLocation) throws {
		try self.lock.withLock {
			self.temporary = temporary

			if self.cancelled {
				throw CancellationError()
			}
		}
	}

	func checkCancellation() throws {
		if self.isCancelled {
			throw CancellationError()
		}
	}

	/// Runs `body` (the step that makes the result visible, such as moving the copy to its final name)
	/// unless the operation was cancelled, with `cancel()` held off until it has finished, so a
	/// cancellation never lands halfway. Keep `body` short: a cancellation waits for it.
	func commit(_ body: () throws -> Void) throws {
		try self.lock.withLock {
			if self.cancelled {
				throw CancellationError()
			}

			try body()

			self.committed = true
		}
	}
}

extension TemporaryVMCancellation {
	/// Runs blocking `work` (file copies, booting a temporary VM) off the cooperative pool, with a new
	/// token: cancelling the calling task cancels that token.
	public static func run<T: Sendable>(runMode: Utils.RunMode, _ work: @escaping @Sendable (TemporaryVMCancellation) -> T) async -> T {
		let cancellation = TemporaryVMCancellation(runMode: runMode)

		return await withTaskCancellationHandler {
			await withCheckedContinuation { continuation in
				DispatchQueue.global(qos: .userInitiated).async {
					continuation.resume(returning: work(cancellation))
				}
			}
		} onCancel: {
			cancellation.cancel()
		}
	}

	/// Throwing form of `run(runMode:_:)`.
	public static func run<T: Sendable>(runMode: Utils.RunMode, _ work: @escaping @Sendable (TemporaryVMCancellation) throws -> T) async throws -> T {
		let result: Result<T, Error> = await run(runMode: runMode) { cancellation in
			Result { try work(cancellation) }
		}

		return try result.get()
	}
}

extension VMLocation {
	/// Stops a temporary VM started by `caked vmrun` and waits for its process to exit, killing it if
	/// it doesn't within `timeout` seconds. Best effort: it is about to be deleted anyway.
	func killTemporaryVirtualMachine(runMode: Utils.RunMode, timeout: TimeInterval = 15) {
		let pid = self.pidFile.isPIDRunning()

		guard pid.running else {
			return
		}

		try? self.stopVirtualMachine(force: true, runMode: runMode)

		guard let processID = pid.pid else {
			return
		}

		let deadline = Date().addingTimeInterval(timeout)

		while kill(processID, 0) == 0 && Date() < deadline {
			Thread.sleep(forTimeInterval: 0.2)
		}

		if kill(processID, 0) == 0 {
			Logger(self).warn("Temporary VM \(self.name) did not stop, killing it")
			kill(processID, SIGKILL)
		}
	}

	/// Waits for a temporary VM that was asked to shut down to actually exit before its files are moved.
	func waitTemporaryVirtualMachineExit(runMode: Utils.RunMode, cancellation: TemporaryVMCancellation?, timeout: TimeInterval = 60) throws {
		let deadline = Date().addingTimeInterval(timeout)

		while self.pidFile.isPIDRunning().running && Date() < deadline {
			try cancellation?.checkCancellation()
			Thread.sleep(forTimeInterval: 0.2)
		}

		if self.pidFile.isPIDRunning().running {
			self.killTemporaryVirtualMachine(runMode: runMode, timeout: 5)
		}
	}

	func destroyTemporaryVirtualMachine(runMode: Utils.RunMode) {
		self.killTemporaryVirtualMachine(runMode: runMode)

		if FileManager.default.fileExists(atPath: self.rootURL.path(percentEncoded: false)) {
			try? self.delete()
		}
	}
}
