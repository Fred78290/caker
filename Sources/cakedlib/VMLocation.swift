import Foundation
import GRPCLib
import NIO
import Shout
import Virtualization
import CakeAgentLib

public struct VMLocation: Hashable, Equatable, Sendable, Purgeable {
	public typealias StartCompletionHandler = (Result<VirtualMachine, any Error>) -> Void

	public enum Status: String {
		case running
		case paused
		case stopped
	}

	public var rootURL: URL
	public let template: Bool
	public var source: String {
		self.template ? "template" : "vm"
	}

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
		buildURL(cloudInitIso).absoluteURL
	}

	public var screenshotURL: URL {
		buildURL("screenshot.png").absoluteURL
	}

	public var agentURL: URL {
		return rootURL.resolvingSymlinksInPath().socketPath(name: "agent")
	}

	public var serviceURL: URL {
		return rootURL.resolvingSymlinksInPath().socketPath(name: "service")
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
			return FileManager.default.fileExists(atPath: diskURL.path)
		}

		return FileManager.default.fileExists(atPath: configURL.path) && FileManager.default.fileExists(atPath: diskURL.path) && FileManager.default.fileExists(atPath: nvramURL.path)
	}

	public func config() throws -> CakeConfig {
		try CakeConfig(location: self.rootURL)
	}

	public var status: Status {
		if isPIDRunning() {
			return .running
		} else if FileManager.default.fileExists(atPath: stateURL.path) {
			return .paused
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

	public var pidFile: URL {
		rootURL.appendingPathComponent("run.pid")
	}

	public func accessDate() throws -> Date {
		try self.rootURL.accessDate()
	}

	public func sizeBytes() throws -> Int {
		try self.diskSize()
	}

	public func allocatedSizeBytes() throws -> Int {
		try self.allocatedSize()
	}

	public func diskSize() throws -> Int {
		var sizeBytes = 0

		try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsSubdirectoryDescendants).forEach {
			sizeBytes += try $0.sizeBytes()
		}

		return sizeBytes
	}

	public func allocatedSize() throws -> Int {
		var allocatedSize = 0

		try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsSubdirectoryDescendants).forEach {
			allocatedSize += try $0.allocatedSizeBytes()
		}

		return allocatedSize
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

	@discardableResult
	public func validate() throws -> VMLocation {
		if !FileManager.default.fileExists(atPath: rootURL.path) {
			throw ServiceError("VM not found \(rootURL.lastPathComponent.deletingPathExtension)")
		}

		if self.inited == false {
			throw ServiceError("VM is not correctly inited, missing files: (\(configURL.lastPathComponent), \(diskURL.lastPathComponent) or \(nvramURL.lastPathComponent))")
		}

		return self
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

	public func deletePID() throws {
		try pidFile.delete()
	}

	public func writePID() throws {
		try pidFile.writePID()
	}

	public func readPID() -> Int32? {
		pidFile.readPID()
	}

	public func isPIDRunning() -> Bool {
		pidFile.isPIDRunning().0
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

	public func restartVirtualMachine(force: Bool, runMode: Utils.RunMode) throws {
		let config = try self.config()
		let home = try Home(runMode: runMode)
		let killVMRun: () -> Void = {
			let pid = pidFile.isPIDRunning()

			if pid.0 {
				if pid.1 == Home.cakedCommandName {
					if let pid = pid.2 {
						kill(pid, SIGINT)
						removePID()
						_ = StartHandler.startVM(location: self, config: config, waitIPTimeout: 30, startMode: .background, runMode: runMode, promise: nil)
					}
				}
			}
		}

		if self.status != .running {
			throw ServiceError("vm \(name) is not running")
		}

		if force || config.agent == false {
			killVMRun()
		} else if try self.agentURL.exists() {
			let client = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: 60, runMode: runMode)

			_ = try client.run(
				request: Caked_RunCommand.with {
					$0.command = "reboot"
					$0.vmname = self.name
				})
		} else {
			let reply = WaitIPHandler.waitIP(name: name, wait: 60, runMode: runMode)

			if reply.success {
				let ssh = try SSH(host: reply.ip)
				try ssh.authenticate(username: config.configuredUser, privateKey: home.sshPrivateKey.path, publicKey: home.sshPublicKey.path, passphrase: "")
				try ssh.execute("sudo reboot")
			} else {
				killVMRun()
			}
		}

	}

	public func suspendVirtualMachine(runMode: Utils.RunMode) throws {
		if self.status != .running {
			throw ServiceError("vm \(name) is not running")
		}

		let pid = pidFile.isPIDRunning()

		if pid.0 {
			if pid.1 == Home.cakedCommandName {
				if let pid = pid.2 {
					kill(pid, SIGUSR1)
					removePID()
				}
			}
		}
	}

	public func stopVirtualMachine(force: Bool, runMode: Utils.RunMode) throws {
		let killVMRun: () -> Void = {
			let pid = pidFile.isPIDRunning()

			if pid.0 {
				if pid.1 == Home.cakedCommandName {
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
			let reply = WaitIPHandler.waitIP(name: name, wait: 60, runMode: runMode)

			if reply.success {
				let ssh = try SSH(host: reply.ip)
				try ssh.authenticate(username: config.configuredUser, privateKey: home.sshPrivateKey.path, publicKey: home.sshPublicKey.path, passphrase: "")
				try ssh.execute("sudo shutdown now")
			} else {
				killVMRun()
			}
		}

		while self.status == .running {
			Thread.sleep(forTimeInterval: 1)
		}

		removePID()
	}

	public func startVirtualMachine(
		_ mode: VMRunServiceMode, on: EventLoop, config: CakeConfig, screenSize: CGSize, display: VMRunHandler.DisplayMode, vncPassword: String, vncPort: Int, internalCall: Bool, runMode: Utils.RunMode,
		completionHandler: StartCompletionHandler? = nil
	) throws -> (
		address: EventLoopFuture<String?>, vm: VirtualMachine
	) {
		let vm = try VirtualMachine(location: self, config: config, screenSize: screenSize, runMode: runMode)

		let runningIP = try vm.runInBackground(mode, on: on, internalCall: internalCall) {
			if case .success = $0 {
				if display == .vnc {
					DispatchQueue.main.async {
						let vncURL = try? vm.startVncServer(vncPassword: vncPassword, port: vncPort)

						Logger(self).info("VNC server started at \(vncURL?.absoluteString ?? "<failed to start VNC server>")")
					}
				}
			}

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
		let clientID = config.dhcpClientID ?? macAddress
		var leases: DHCPLeaseProvider
		var count = 0
		let useNat = config.networks.first { $0.network == "nat" } != nil

		guard macAddress.isEmpty == false && clientID.isEmpty == false else {
			throw ShellError(terminationStatus: -1, error: "Unable to get MAC address for VM \(self.name)", message: "Any mac address or client ID is not configured")
		}

		repeat {
			if let startedProcess = startedProcess, startedProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Caked vmrun process is not running", message: "")
			}

			// Try also arp if dhcp is disabled
			if useNat == false || count & 1 == 1 {
				leases = try ARPParser()

				if let runningIP = leases[macAddress] {
					return runningIP
				}
			} else {
				leases = try DHCPLeaseParser()

				if let runningIP = leases[clientID] {
					return runningIP
				}
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: "Unable to get IP for VM \(self.name)", message: "Timeout")
	}

	func vmInfos(wait: Int = 5, runMode: Utils.RunMode, _ completion: @escaping (Result<Caked_InfoReply, Error>) -> Void) {
		do {
			let conn = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: self.agentURL, timeout: wait, runMode: runMode, retries: .none)
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
				throw ShellError(terminationStatus: -1, error: "Caked vmrun process is not running", message: "")
			}

			if let infos = try? conn.info().wait() {
				let infos = infos

				if case .success(let infos) = infos {
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
		if config.source == .iso && config.firstLaunch {
			return on.submit {
				try? self.waitIPWithLease(wait: wait, runMode: runMode)
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
		Logger(self).info("Installing agent on \(self.name)")

		let imageSource = config.source
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let caCert = try String(contentsOf: certificates.caCertURL, encoding: .ascii)
		let serverKey: String = try String(contentsOf: certificates.serverKeyURL, encoding: .ascii)
		let serverPem = try String(contentsOf: certificates.serverCertURL, encoding: .ascii)
		let sshPublicKeys = try getPublicSSHKeys(config: config, runMode: runMode).joined(separator: "\n")
		let ssh = try createSSH(host: runningIP, timeout: timeout)
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

			if test "${OSDISTRO}" = "darwin"
			then
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
			UPDATE=0

			mkdir -p /usr/local/bin ${SSHDIR}

			if test -f /usr/local/bin/cakeagent
			then
				if test -n "$(/usr/local/bin/cakeagent version|grep \(CAKEAGENT_SNAPSHOT))"
				then
					echo "CakeAgent already installed, skipping"
					exit 0
				else
					echo "CakeAgent already installed, updating"
					/usr/local/bin/cakeagent service stop
					UPDATE=1
				fi
			fi

			if test ! -f /tmp/cakeagent
			then
				echo "Downloading CakeAgent from ${AGENT_URL}"
				AGENT_URL="https://github.com/Fred78290/cakeagent/releases/download/SNAPSHOT-\(CAKEAGENT_SNAPSHOT)/cakeagent-${OSDISTRO}-${ARCH}"
				
				if test -n "$(command -v curl)"; then
					curl -L "${AGENT_URL}" -o /tmp/cakeagent
				elif test -n "$(command -v wget)"
				then
					wget "${AGENT_URL}" -O /tmp/cakeagent
				else
					echo "No curl or wget found, cannot download CakeAgent"
					exit 1
				fi
			fi

			if test ! -f /tmp/cakeagent
			then
				echo "Failed to download CakeAgent, exiting"
				exit 1
			fi

			echo "Install CakeAgent, setting permissions"
			mv /tmp/cakeagent /usr/local/bin/cakeagent

			touch ${SSHDIR}/authorized_keys

			if test -z "$(grep '\(sshPublicKeys)' ${SSHDIR}/authorized_keys)"
			then
				echo "\(sshPublicKeys)" >> "${SSHDIR}/authorized_keys"
				chown -R \(config.configuredUser) "${SSHDIR}"
				chmod 600 "${SSHDIR}/authorized_keys"
			fi

			if test ! -f "${CA}"
			then
			echo "Creating CA certificate file at ${CA}"
			cat <<'EOF' > "${CA}"
			\(caCert)
			EOF
			fi

			if test ! -f "${SERVER}"
			then
			echo "Creating server certificate file at ${SERVER}"
			cat <<'EOF' > "${SERVER}"
			\(serverPem)
			EOF
			fi

			if test ! -f "${KEY}"
			then
			echo "Creating server key file at ${KEY}"
			cat <<'EOF' > "${KEY}"
			\(serverKey)
			EOF
			fi

			chmod -R 600 "${CERTS}"

			if test "${OSDISTRO}" = "darwin"
			then
				chown root:wheel /usr/local/bin/cakeagent
				chown -R root:wheel "${CERTS}"
			else
				chown root:adm /usr/local/bin/cakeagent
				chown -R root:adm "${CERTS}"
				mkdir -p /mnt/shared
				chmod 777 /mnt/shared
			fi

			chmod 755 /usr/local/bin/cakeagent

			if [ $UPDATE -eq 1 ]
			then
				/usr/local/bin/cakeagent service start
			else
				/usr/local/bin/cakeagent service install \\
					--listen="vsock://any:5000" \\
					--ca-cert="${CA}" \\
					--tls-cert="${SERVER}" \\
					--tls-key="${KEY}" \(config.linuxMounts)
			fi

			if test "${OSDISTRO}" = "linux"
			then
				mount /mnt/shared 2>/dev/null || true
			fi

			"""

		try install_agent.write(to: tempFileURL, atomically: true, encoding: .utf8)

		let agentBinary = try await Utilities.cakeagentBinary(os: config.os, runMode: runMode)

		#if arch(arm64)
			if imageSource == .ipsw {
				try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
			} else if let sshPrivateKeyPath = config.sshPrivateKeyPath {
				try ssh.authenticate(username: config.configuredUser, privateKey: URL(fileURLWithPath: sshPrivateKeyPath.expandingTildeInPath, relativeTo: self.configURL).absoluteURL.path, passphrase: config.sshPrivateKeyPassphrase)
			} else {
				try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
			}
		#else
			if let sshPrivateKeyPath = config.sshPrivateKeyPath {
				try ssh.authenticate(username: config.configuredUser, privateKey: URL(fileURLWithPath: sshPrivateKeyPath.expandingTildeInPath, relativeTo: self.configURL).absoluteURL.path, passphrase: config.sshPrivateKeyPassphrase)
			} else {
				try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword ?? config.configuredUser)
			}
		#endif

		_ = try ssh.sendFile(localURL: agentBinary, remotePath: "/tmp/cakeagent", permissions: .init(rawValue: 0o755))
		_ = try ssh.sendFile(localURL: tempFileURL, remotePath: "/tmp/install-agent.sh", permissions: .init(rawValue: 0o755))

		try tempFileURL.delete()
		let cmd = "echo \(config.configuredPassword ?? config.configuredUser)|sudo -S sh -c '/tmp/install-agent.sh 2>&1 | tee /tmp/install-agent.log'"
		let result = try ssh.capture(cmd)

		if result.status == 0 {
			Logger(self).info("Agent installed on \(self.name), exit code: \(result.status)")
			#if DEBUG
				print(result.status)
			#endif
		} else {
			Logger(self).error("Agent installation failed on \(self.name), exit code: \(result.status)\n\(result.output)")

			throw ServiceError("Agent installation failed on \(self.name)")
		}

		return true
	}

}
