//
//  helper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/11/2026.
//
#if USE_AUTHORIZATION_HELPER
	import CakeAgentLib
	import CakedLib
	import Darwin
	import Foundation
	import Logging
	import GRPCLib
	import Security

	final class AuthorizationHelperTool: NSObject, NSXPCListenerDelegate, AuthorizationHelperProtocol {
		private let listener: NSXPCListener
		private let logger = Logger("AuthorizationHelperTool")

		override init() {
			// Set up our XPC listener to handle requests on our Mach service.
			listener = NSXPCListener(machServiceName: AuthorizationHelperCommon.kAuthorizationHelperToolMachServiceName)
			super.init()
			listener.delegate = self
		}

		func stop() {
			listener.invalidate()
		}

		/// Starts processing requests and runs the run loop forever.
		func run() -> Never {
			listener.resume()
			RunLoop.current.run()
			fatalError("the run loop should never return")
		}

		// MARK: NSXPCListenerDelegate

		/// Called by our XPC listener when a new connection comes in.  We configure the connection with
		/// our protocol and ourselves as the main object.
		func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
			// Only the app's own executables, signed by the same team as the helper, may talk to it. An ad-hoc signed build
			// (development) has no team to compare with: it is accepted, as the authorization rights still apply.
			if let requirement = Self.clientRequirement {
				newConnection.setCodeSigningRequirement(requirement)
			} else {
				self.logger.warn("Helper is not signed by a team: XPC clients are not verified")
			}

			newConnection.exportedInterface = NSXPCInterface(with: AuthorizationHelperProtocol.self)
			newConnection.exportedObject = self
			newConnection.resume()

			return true
		}

		/// The code signing requirement of a client: one of the app's executables, signed by the helper's own team.
		private static let clientRequirement: String? = {
			var code: SecCode?
			var staticCode: SecStaticCode?
			var information: CFDictionary?

			guard SecCodeCopySelf([], &code) == errSecSuccess, let code, SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
				SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
				let team = (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
			else {
				return nil
			}

			let identifiers = ["com.aldunelabs.caker", "com.aldunelabs.caker.caked", "com.aldunelabs.caker.cakectl"]
				.map { "identifier \"\($0)\"" }
				.joined(separator: " or ")

			return "(\(identifiers)) and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
		}()

		// MARK: Helpers

		/// Checks that the client denoted by `authData` is allowed to run the specified command.
		/// `authData` is expected to be a Data with an AuthorizationExternalForm embedded inside.
		private func checkAuthorization(_ authData: Data, command: Selector) -> NSError? {
			// First check that authData looks reasonable.
			guard authData.count == MemoryLayout<AuthorizationExternalForm>.size,
				let rightName = AuthorizationHelperCommon.authorizationRight(for: command)
			else {
				return NSError(domain: NSOSStatusErrorDomain, code: Int(paramErr))
			}

			// Create an authorization ref from the external form data contained within.
			var authRef: AuthorizationRef?
			var err = authData.withUnsafeBytes { buffer in
				AuthorizationCreateFromExternalForm(buffer.baseAddress!.assumingMemoryBound(to: AuthorizationExternalForm.self), &authRef)
			}
			defer {
				if let authRef {
					let junk = AuthorizationFree(authRef, [])
					assert(junk == errAuthorizationSuccess)
				}
			}

			// Authorize the right associated with the command.
			if err == errAuthorizationSuccess, let authRef {
				err = rightName.withCString { name in
					var oneRight = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
					return withUnsafeMutablePointer(to: &oneRight) { items in
						var rights = AuthorizationRights(count: 1, items: items)
						return AuthorizationCopyRights(authRef, &rights, nil, [.extendRights], nil)
					}
				}
			}

			return err == errAuthorizationSuccess ? nil : NSError(domain: NSOSStatusErrorDomain, code: Int(err))
		}

		// MARK: Request validation

		/// The user on the other end of the XPC connection, as seen by the kernel (not as claimed by the request).
		private struct Caller {
			let uid: uid_t
			let gid: gid_t

			static func current() -> Caller? {
				guard let connection = NSXPCConnection.current() else {
					return nil
				}

				return Caller(uid: connection.effectiveUserIdentifier, gid: connection.effectiveGroupIdentifier)
			}
		}

		private static let queue = DispatchQueue(label: "com.aldunelabs.caker.authorization.work", attributes: .concurrent)
		private static let logPath = "/var/log/com.aldunelabs.caker.authorization.log"
		private static let installedPathsFile = "/etc/paths.d/com.aldunelabs.caker"

		/// Runs `work` off the XPC thread and sends exactly one reply.
		private func perform(_ operation: String, authorization authData: Data, command: Selector, reply: @escaping @Sendable (AuthorizationHelperReply) -> Void, work: @escaping @Sendable (Caller) throws -> String) {
			self.logger.debug("Performing operation \(operation)")

			func doReply(_ result: AuthorizationHelperReply) {
				#if DEBUG
					self.logger.debug(Format.text.renderSingle(result))
				#endif

				reply(result)
			}

			if let error = checkAuthorization(authData, command: command) {
				doReply(AuthorizationHelperReply(operation: operation, success: false, reason: error.reason))
				return
			}

			guard let caller = Caller.current() else {
				doReply(AuthorizationHelperReply(operation: operation, success: false, reason: "Unable to identify the caller"))
				return
			}

			Self.queue.async {
				do {
					reply(AuthorizationHelperReply(operation: operation, success: true, reason: try work(caller)))
				} catch {
					reply(AuthorizationHelperReply(operation: operation, success: false, reason: error.reason))
				}
			}
		}

		/// `cakeHome` as sent by the client (a path or a file URL) when it is an existing directory owned by the caller.
		/// The helper is root: it must never be pointed at a directory the caller doesn't own.
		private static func validatedHome(_ cakeHome: String, caller: Caller) throws -> URL {
			let url = cakeHome.hasPrefix("file:") ? URL(string: cakeHome) : URL(fileURLWithPath: cakeHome)

			guard let url, url.isFileURL, url.path.hasPrefix("/") else {
				throw ServiceError("Invalid cake home '\(cakeHome)'")
			}

			let resolved = url.resolvingSymlinksInPath().standardizedFileURL
			let attributes = try FileManager.default.attributesOfItem(atPath: resolved.path) as NSDictionary

			guard attributes.fileType() == FileAttributeType.typeDirectory.rawValue, attributes.fileOwnerAccountID()?.uint32Value == caller.uid else {
				throw ServiceError("Cake home \(resolved.path) is not a directory owned by the calling user \(caller.uid)")
			}

			return resolved
		}

		#if USE_DHCP_SERVER
			/// A network name is a single path component and can't be taken for an option.
			private static func validateNetworkName(_ name: String) throws {
				guard name.isEmpty == false, name.count <= 128, name.first != "-", name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) }), name != ".", name != ".." else {
					throw ServiceError("Invalid network name '\(name)'")
				}
			}
		#endif

		/// The log level a client asks the root child to use: one of `Logging.Logger.Level`'s raw values, nothing else, since it ends up
		/// in the arguments of a process running as root.
		private static func validatedLogLevel(_ level: String) throws -> String {
			guard ["trace", "debug", "info", "notice", "warning", "error", "critical"].contains(level) else {
				throw ServiceError("Invalid log level '\(level)'")
			}

			return level
		}

		private static func validateIPv4(_ address: String) throws {
			var storage = in_addr()

			guard inet_pton(AF_INET, address, &storage) == 1 else {
				throw ServiceError("Invalid IPv4 address '\(address)'")
			}
		}

		#if BECOME_PARANOID
			/// Whether `url` is owned by root and can't be modified by anybody else.
			/// True when this helper executable isn't root-owned and protected, which is never the case once it is installed with the app.
			private func isDevelopmentHelper() -> Bool {
				guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
					return false
				}

				return isRootOwnedAndProtected(executable) == false
			}
		#endif

		#if BECOME_PARANOID
			private func isRootOwnedAndProtected(_ url: URL, alsoOwnedBy uid: uid_t? = nil) -> Bool {
				guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) as NSDictionary else {
					return false
				}

				let owner = attributes.fileOwnerAccountID()?.uint32Value

				return (owner == 0 || (uid != nil && owner == uid)) && (attributes.filePosixPermissions() & Int(S_IWGRP | S_IWOTH)) == 0
			}
		#endif

		/// The `caked` shipped with the app the helper belongs to. It runs as root, so it must be root-owned and not writable by others.
		///
		/// A `caked` owned by the caller (`alsoOwnedBy`) is accepted only when the helper's own executable isn't root-protected either, i.e. a development build run from Xcode's
		/// products, where a freshly built binary belongs to the developer. Whoever can replace such a `caked` can already replace the helper, so nothing more is exposed.
		/// An installed helper is root-owned: it only runs a root-owned `caked`.
		private func trustedCaked(in appURL: URL? = nil, alsoOwnedBy uid: uid_t? = nil) throws -> URL {
			var candidates: [URL] = []

			self.logger.debug("Finding trusted caked")

			if let appURL {
				candidates.append(appURL.appendingPathComponent("Contents/PlugIns/caked.app/Contents/MacOS/caked"))
			} else {
				var directory = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath().deletingLastPathComponent()

				while directory.path != "/" {
					candidates.append(directory.appendingPathComponent("caked"))
					candidates.append(directory.appendingPathComponent("Contents/PlugIns/caked.app/Contents/MacOS/caked"))
					directory = directory.deletingLastPathComponent()
				}
			}

			guard let caked = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
				throw ServiceError("caked not found")
			}

			#if BECOME_PARANOID
				let isDevelopmentHelper = self.isDevelopmentHelper()
				let developer = isDevelopmentHelper ? uid : nil

				guard isRootOwnedAndProtected(caked, alsoOwnedBy: developer) else {
					if let uid, isDevelopmentHelper {
						throw ServiceError("\(caked.path) must be owned by root or uid \(uid) and not writable by others to be run by the helper")
					} else {
						throw ServiceError("\(caked.path) must be owned by root and not writable by others to be run by the helper")
					}
				}

				guard isRootOwnedAndProtected(caked, alsoOwnedBy: developer) else {
					throw ServiceError("\(caked.path) must be owned by root and not writable by others to be run by the helper")
				}
			#endif

			return caked
		}

		private static func environment(home: URL) -> [String: String] {
			// CAKED_NOFOLLOW_PATHS: the paths handed to caked were canonicalized by the helper, so caked must not resolve a symlink
			// it finds in them (see `URL.openDirectoryWithoutFollowingSymlinks`).
			var env = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "CAKE_HOME": home.path]

			#if DEBUG
				env["TART_HOME"] = home.path(percentEncoded: false)
			#endif

			#if BECOME_PARANOID
				env[URL.noFollowPathsEnvironmentKey] = "1"
			#endif

			return env
		}

		private static func logFile() -> FileHandle {
			if FileManager.default.fileExists(atPath: logPath) == false {
				FileManager.default.createFile(atPath: logPath, contents: nil, attributes: [.posixPermissions: 0o644])
			}

			guard let handle = FileHandle(forWritingAtPath: logPath) else {
				return FileHandle.nullDevice
			}

			_ = try? handle.seekToEnd()

			return handle
		}

		/// The network's own log, `net.log` next to its socket and pid file, which is where `caked` writes it when the user starts the
		/// network, so a network the helper started logs where the user looks (not in this daemon's log). The directory is writable by
		/// the caller and this process is root: the file is opened without following a symlink (relative to the pinned directory when
		/// there is one), must be a regular file with a single link, and is handed to the caller. Falls back to the helper's own log.
		private static func networkLog(directory: URL, directoryDescriptor: CInt?, caller: Caller) -> FileHandle {
			let name = "net.log"
			// O_NONBLOCK: opening a FIFO planted under that name must fail instead of blocking this daemon.
			let flags = O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC
			let descriptor: CInt

			if let directoryDescriptor {
				descriptor = openat(directoryDescriptor, name, flags, 0o644)
			} else {
				descriptor = open(directory.appendingPathComponent(name).path(percentEncoded: false), flags, 0o644)
			}

			var attributes = stat()

			guard descriptor >= 0 else {
				return logFile()
			}

			guard fstat(descriptor, &attributes) == 0, (attributes.st_mode & S_IFMT) == S_IFREG, attributes.st_nlink == 1, ftruncate(descriptor, 0) == 0, fchown(descriptor, caller.uid, caller.gid) == 0 else {
				close(descriptor)
				return logFile()
			}

			return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
		}

		/// Runs `executable` to completion and returns its status and output.
		private static func runAndCollect(_ executable: URL, arguments: [String], environment: [String: String]) throws -> (status: Int32, output: String) {
			let process = Process()
			let pipe = Pipe()

			process.executableURL = executable
			process.arguments = arguments
			process.environment = environment
			process.standardInput = FileHandle.nullDevice
			process.standardOutput = pipe
			process.standardError = pipe

			try process.run()

			let data = pipe.fileHandleForReading.readDataToEndOfFile()

			process.waitUntilExit()

			return (process.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
		}

		/// Writes a root:wheel file with `mode`, replacing `destination` atomically.
		private static func installRootOwnedFile(_ content: String, to destination: String, mode: Int, validate: ((URL) throws -> Void)? = nil) throws {
			let destinationURL = URL(fileURLWithPath: destination)
			let parent = destinationURL.deletingLastPathComponent()
			let temporary = parent.appendingPathComponent(".\(destinationURL.lastPathComponent).\(getpid()).tmp")

			try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755, .ownerAccountID: 0, .groupOwnerAccountID: 0])
			try? FileManager.default.removeItem(at: temporary)

			defer {
				try? FileManager.default.removeItem(at: temporary)
			}

			guard FileManager.default.createFile(atPath: temporary.path, contents: Data(content.utf8), attributes: [.posixPermissions: mode, .ownerAccountID: 0, .groupOwnerAccountID: 0]) else {
				throw ServiceError("Unable to write \(temporary.path)")
			}

			try validate?(temporary)

			guard rename(temporary.path, destinationURL.path) == 0 else {
				throw ServiceError("Unable to install \(destination): \(String(cString: strerror(errno)))")
			}
		}

		// MARK: HelperToolProtocol implementation
		func checkConnectivity(authorization authData: Data, cakeHome: String, withReply reply: @escaping @Sendable (CakedLib.AuthorizationHelperReply) -> Void) {
			perform("check-connectivity", authorization: authData, command: #selector(AuthorizationHelperProtocol.checkConnectivity(authorization:cakeHome:withReply:)), reply: reply) { caller in
				let home = try Self.validatedHome(cakeHome, caller: caller)

				return String(localized: "Authorization successful, your cake home is: \(home.path(percentEncoded: false))")
			}
		}

		#if USE_DHCP_SERVER
			// IMPORTANT: NSXPCConnection can call these methods on any thread.  Each one checks its own authorization right,
			// then runs its work on a concurrent queue so a slow operation doesn't hold the connection.
			func startNetwork(authorization authData: Data, cakeHome: String, networkName: String, logLevel: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
				perform("start-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:logLevel:withReply:)), reply: reply) { caller in
					let home = try Self.validatedHome(cakeHome, caller: caller)

					try Self.validateNetworkName(networkName)

					let logLevel = try Self.validatedLogLevel(logLevel)
					let caked = try self.trustedCaked(alsoOwnedBy: caller.uid)
					let pidFile = try Home(home, runMode: .user, createItIfNotExists: false).networkDirectory.appendingPathComponent(networkName, isDirectory: true).appendingPathComponent("pid")

					if pidFile.isCakedRunning() {
						return "Network \(networkName) is already running"
					}

					// The network is the process: it keeps running after the helper's reply, logging to the network's own log.
					let networkDirectory = pidFile.deletingLastPathComponent()
					#if BECOME_PARANOID
						let directoryDescriptor = try URL.openPIDDirectory(networkDirectory.appendingPathComponent("net.pid"), beneath: home, owner: caller.uid)
						defer { close(directoryDescriptor) }
						let log = Self.networkLog(directory: networkDirectory, directoryDescriptor: directoryDescriptor, caller: caller)
					#else
						let log = Self.networkLog(directory: networkDirectory, directoryDescriptor: nil, caller: caller)
					#endif
					let process = Process()

					process.executableURL = caked
					process.arguments = ["networks", "start", networkName, "--fork", "--home=\(home.path)", "--log-level=\(logLevel)"]
					process.environment = Self.environment(home: home)
					process.standardInput = FileHandle.nullDevice
					process.standardOutput = log
					process.standardError = log

					try process.run()

					// Ready once the network wrote its pid file; a process that exits before that failed.
					for _ in 0..<150 {
						if FileManager.default.fileExists(atPath: pidFile.path), process.isRunning {
							return "Network \(networkName) started"
						}

						if process.isRunning == false {
							throw ServiceError("Network \(networkName) failed to start: status \(process.terminationStatus), see \(networkDirectory.appendingPathComponent("net.log").path)")
						}

						Thread.sleep(forTimeInterval: 0.1)
					}

					throw ServiceError("Network \(networkName) did not start within the expected time, see \(networkDirectory.appendingPathComponent("net.log").path)")
				}
			}
		#endif

		func setDHCPLease(authorization authData: Data, leaseTime: Int32, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
			perform("set-dhcp-lease", authorization: authData, command: #selector(AuthorizationHelperProtocol.setDHCPLease(authorization:leaseTime:withReply:)), reply: reply) { _ in
				guard leaseTime > 0 else {
					throw ServiceError("Invalid DHCP lease time \(leaseTime)")
				}

				// The helper is root: this writes the bootpd preferences directly.
				return try NetworksHandler.setDHCPLease(leaseTime: leaseTime, runMode: .user)
			}
		}

		func imdsRedirect(authorization authData: Data, externalAddress: String, internalAddress: String, internalPort: Int, install: Bool, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
			perform("imds-redirect", authorization: authData, command: #selector(AuthorizationHelperProtocol.imdsRedirect(authorization:externalAddress:internalAddress:internalPort:install:withReply:)), reply: reply) { caller in

				if install {
					try Self.validateIPv4(internalAddress)

					// The rule redirects whatever is sent to `externalAddress`: only the AWS-compatible address may be taken over.
					guard externalAddress == IMDSNetworkInterface.awsCompatAddress else {
						throw ServiceError("Only \(IMDSNetworkInterface.awsCompatAddress) can be redirected")
					}

					guard (1...65535).contains(internalPort) else {
						throw ServiceError("Invalid port \(internalPort)")
					}

					try PFRedirect.enableAddressAlias(externalAddress: externalAddress, targetAddress: internalAddress, targetPort: internalPort)

					return "IMDS redirect installed"
				}

				try PFRedirect.disableAddressAlias()

				return "IMDS redirect removed"
			}
		}

		func importVirtualMachine(authorization authData: Data, cakeHome: String, arguments: [String], logLevel: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
			perform("import-virtual-machine", authorization: authData, command: #selector(AuthorizationHelperProtocol.importVirtualMachine(authorization:cakeHome:arguments:logLevel:withReply:)), reply: reply) { caller in
				let home = try Self.validatedHome(cakeHome, caller: caller)

				// The import runs as root but the VM belongs to the caller: it can't choose another owner or home, nor
				// have root open a path or take an option it was not written for. Only a Multipass import needs root.
				try ImportHandler.validatePrivilegedImportArguments(arguments)

				let logLevel = try Self.validatedLogLevel(logLevel)
				let caked = try self.trustedCaked(alsoOwnedBy: caller.uid)
				let result = try Self.runAndCollect(
					caked,
					arguments: [
						"import",
						"--log-level=\(logLevel)",
						"--home=\(home.path)",
						"--uid=\(caller.uid)",
						"--gid=\(caller.gid)",
					] + arguments,
					environment: Self.environment(home: home))

				guard result.status == 0 else {
					throw ServiceError(result.output.isEmpty ? "Import failed with status \(result.status)" : result.output)
				}

				return result.output
			}
		}

		/// The `caked networks run` arguments for what a client asks. It runs as root, so every value is checked against what it must
		/// be (an address, a UUID, an interface name, a log level, ...) and nothing else reaches the command line: an option the client
		/// doesn't know can't be added, and an empty value means "not set".
		static func runNetworkArguments(_ networkConfig: [String: String], home: URL, descriptor: Int32, pidFile: URL) throws -> [String] {
			let allowed: Set<String> = ["mode", "name", "netmask", "dhcp-start", "dhcp-end", "interface-id", "nat66-prefix", "dns", "log-level"]

			if let unknown = networkConfig.keys.first(where: { allowed.contains($0) == false }) {
				throw ServiceError("Network option '\(unknown)' is not allowed")
			}

			func value(_ key: String) -> String? {
				guard let value = networkConfig[key], value.isEmpty == false else {
					return nil
				}

				return value
			}

			guard let mode = VMNetMode(rawValue: value("mode") ?? "shared") else {
				throw ServiceError("Invalid network mode '\(value("mode") ?? "")'")
			}

			let level = try Self.validatedLogLevel(value("log-level") ?? "info")
			var arguments: [String] = [
				"networks",
				"run",
				"--home=\(home.path)",
				"--log-level=\(level)",
				"--mode=\(mode.rawValue)",
				"--fd=\(descriptor)",
				"--pidfile=\(pidFile.path(percentEncoded: false))",
			]

			if level == "debug" || level == "trace" {
				arguments.append("--debug")
			}

			if let interfaceID = value("interface-id") {
				guard UUID(uuidString: interfaceID) != nil else {
					throw ServiceError("Invalid interface id '\(interfaceID)'")
				}

				arguments.append("--interface-id=\(interfaceID)")
			}

			if mode == .bridged {
				guard let name = value("name") else {
					throw ServiceError("interface is required for bridged mode")
				}

				guard name.count <= 32, name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-") }) else {
					throw ServiceError("Invalid interface name '\(name)'")
				}

				arguments.append("--interface=\(name)")
			} else {
				for (key, option) in [("dhcp-start", "--gateway"), ("dhcp-end", "--dhcp-end"), ("netmask", "--netmask")] {
					if let address = value(key) {
						try Self.validateIPv4(address)
						arguments.append("\(option)=\(address)")
					}
				}

				if let prefix = value("nat66-prefix") {
					let parts = prefix.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
					var storage = in6_addr()

					guard parts.count <= 2, inet_pton(AF_INET6, String(parts[0]), &storage) == 1, parts.count == 1 || (UInt8(parts[1]).map { $0 <= 128 } ?? false) else {
						throw ServiceError("Invalid NAT66 prefix '\(prefix)'")
					}

					arguments.append("--nat66-prefix=\(prefix)")
				}

				if let dns = value("dns") {
					guard dns == "true" || dns == "false" else {
						throw ServiceError("Invalid dns value '\(dns)'")
					}

					if dns == "true" {
						arguments.append("--dns")
					}
				}
			}

			return arguments
		}

		/// Networks started for a client, kept so their `Process` is reaped and not released while running.
		private static let runningNetworks = NSMutableDictionary()
		private static let runningNetworksLock = NSLock()

		func runNetwork(authorization authData: Data, cakeHome: String, networkConfig: [String: String], pidFile: String, fileHandle: FileHandle, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
			perform("run-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.runNetwork(authorization:cakeHome:networkConfig:pidFile:fileHandle:withReply:)), reply: reply) { caller in
				let home = try Self.validatedHome(cakeHome, caller: caller)
				let caked = try self.trustedCaked(alsoOwnedBy: caller.uid)
				let process = ProcessWithSharedFileHandle()

				#if BECOME_PARANOID
					let requested = URL(fileURLWithPath: pidFile).standardizedFileURL
					let pidURL = URL(fileURLWithPath: URL.canonicalPath(requested.deletingLastPathComponent().path(percentEncoded: false))).appendingPathComponent(requested.lastPathComponent)
					let pidDirectory = FileHandle(fileDescriptor: try URL.openPIDDirectory(pidURL, beneath: home, owner: caller.uid), closeOnDealloc: true)
					let log = Self.networkLog(directory: pidURL.deletingLastPathComponent(), directoryDescriptor: pidDirectory.fileDescriptor, caller: caller)
					let sharedFileHandles = [fileHandle, pidDirectory]
					var environment = Self.environment(home: home)

					environment[URL.pidDirectoryEnvironmentKey] = String(pidDirectory.fileDescriptor)
					environment[URL.pidPathEnvironmentKey] = pidURL.path(percentEncoded: false)
					unlinkat(pidDirectory.fileDescriptor, pidURL.lastPathComponent, 0)
				#else
					let pidURL = URL(fileURLWithPath: pidFile).standardizedFileURL
					let log = Self.networkLog(directory: pidURL.deletingLastPathComponent(), directoryDescriptor: nil, caller: caller)
					let sharedFileHandles = [fileHandle]
					let environment = Self.environment(home: home)
					// A stale file from a previous run must not be taken for this network's readiness.
					try? FileManager.default.removeItem(at: pidURL)
				#endif

				let arguments = try Self.runNetworkArguments(networkConfig, home: home, descriptor: fileHandle.fileDescriptor, pidFile: pidURL)

				process.executableURL = caked
				process.arguments = arguments
				process.standardInput = FileHandle.nullDevice
				process.standardOutput = log
				process.standardError = log
				process.sharedFileHandles = sharedFileHandles
				process.environment = environment

				process.terminationHandler = { process in
					Self.runningNetworksLock.lock()
					Self.runningNetworks.removeObject(forKey: NSNumber(value: process.processIdentifier))
					Self.runningNetworksLock.unlock()
				}

				try process.run()

				Self.runningNetworksLock.lock()
				Self.runningNetworks[NSNumber(value: process.processIdentifier)] = process
				Self.runningNetworksLock.unlock()

				for _ in 0..<150 {
					#if BECOME_PARANOID
						var attributes = stat()
						if fstatat(pidDirectory.fileDescriptor, pidURL.lastPathComponent, &attributes, AT_SYMLINK_NOFOLLOW) == 0, attributes.st_mode & S_IFMT == S_IFREG, process.isRunning {
							return String(process.processIdentifier)
						}
					#else
						if FileManager.default.fileExists(atPath: pidURL.path(percentEncoded: false)), process.isRunning {
							return String(process.processIdentifier)
						}
					#endif

					if process.isRunning == false {
						throw ServiceError("Network failed to start: status \(process.terminationStatus), see \(pidURL.deletingLastPathComponent().appendingPathComponent("net.log").path)")
					}

					Thread.sleep(forTimeInterval: 0.1)
				}

				process.terminate()

				throw ServiceError("Network did not start within the expected time, see \(pidURL.deletingLastPathComponent().appendingPathComponent("net.log").path)")
			}
		}

		func installPriviligedFiles(authorization authData: Data, cakerPath: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
			perform("install-priviliged-files", authorization: authData, command: #selector(AuthorizationHelperProtocol.installPriviligedFiles(authorization:cakerPath:withReply:)), reply: reply) { caller in
				let app = URL(fileURLWithPath: cakerPath).resolvingSymlinksInPath().standardizedFileURL

				guard app.pathExtension == "app", cakerPath.hasPrefix("/") else {
					throw ServiceError("Invalid application path '\(cakerPath)'")
				}

				// `caked` goes into a NOPASSWD sudoers rule: the file must be one nobody but root can replace.
				let caked = try self.trustedCaked(in: app, alsoOwnedBy: caller.uid)

				let plugins = app.appendingPathComponent("Contents/PlugIns")
				let directories = ["caked.app", "cakectl.app"]
					.map { plugins.appendingPathComponent($0).appendingPathComponent("Contents/MacOS").path + "/" }
					.filter { FileManager.default.fileExists(atPath: $0) }

				try Self.installRootOwnedFile(directories.joined(separator: "\n") + "\n", to: Self.installedPathsFile, mode: 0o644)

				// One rule file per user, naming that user only and pinning `caked` by its digest: see `SudoCaked.sudoersRule(uid:caked:)`.
				// It is also the one place that refuses a bundle that isn't root-owned all the way up.
				let sudoers = try SudoCaked.sudoersRule(uid: caller.uid, caked: caked)
				let installedSudoersFile = SudoCaked.sudoersRulePath(uid: caller.uid)

				// A broken sudoers file locks sudo out: let visudo check it before it replaces the real one.
				let checkSudoers: (URL) throws -> Void = { temporary in
					let check = try Self.runAndCollect(URL(fileURLWithPath: "/usr/sbin/visudo"), arguments: ["-c", "-f", temporary.path], environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"])

					guard check.status == 0 else {
						throw ServiceError("Invalid sudoers file: \(check.output)")
					}
				}

				try Self.installRootOwnedFile(sudoers, to: installedSudoersFile, mode: 0o440, validate: checkSudoers)

				// The digest changed for everybody: the other users that already have a rule get the new one too, otherwise
				// theirs would stop working until they open the application themselves.
				for uid in SudoCaked.installedRuleUIDs() where uid != caller.uid {
					try Self.installRootOwnedFile(try SudoCaked.sudoersRule(uid: uid, caked: caked), to: SudoCaked.sudoersRulePath(uid: uid), mode: 0o440, validate: checkSudoers)
				}

				// The `%everyone` rule of earlier versions, and the single-user file: nothing may keep granting them.
				for legacy in SudoCaked.legacySudoersRulePaths where unlink(legacy) != 0 && errno != ENOENT {
					throw ServiceError("Unable to remove \(legacy): \(String(cString: strerror(errno)))")
				}

				return "Installed \(Self.installedPathsFile) and \(installedSudoersFile)"
			}
		}
	}
#endif
