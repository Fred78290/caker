//
//  helper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/11/2026.
//

import CakeAgentLib
import CakedLib
import Darwin
import Foundation
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

		newConnection.exportedInterface = AuthorizationHelperCommon.makeInterface()
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
		if Bundle.isApplicationSandboxed {
			return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.\(Utils.cakerSignature)")!
		}

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

	/// A network name is a single path component and can't be taken for an option.
	private static func validateNetworkName(_ name: String) throws {
		guard name.isEmpty == false, name.count <= 128, name.first != "-", name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) }), name != ".", name != ".." else {
			throw ServiceError("Invalid network name '\(name)'")
		}
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
		#if APPSTORE
			["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
		#else
			["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "CAKE_HOME": home.path, "TART_HOME": home.path]
		#endif
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

	/// Same as `runAndCollect`, with the output kept apart from the errors: a command that prints JSON must be parsed without
	/// whatever it logs next to it.
	private static func runAndCollectSeparately(_ executable: URL, arguments: [String], environment: [String: String]) throws -> (status: Int32, output: String, error: String) {
		let process = Process()
		let output = Pipe()
		let error = Pipe()

		process.executableURL = executable
		process.arguments = arguments
		process.environment = environment
		process.standardInput = FileHandle.nullDevice
		process.standardOutput = output
		process.standardError = error

		try process.run()

		// Both pipes are drained at the same time: a command that fills one while this waits on the other would block.
		nonisolated(unsafe) var errorData = Data()
		let drained = DispatchGroup()

		drained.enter()

		DispatchQueue.global().async {
			errorData = error.fileHandleForReading.readDataToEndOfFile()
			drained.leave()
		}

		let outputData = output.fileHandleForReading.readDataToEndOfFile()

		drained.wait()
		process.waitUntilExit()

		return (process.terminationStatus, String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines), String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
	}

	/// Runs `caked networks <arguments>` as root on the caller's cake home and returns what it printed.
	///
	/// The network commands validate their own arguments (a network in use, a reserved name, an address already taken...) and report
	/// a refusal as a non-zero status, which is thrown here with the command's own message.
	private func runNetworksCommand(_ arguments: [String], home: URL, caller: Caller, json: Bool = true) throws -> String {
		let caked = try self.trustedCaked(alsoOwnedBy: caller.uid)
		let result = try Self.runAndCollectSeparately(caked, arguments: ["networks"] + arguments + ["--home", home.path] + (json ? ["--json"] : []), environment: Self.environment(home: home))

		guard result.status == 0 else {
			// ArgumentParser writes "Error: <reason>" followed by the usage of the command: only the reason is of any use to the caller.
			var message = result.error.isEmpty ? result.output : result.error

			message = message.components(separatedBy: "\nUsage:").first ?? message

			if message.hasPrefix("Error: ") {
				message.removeFirst("Error: ".count)
			}

			message = message.trimmingCharacters(in: .whitespacesAndNewlines)

			throw ServiceError(message.isEmpty ? "Network command failed with status \(result.status)" : message)
		}

		return result.output
	}

	/// A root `caked` that creates `net/` or rewrites `networks.json` in the caller's cake home leaves them owned by root, which the
	/// caller's own `caked` could no longer update: hand them back. Both are opened without following symbolic links, the caller
	/// owns the directory and could otherwise have a link there point root at a file of its choice.
	private static func restoreOwnership(home: URL, caller: Caller) {
		guard Bundle.isApplicationSandboxed == false else {
			return
		}

		func giveBack(_ descriptor: Int32) {
			var status = stat()

			if fstat(descriptor, &status) == 0, status.st_uid == 0 {
				_ = fchown(descriptor, caller.uid, caller.gid)
			}
		}

		let directory = open(home.appendingPathComponent("net", isDirectory: true).path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)

		guard directory >= 0 else {
			return
		}

		defer {
			close(directory)
		}

		giveBack(directory)

		let file = openat(directory, Home.networksFilename, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)

		if file >= 0 {
			giveBack(file)
			close(file)
		}
	}

	/// How the value of a `caked networks create`/`configure` option is checked before it reaches a root command line.
	private enum NetworkOptionKind {
		case mode, ipv4, uuid, bool, prefix
		case seconds
	}

	private static let networkOptionKinds: [String: NetworkOptionKind] = [
		"mode": .mode,
		"gateway": .ipv4,
		"dhcp-end": .ipv4,
		"netmask": .ipv4,
		"dhcp-lease": .seconds,
		"interface-id": .uuid,
		"dns": .bool,
		"nat66-prefix": .prefix,
	]

	/// The command line for `options` (long option name without the dashes -> value), refusing any option, or value,
	/// `caked networks create`/`configure` was not meant to receive from a client. `configure` can't change the mode of a network.
	private static func networkOptionArguments(_ options: [String: Any], allowMode: Bool, dnsIsFlag: Bool) throws -> [String] {
		var arguments: [String] = []

		for name in options.keys.sorted() {
			guard let kind = Self.networkOptionKinds[name], allowMode || name != "mode", let value = options[name] else {
				throw ServiceError("Option \(name) is not allowed")
			}

			func text() throws -> String {
				guard let text = value as? String, text.isEmpty == false, text.count <= 64, text.first != "-" else {
					throw ServiceError("Invalid value for option \(name)")
				}

				return text
			}

			switch kind {
			case .mode:
				let mode = try text()

				guard mode == "shared" || mode == "host" else {
					throw ServiceError("Invalid network mode '\(mode)'")
				}

				arguments += ["--mode", mode]
			case .ipv4:
				let address = try text()

				try Self.validateIPv4(address)

				arguments += ["--\(name)", address]
			case .uuid:
				let uuid = try text()

				guard UUID(uuidString: uuid) != nil else {
					throw ServiceError("Invalid interface identifier '\(uuid)'")
				}

				arguments += ["--interface-id", uuid]
			case .prefix:
				let prefix = try text()

				// An IPv6 prefix: hexadecimal digits, colons and the length.
				guard prefix.allSatisfy({ $0.isHexDigit || $0 == ":" || $0 == "/" }) else {
					throw ServiceError("Invalid IPv6 prefix '\(prefix)'")
				}

				arguments += ["--nat66-prefix", prefix]
			case .seconds:
				guard let seconds = (value as? NSNumber)?.int64Value, (1...Int64(Int32.max)).contains(seconds) else {
					throw ServiceError("Invalid DHCP lease time")
				}

				arguments += ["--dhcp-lease", String(seconds)]
			case .bool:
				guard let enabled = (value as? NSNumber)?.boolValue else {
					throw ServiceError("Invalid value for option dns")
				}

				if dnsIsFlag {
					// `create` has a flag, which can only turn it on.
					if enabled {
						arguments.append("--dns")
					}
				} else {
					arguments += ["--dns", enabled ? "true" : "false"]
				}
			}
		}

		return arguments
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

	// IMPORTANT: NSXPCConnection can call these methods on any thread.  Each one checks its own authorization right,
	// then runs its work on a concurrent queue so a slow operation doesn't hold the connection.
	func startNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		perform("start-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			try Self.validateNetworkName(networkName)

			let caked = try self.trustedCaked(alsoOwnedBy: caller.uid)
			let pidFile = try Home(home, runMode: .user, createItIfNotExists: false).networkDirectory.appendingPathComponent(networkName, isDirectory: true).appendingPathComponent("pid")

			if pidFile.isCakedRunning() {
				return "Network \(networkName) is already running"
			}

			// The network is the process: it keeps running after the helper's reply, logging to the helper's log.
			let log = Self.logFile()
			let process = Process()

			process.executableURL = caked
			process.arguments = ["networks", "start", "--fork", "--home", home.path, networkName]
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
					throw ServiceError("Network \(networkName) failed to start: status \(process.terminationStatus), see \(Self.logPath)")
				}

				Thread.sleep(forTimeInterval: 0.1)
			}

			throw ServiceError("Network \(networkName) did not start within the expected time, see \(Self.logPath)")
		}
	}

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

	func importVirtualMachine(authorization authData: Data, cakeHome: String, arguments: [String], withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		perform("import-virtual-machine", authorization: authData, command: #selector(AuthorizationHelperProtocol.importVirtualMachine(authorization:cakeHome:arguments:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			// The import runs as root but the VM belongs to the caller: it can't choose another owner or home, nor
			// have root open a path or take an option it was not written for. Only a Multipass import needs root.
			try ImportHandler.validatePrivilegedImportArguments(arguments)

			let caked = try self.trustedCaked(alsoOwnedBy: caller.uid)
			let result = try Self.runAndCollect(caked, arguments: ["import", "--home", home.path, "--uid", String(caller.uid), "--gid", String(caller.gid)] + arguments, environment: Self.environment(home: home))

			guard result.status == 0 else {
				throw ServiceError(result.output.isEmpty ? "Import failed with status \(result.status)" : result.output)
			}

			return result.output
		}
	}

	/// `caked networks run` options a client may choose. Anything else (and any value outside `--option=value`) is refused.
	private static let runNetworkOptions: Set<String> = ["--mode", "--interface-id", "--interface", "--gateway", "--dhcp-end", "--netmask", "--nat66-prefix", "--log-level"]
	private static let runNetworkFlags: Set<String> = ["--debug", "--dns"]

	/// Networks started for a client, kept so their `Process` is reaped and not released while running.
	private static let runningNetworks = NSMutableDictionary()
	private static let runningNetworksLock = NSLock()

	func runNetwork(authorization authData: Data, cakeHome: String, arguments: [String], pidFile: String, fileHandle: FileHandle, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		perform("run-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.runNetwork(authorization:cakeHome:arguments:pidFile:fileHandle:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			for argument in arguments {
				let name = argument.split(separator: "=", maxSplits: 1).first.map(String.init) ?? argument

				guard Self.runNetworkFlags.contains(argument) || (argument.contains("=") && Self.runNetworkOptions.contains(name)) else {
					throw ServiceError("Argument \(argument) is not allowed")
				}
			}

			// The pid file is written as root: it must be a .pid file inside the caller's cake home.
			let requested = URL(fileURLWithPath: pidFile).standardizedFileURL
			let pidURL = requested.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(requested.lastPathComponent)

			guard pidURL.pathExtension == "pid", pidURL.path.hasPrefix(home.path + "/") else {
				throw ServiceError("Invalid pid file '\(pidFile)'")
			}

			let caked = try self.trustedCaked(alsoOwnedBy: caller.uid)
			let log = Self.logFile()
			let process = ProcessWithSharedFileHandle()

			try? FileManager.default.removeItem(at: pidURL)

			process.executableURL = caked
			// The descriptor keeps the number it has here in the child.
			process.arguments = ["networks", "run", "--home", home.path] + arguments + ["--fd=\(fileHandle.fileDescriptor)", "--pidfile=\(pidURL.path)"]
			process.environment = Self.environment(home: home)
			process.standardInput = FileHandle.nullDevice
			process.standardOutput = log
			process.standardError = log
			process.sharedFileHandles = [fileHandle]

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
				if FileManager.default.fileExists(atPath: pidURL.path), process.isRunning {
					return String(process.processIdentifier)
				}

				if process.isRunning == false {
					throw ServiceError("Network failed to start: status \(process.terminationStatus), see \(Self.logPath)")
				}

				Thread.sleep(forTimeInterval: 0.1)
			}

			process.terminate()

			throw ServiceError("Network did not start within the expected time, see \(Self.logPath)")
		}
	}

	// MARK: Networks

	// The other network operations run the network commands of the trusted `caked` as root on the caller's cake home, the same way
	// `startNetwork` does. A network is root's process and its files and control socket are not reachable from a sandboxed caller.
	func createNetwork(authorization authData: Data, cakeHome: String, networkName: String, options: [String: Any], withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		nonisolated(unsafe) let options = options

		perform("create-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.createNetwork(authorization:cakeHome:networkName:options:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			try Self.validateNetworkName(networkName)

			let arguments = try Self.networkOptionArguments(options, allowMode: true, dnsIsFlag: true)

			defer {
				Self.restoreOwnership(home: home, caller: caller)
			}

			return try self.runNetworksCommand(["create"] + arguments + [networkName], home: home, caller: caller)
		}
	}

	func configureNetwork(authorization authData: Data, cakeHome: String, networkName: String, options: [String: Any], withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		nonisolated(unsafe) let options = options

		perform("configure-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.configureNetwork(authorization:cakeHome:networkName:options:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			try Self.validateNetworkName(networkName)

			let arguments = try Self.networkOptionArguments(options, allowMode: false, dnsIsFlag: false)

			defer {
				Self.restoreOwnership(home: home, caller: caller)
			}

			return try self.runNetworksCommand(["configure"] + arguments + [networkName], home: home, caller: caller)
		}
	}

	func restartNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		perform("restart-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.restartNetwork(authorization:cakeHome:networkName:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			try Self.validateNetworkName(networkName)

			// The command prints a sentence, not a structure.
			return try self.runNetworksCommand(["restart", networkName], home: home, caller: caller, json: false)
		}
	}

	func stopNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		perform("stop-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.stopNetwork(authorization:cakeHome:networkName:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			try Self.validateNetworkName(networkName)

			return try self.runNetworksCommand(["stop", networkName], home: home, caller: caller)
		}
	}

	func deleteNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		perform("delete-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.deleteNetwork(authorization:cakeHome:networkName:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			try Self.validateNetworkName(networkName)

			defer {
				Self.restoreOwnership(home: home, caller: caller)
			}

			return try self.runNetworksCommand(["delete", networkName], home: home, caller: caller)
		}
	}

	func listNetwork(authorization authData: Data, cakeHome: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		perform("list-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.listNetwork(authorization:cakeHome:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			return try self.runNetworksCommand(["list"], home: home, caller: caller)
		}
	}

	func infosNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void) {
		perform("infos-network", authorization: authData, command: #selector(AuthorizationHelperProtocol.infosNetwork(authorization:cakeHome:networkName:withReply:)), reply: reply) { caller in
			let home = try Self.validatedHome(cakeHome, caller: caller)

			try Self.validateNetworkName(networkName)

			return try self.runNetworksCommand(["infos", networkName], home: home, caller: caller)
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
