import Foundation
import Virtualization
import GRPCLib
import NIO
import Shout

struct VMLocation {
	public typealias StartCompletionHandler = (Result<VirtualMachine, any Error>) -> Void

	enum Status: String {
		case running
		case suspended
		case stopped
	}

	var rootURL: URL
	let template: Bool

	var configURL: URL {
		rootURL.appendingPathComponent("config.json")
	}

	var cakeURL: URL {
		rootURL.appendingPathComponent("cake.json")
	}

	var diskURL: URL {
		rootURL.appendingPathComponent("disk.img")
	}

	var nvramURL: URL {
		rootURL.appendingPathComponent("nvram.bin")
	}

	var stateURL: URL {
		rootURL.appendingPathComponent("state.vzvmsave")
	}

	var manifestURL: URL {
		rootURL.appendingPathComponent("manifest.json")
	}

	var cdromISO: URL {
		rootURL.appendingPathComponent("cloud-init.iso")
	}

	var agentURL: URL {
		let agentURL = rootURL.appendingPathComponent("agent.sock")

		return URL(string: "unix://\(agentURL.path)")!
	}

	var name: String {
		rootURL.lastPathComponent
	}

	var url: URL {
		rootURL
	}

	var inited: Bool {
		if self.template {
			return FileManager.default.fileExists(atPath: diskURL.path)
		}

		return FileManager.default.fileExists(atPath: configURL.path) &&
			FileManager.default.fileExists(atPath: diskURL.path) &&
			FileManager.default.fileExists(atPath: nvramURL.path)
	}

	func config() throws -> CakeConfig {
		try CakeConfig(location: self.rootURL)
	}

	func tartRunning() -> Bool {
		guard let lock = try? PIDLock(lockURL: configURL) else {
			return false
		}

		guard let pid = try? lock.pid() else {
			return false
		}

		return pid != 0
	}

	var status: Status {
		get {
			if isPIDRunning() {
				return .running
			} else if tartRunning() {
				return .running
			} else if FileManager.default.fileExists(atPath: stateURL.path) {
				return .suspended
			} else {
				return .stopped
			}
		}
	}

	var macAddress: VZMACAddress? {
		if let config = try? CakeConfig(location: rootURL) {
			return config.macAddress
		}

		return nil
	}

	func diskSize() throws -> Int {
		try self.diskURL.sizeBytes()
	}

	func allocatedSize() throws -> Int {
		if self.template {
			return try diskSize()
		}

		return try diskSize() + nvramURL.sizeBytes() + configURL.sizeBytes()
	}

	func lock() -> Bool {
		let fd = open(configURL.path, O_RDWR) 

		if fd != -1 {
			close(fd)
		}

		return fd != -1
	}

	func copyTo(_ target: VMLocation) throws -> VMLocation{
		try FileManager.default.copyItem(at: self.diskURL, to: target.diskURL)
		try FileManager.default.copyItem(at: self.nvramURL, to: target.nvramURL)
		try FileManager.default.copyItem(at: self.configURL, to: target.configURL)
		try FileManager.default.copyItem(at: self.cakeURL, to: target.cakeURL)
		if FileManager.default.fileExists(atPath: self.cdromISO.path) {
			try FileManager.default.copyItem(at: self.cdromISO, to: target.cdromISO)
		}

		return target
	}

	func duplicateTemporary() throws -> VMLocation {
		return try self.copyTo(try Self.tempDirectory())
	}

	static func tempDirectory() throws -> VMLocation {
		let tmpDir = try Home(asSystem: runAsSystem).temporaryDir.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

		return VMLocation(rootURL: tmpDir, template: false)
	}

	func validatate(userFriendlyName: String) throws {
		if !FileManager.default.fileExists(atPath: rootURL.path) {
			throw ServiceError("VM not found \(userFriendlyName)")
		}

		if self.inited == false {
			throw ServiceError("VM is not correctly inited, missing files: (\(configURL.lastPathComponent), \(diskURL.lastPathComponent) or \(nvramURL.lastPathComponent))")
		}
	}

	func expandDiskTo(_ sizeGB: UInt16) throws {
		let wantedFileSize = UInt64(sizeGB) * 1000 * 1000 * 1000

		if !FileManager.default.fileExists(atPath: diskURL.path) {
			FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)
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
			let curFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(curFileSize))
			let wantedFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(wantedFileSize))
			throw ServiceError("the new file size \(wantedFileSizeHuman) is lesser than the current disk size of \(curFileSizeHuman)")
		} else if wantedFileSize > curFileSize {
			try diskFileHandle.truncate(atOffset: wantedFileSize)
		}
	}

	func writePID() throws {
		let pid = getpid()
		let pidFile = rootURL.appendingPathComponent("run.pid")

		try "\(pid)".write(to: pidFile, atomically: true, encoding: .ascii)
	}

	func readPID() -> Int32? {
		let pidFile = rootURL.appendingPathComponent("run.pid")

		if FileManager.default.fileExists(atPath: pidFile.path()) == false {
			return nil
		}

		guard let pidString = try? String(contentsOf: pidFile, encoding: .ascii) else {
			return nil
		}

		guard let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			return nil
		}

		return pid
	}

	func isPIDRunning() -> Bool {
		if let pid = readPID() {
			return kill(pid, 0) == 0
		}

		return false
	}

	func removePID() {
		let pidFile = rootURL.appendingPathComponent("run.pid")

		if FileManager.default.fileExists(atPath: pidFile.path) {
			try? FileManager.default.removeItem(at: pidFile)
		}
	}

	func delete() throws {
		try FileManager.default.removeItem(at: rootURL)
	}

	func stopVirtualMachine(force: Bool, asSystem: Bool) throws {
		let killVMRun: () -> Void = {
			if let pid = readPID() {
				kill(pid, SIGINT)
				removePID()
			}
		}

		let config = try self.config()
		let home = try Home(asSystem: asSystem)

		if self.status != .running {
			throw ServiceError("vm \(name) is not running")
		}

		if force || config.useCloudInit == false {
			killVMRun()
		} else if try self.agentURL.exists() {
			let certLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem))).createCertificats()
			let conn = CakeAgentConnection(eventLoop: Root.group.next(),
			                               listeningAddress: self.agentURL,
			                               caCert: certLocation.caCertURL.path(),
			                               tlsCert: certLocation.serverCertURL.path(),
			                               tlsKey: certLocation.serverKeyURL.path())

			try conn.execute(request: Caked_ExecuteRequest.with {
				$0.command = "shutdown -h now"
			}).log()
		} else {
			if let ip: String = try? WaitIPHandler.waitIP(name: name, wait: 60, asSystem: asSystem) {
				let ssh = try SSH(host: ip)
				try ssh.authenticate(username: config.configuredUser, privateKey: home.sshPrivateKey.path(), publicKey: home.sshPublicKey.path(), passphrase: "")
				try ssh.execute("sudo shutdown now")
			} else {
				killVMRun()
			}
		}

		while self.status == .running {
			Thread.sleep(forTimeInterval: 1)
		}
	}

	func startVirtualMachine(on: EventLoop, config: CakeConfig, internalCall: Bool, asSystem: Bool, promise: EventLoopPromise<String?>? = nil, completionHandler: StartCompletionHandler? = nil) throws -> (EventLoopFuture<String?>, VirtualMachine) {
		let vm = try VirtualMachine(vmLocation: self, config: config)

		let runningIP = try vm.runInBackground(on: on, internalCall: internalCall, asSystem: asSystem) {
			if let handler = completionHandler {
				switch $0 {
				case .success:
					handler(.success(vm))
				case .failure(let error):
					handler(.failure(error))
				}
			}
		}

		try self.writePID()

		return (runningIP, vm)
	}
}
