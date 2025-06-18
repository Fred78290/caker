import Foundation
import GRPCLib
import NIO
import Shout
import Virtualization

public struct VMLocation {
	public typealias StartCompletionHandler = (Result<VirtualMachine, any Error>) -> Void

	public enum Status: String {
		case running
		case suspended
		case stopped
	}

	public var rootURL: URL
	public let template: Bool

	public init(rootURL: URL, template: Bool = false) {
		self.rootURL = rootURL
		self.template = template
	}

	private func buildURL(_ path: String) -> URL {
		return rootURL.appendingPathComponent(path).resolvingSymlinksInPath().absoluteURL
	}

	public var configURL: URL {
		buildURL("config.json").absoluteURL
	}

	public var cakeURL: URL {
		buildURL("cake.json").absoluteURL
	}

	public var diskURL: URL {
		buildURL("disk.img").absoluteURL
	}

	public var nvramURL: URL {
		buildURL("nvram.bin").absoluteURL
	}

	public var stateURL: URL {
		buildURL("state.vzvmsave").absoluteURL
	}

	public var manifestURL: URL {
		buildURL("manifest.json").absoluteURL
	}

	public var cdromISO: URL {
		buildURL("cloud-init.iso").absoluteURL
	}

	public var agentURL: URL {
		return rootURL.resolvingSymlinksInPath().socketPath(name: "agent")
	}

	public var mountServiceURL: URL {
		return rootURL.resolvingSymlinksInPath().socketPath(name: "mount")
	}

	public var name: String {
		rootURL.deletingPathExtension().lastPathComponent
	}

	public var url: URL {
		rootURL
	}

	public var inited: Bool {
		if self.template {
			return FileManager.default.fileExists(atPath: diskURL.path)
		}

		return FileManager.default.fileExists(atPath: configURL.path) && FileManager.default.fileExists(atPath: diskURL.path) && FileManager.default.fileExists(atPath: nvramURL.path)
	}

	public func config() throws -> CakeConfig {
		try CakeConfig(location: self.rootURL)
	}

	public func tartRunning() -> Bool {
		guard let lock = try? PIDLock(lockURL: configURL) else {
			return false
		}

		guard let pid = try? lock.pid() else {
			return false
		}

		return pid != 0
	}

	public var status: Status {
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

	public var macAddress: VZMACAddress? {
		if let config = try? CakeConfig(location: rootURL) {
			return config.macAddress
		}

		return nil
	}

	public func diskSize() throws -> Int {
		try self.diskURL.sizeBytes()
	}

	public func allocatedSize() throws -> Int {
		if self.template {
			return try diskSize()
		}

		return try diskSize() + nvramURL.sizeBytes() + configURL.sizeBytes()
	}

	public func lock() -> Bool {
		let fd = open(configURL.path, O_RDWR)

		if fd != -1 {
			close(fd)
		}

		return fd != -1
	}

	@discardableResult
	public func templateTo(_ target: VMLocation) throws -> VMLocation {
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
		try FileManager.default.copyItem(at: self.diskURL, to: target.diskURL)
		try FileManager.default.copyItem(at: self.nvramURL, to: target.nvramURL)
		try FileManager.default.copyItem(at: self.configURL, to: target.configURL)
		try FileManager.default.copyItem(at: self.cakeURL, to: target.cakeURL)
		if FileManager.default.fileExists(atPath: self.cdromISO.path) {
			try FileManager.default.copyItem(at: self.cdromISO, to: target.cdromISO)
		}

		return target
	}

	@discardableResult
	public func duplicateTemporary(runMode: Utils.RunMode) throws -> VMLocation {
		return try self.copyTo(try Self.tempDirectory(runMode: runMode))
	}

	public static func tempDirectory(runMode: Utils.RunMode) throws -> VMLocation {
		let tmpDir = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

		return VMLocation(rootURL: tmpDir, template: false)
	}

	public func validatate(userFriendlyName: String) throws {
		if !FileManager.default.fileExists(atPath: rootURL.path) {
			throw ServiceError("VM not found \(userFriendlyName)")
		}

		if self.inited == false {
			throw ServiceError("VM is not correctly inited, missing files: (\(configURL.lastPathComponent), \(diskURL.lastPathComponent) or \(nvramURL.lastPathComponent))")
		}
	}

	public func expandDisk(_ sizeGB: UInt16) throws {
		let wantedFileSize = UInt64(sizeGB) * 1000 * 1000 * 1000

		if FileManager.default.fileExists(atPath: diskURL.path) {
			try Shell.bash(to: "hdiutil", arguments: ["resize", "-sectors", String("\(wantedFileSize / 512)"), diskURL.path])
		} else {
			FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)

			let diskFileHandle = try FileHandle.init(forWritingTo: diskURL)
			let curFileSize = try diskFileHandle.seekToEnd()

			defer {
				try? diskFileHandle.close()
			}

			if wantedFileSize < curFileSize {
				let curFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(curFileSize))
				let wantedFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(wantedFileSize))
				throw ServiceError("the new file size \(wantedFileSizeHuman) is lesser than the current disk size of \(curFileSizeHuman)")
			} else if wantedFileSize > curFileSize {
				try diskFileHandle.truncate(atOffset: wantedFileSize)
			}
		}
	}

	public func resizeDisk(_ sizeGB: UInt16) throws {
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

	public func pidFile() -> URL {
		rootURL.appendingPathComponent("run.pid")
	}

	public func deletePID() throws {
		try pidFile().delete()
	}

	public func writePID() throws {
		try pidFile().writePID()
	}

	public func readPID() -> Int32? {
		pidFile().readPID()
	}

	public func isPIDRunning() -> Bool {
		pidFile().isPIDRunning().0
	}

	public func removePID() {
		let pidFile = rootURL.appendingPathComponent("run.pid")

		if FileManager.default.fileExists(atPath: pidFile.path) {
			try? FileManager.default.removeItem(at: pidFile)
		}
	}

	public func delete() throws {
		try FileManager.default.removeItem(at: rootURL)
	}

	public func stopVirtualMachine(force: Bool, runMode: Utils.RunMode) throws {
		let killVMRun: () -> Void = {
			let pid = pidFile().isPIDRunning()
			
			if pid.0 {
				if pid.1 == "caked" {
					if let pid = pid.2 {
						kill(pid, SIGINT)
						removePID()
					}
				}
			}
		}

		let config = try self.config()
		let home = try Home(runMode: runMode)

		if self.status != .running {
			throw ServiceError("vm \(name) is not running")
		}

		if force || config.agent == false {
			killVMRun()
		} else if try self.agentURL.exists() {
			let client = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: 60, runMode: runMode)

			try client.shutdown().log()
		} else {
			if let ip: String = try? WaitIPHandler.waitIP(name: name, wait: 60, runMode: runMode) {
				let ssh = try SSH(host: ip)
				try ssh.authenticate(username: config.configuredUser, privateKey: home.sshPrivateKey.path, publicKey: home.sshPublicKey.path, passphrase: "")
				try ssh.execute("sudo shutdown now")
			} else {
				killVMRun()
			}
		}

		while self.status == .running {
			Thread.sleep(forTimeInterval: 1)
		}
	}

	public func startVirtualMachine(on: EventLoop, config: CakeConfig, internalCall: Bool, runMode: Utils.RunMode, promise: EventLoopPromise<String?>? = nil, completionHandler: StartCompletionHandler? = nil) throws -> (EventLoopFuture<String?>, VirtualMachine) {
		let vm = try VirtualMachine(vmLocation: self, config: config, runMode: runMode)

		let runningIP = try vm.runInBackground(on: on, internalCall: internalCall) {
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

	public func waitIPWithLease(wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let config = try self.config()
		let start: Date = Date.now
		let macAddress = config.macAddress?.string ?? ""
		var leases: DHCPLeaseProvider
		var count = 0
		let useNat = config.networks.first { $0.network == "nat" } != nil

		repeat {
			if let startedProcess = startedProcess, startedProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Caked vmrun process is not running", message: "")
			}

			// Try also arp if dhcp is disabled
			if useNat == false || count & 1 == 1 {
				leases = try ARPParser()
			} else {
				leases = try DHCPLeaseParser()
			}

			if let runningIP = leases[macAddress] {
				return runningIP
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: "Unable to get IP for VM \(self.name)", message: "")
	}

	public func waitIPWithAgent(wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let conn = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: 5, runMode: runMode, retries: .none)
		let start: Date = Date.now
		var count = 0

		repeat {
			if let startedProcess = startedProcess, startedProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Caked vmrun process is not running", message: "")
			}

			if let infos = try? conn.info().wait() {
				let infos = infos

				if case let .success(infos) = infos {
					if infos.ipaddresses.count > 0, let runningIP = infos.ipaddresses.first {
						return runningIP
					}
				}
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: "Unable to get IP for VM \(self.name)", message: "")
	}

	public func waitIP(config: CakeConfig, wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		if startedProcess == nil && self.status != .running {
			throw ServiceError("VM \(name) is not running")
		}

		if config.agent {
			return try waitIPWithAgent(wait: wait, runMode: runMode, startedProcess: startedProcess)
		} else {
			return try waitIPWithLease(wait: wait, runMode: runMode, startedProcess: startedProcess)
		}
	}

	public func waitIP(wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		return try self.waitIP(config: self.config(), wait: wait, runMode: runMode, startedProcess: startedProcess)
	}

	public func waitIP(on: EventLoop, config: CakeConfig, wait: Int, runMode: Utils.RunMode) throws -> EventLoopFuture<String?> {
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
				try? self.waitIPWithLease(wait: wait, runMode: runMode)
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

	public func installAgent(config: CakeConfig, runningIP: String, runMode: Utils.RunMode) throws -> Bool {
		Logger(self).info("Installing agent on \(self.name)")

		let home: Home = try Home(runMode: runMode)
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let caCert = try Data(contentsOf: certificates.caCertURL).base64EncodedString(options: .lineLength64Characters)
		let serverKey: String = try Data(contentsOf: certificates.serverKeyURL).base64EncodedString(options: .lineLength64Characters)
		let serverPem = try Data(contentsOf: certificates.serverCertURL).base64EncodedString(options: .lineLength64Characters)
		let sharedPublicKey = try home.getSharedPublicKey()
		let ssh = try createSSH(host: runningIP, timeout: 120)
		let tempFileURL = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent("install-agent.sh")
		let install_agent = """
			#!/bin/sh
			set -xe

			case $(uname -m) in
				x86_64)
					ARCH=amd64
					;;
				aarch64|arm64)
					ARCH=arm64
					;;
			esac

			case $(uname -s) in
				Darwin)
					OSDISTRO=darwin
					;;
				*)
					OSDISTRO=linux
					;;
			esac

			AGENT_URL="https://github.com/Fred78290/cakeagent/releases/download/SNAPSHOT-\(CAKEAGENT_SNAPSHOT)/cakeagent-${OSDISTRO}-${ARCH}"

			if [ "${OSDISTRO}" = "darwin" ]; then
				CERTS="/Library/Application Support/CakeAgent/certs"
				SSHDIR="/Users/\(config.configuredUser)/.ssh"
			else
				CERTS="/etc/cakeagent/ssl"
				SSHDIR="/home/\(config.configuredUser)/.ssh"
			fi

			mkdir -p "${CERTS}"

			CA="${CERTS}/ca.pem"
			SERVER="${CERTS}/server.pem"
			KEY="${CERTS}/server.key"

			mkdir -p /usr/local/bin ${SSHDIR}

			curl -L $AGENT_URL -o /usr/local/bin/cakeagent

			echo "\(sharedPublicKey)" > "${SSHDIR}/authorized_keys"
			chown -R \(config.configuredUser) "${SSHDIR}"
			chmod 600 "${SSHDIR}/authorized_keys"

			cat <<EOF | base64 -d > "${CA}"
			\(caCert)
			EOF

			cat <<EOF | base64 -d > "${SERVER}"
			\(serverPem)
			EOF

			cat <<EOF | base64 -d > "${KEY}"
			\(serverKey)
			EOF

			chmod -R 600 "${CERTS}"

			if [ "${OSDISTRO}" = "darwin" ]; then
				chown root:wheel /usr/local/bin/cakeagent
				chown -R root:wheel "${CERTS}"
			else
				chown root:adm /usr/local/bin/cakeagent
				chown -R root:adm "${CERTS}"
				mkdir -p /mnt/shared
				chmod 777 /mnt/shared
				mount /mnt/shared
			fi

			chmod 755 /usr/local/bin/cakeagent

			/usr/local/bin/cakeagent --install \\
				--listen="vsock://any:5000" \\
				--ca-cert="${CA}" \\
				--tls-cert="${SERVER}" \\
				--tls-key="${KEY}" \(config.linuxMounts)

			"""

		try install_agent.write(to: tempFileURL, atomically: true, encoding: .utf8)

		if let sshPrivateKeyPath = config.sshPrivateKeyPath {
			try ssh.authenticate(username: config.configuredUser, privateKey: sshPrivateKeyPath.expandingTildeInPath)
		} else {
			try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
		}

		_ = try ssh.sendFile(localURL: tempFileURL, remotePath: "/tmp/install-agent.sh", permissions: .init(rawValue: 0o755))

		try tempFileURL.delete()
		let result = try ssh.capture("sudo sh -c '/tmp/install-agent.sh 2>&1 | tee /tmp/install-agent.log'")

		if result.status == 0 {
			Logger(self).info("Agent installed on \(self.name), exit code: \(result.status)")
		} else {
			Logger(self).error("Agent installation failed on \(self.name), exit code: \(result.status)\n\(result.output)")
		}

		return result.status == 0
	}

}
