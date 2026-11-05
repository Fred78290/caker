//
//  Sudo.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/11/2025.
//
import CakeAgentLib
import CryptoKit
import Foundation
import GRPCLib

public let SUDO = "sudo"

public final class SudoCaked {
	let process: Process
	let outputQueue = DispatchQueue(label: UUID().uuidString)

	var stdout: Data!
	var stderr: Data!
	var outputPipe: Foundation.Pipe!
	var errorPipe: Foundation.Pipe!

	deinit {
		try? outputPipe?.close()
		try? errorPipe?.close()
	}

	public convenience init(arguments: [String], runMode: Utils.RunMode, log: FileHandle? = nil) throws {
		try self.init(command: Home.cakedCommandName, arguments: arguments, runMode: runMode, standardOutput: log, standardError: log)
	}

	public convenience init(arguments: [String], runMode: Utils.RunMode, standardOutput: FileHandle? = nil, standardError: FileHandle? = nil) throws {
		try self.init(command: Home.cakedCommandName, arguments: arguments, runMode: runMode, standardOutput: standardOutput, standardError: standardError)
	}

	public init(command: String, arguments: [String], runMode: Utils.RunMode, standardOutput: FileHandle? = nil, standardError: FileHandle? = nil) throws {
		guard let binary = URL.binary(command) else {
			throw ServiceError(String(localized: "\(command) not found in path"))
		}

		let launch = try Self.privilegedLaunch(binary: binary, runMode: runMode)
		let process = Process()
		let runningArguments = launch.arguments + arguments

		#if DEBUG
			Logger("SUDO").debug("SUDO: \(launch.executableURL) \(runningArguments.joined(separator: " "))")
		#endif

		process.executableURL = launch.executableURL
		process.arguments = runningArguments
		process.environment = launch.environment
		process.standardInput = FileHandle.nullDevice

		self.stdout = Data()
		self.stderr = Data()
		self.process = process

		if let standardOutput = standardOutput {
			process.standardOutput = standardOutput
			self.stdout = nil
		} else {
			let outputPipe = Pipe()

			self.outputPipe = outputPipe

			outputPipe.fileHandleForReading.readabilityHandler = nil
			outputPipe.fileHandleForReading.readabilityHandler = { handler in
				let data = handler.availableData

				if data.isEmpty == false {
					self.outputQueue.async {
						self.stdout.append(data)
					}
				}
			}

			process.standardOutput = outputPipe
		}

		if let standardError = standardError {
			process.standardError = standardError
			self.stderr = nil
		} else {
			let errorPipe = Pipe()

			self.errorPipe = errorPipe

			errorPipe.fileHandleForReading.readabilityHandler = nil
			errorPipe.fileHandleForReading.readabilityHandler = { handler in
				let data = handler.availableData

				if data.isEmpty == false {
					self.outputQueue.async {
						self.stderr.append(data)
					}
				}
			}

			process.standardError = errorPipe
		}
	}

	public func run() throws -> Self {
		try self.process.run()

		return self
	}

	public func waitUntilExit() -> Int32 {
		self.process.waitUntilExit()

		return outputQueue.sync {
			try? outputPipe?.close()
			try? errorPipe?.close()

			return self.process.terminationStatus
		}
	}

	public func runAndWait() throws -> Int32 {
		try self.run().waitUntilExit()
	}

	public var standardOutput: String {
		guard let stdout = self.stdout else {
			return String.empty
		}

		if let output = String(data: stdout, encoding: .utf8) {
			return output
		} else {
			return String.empty
		}
	}

	public var standardError: String {
		guard let stderr = self.stderr else {
			return String.empty
		}

		if let error = String(data: stderr, encoding: .utf8) {
			return error
		} else {
			return String.empty
		}
	}

	public var terminationStatus: Int32 {
		if self.process.isRunning {
			return 0
		}

		let status = self.process.terminationStatus

		if status != 0 {
			if let stdout = self.stdout {
				try? FileHandle.standardOutput.write(contentsOf: stdout)
			}

			if let stderr = self.stderr {
				try? FileHandle.standardError.write(contentsOf: stderr)
			}
		}

		return status
	}

	public var terminationReason: Process.TerminationReason {
		self.process.terminationReason
	}

	/// Environment variable telling a setuid-root `caked` it was launched to run privileged: it then calls `setuid(0)` (see `becomeRootIfRequested()`).
	public static let becomeRootEnvironmentKey = "CAKED_BECOME_ROOT"

	/// How to start `binary` with root privileges.
	public struct PrivilegedLaunch {
		/// What to execute: `binary` itself, or `sudo`.
		public let executableURL: URL
		/// Arguments to put before the command's own ones (empty for a direct launch).
		public let arguments: [String]
		public let environment: [String: String]
		/// `true` when `sudo` is used, `false` when `binary` gets root by itself (already root, or setuid-root).
		public let viaSudo: Bool
	}

	/// Whether `binary` gets root without `sudo`: the current process is root, or `binary` is owned by root with the setuid bit.
	public static func canElevateDirectly(binary: URL) -> Bool {
		if geteuid() == 0 {
			return true
		}

		guard let info = try? FileManager.default.attributesOfItem(atPath: binary.path(percentEncoded: false)) as NSDictionary else {
			return false
		}

		return info.fileOwnerAccountID() == 0 && (info.filePosixPermissions() & Int(S_ISUID)) != 0
	}

	/// Resolve how to start `binary` as root. A root-owned setuid `binary` (or a root caller) is executed directly, with
	/// `becomeRootEnvironmentKey` set so it switches its real uid to root; otherwise it goes through `sudo --non-interactive`.
	/// `--system` is added for the system run mode. Throws when neither is possible.
	public static func privilegedLaunch(binary: URL, runMode: Utils.RunMode) throws -> PrivilegedLaunch {
		var environment = try Utilities.environment(runMode: runMode)
		var arguments: [String] = []

		#if USE_SETUID
			if canElevateDirectly(binary: binary) {
				environment[becomeRootEnvironmentKey] = "1"

				if runMode.isSystem && binary.lastPathComponent == Home.cakedCommandName {
					arguments.append("--system")
				}

				return PrivilegedLaunch(executableURL: binary, arguments: arguments, environment: environment, viaSudo: false)
			}
		#endif

		guard let sudoURL = URL.binary(SUDO) else {
			throw ServiceError(String(localized: "sudo not found in path"))
		}

		guard try checkIfSudoable(sudoURL: sudoURL, binary: binary) else {
			throw ServiceError(String(localized: "\(binary.lastPathComponent) is not sudoable"))
		}

		arguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", binary.path(percentEncoded: false)]

		if runMode.isSystem && binary.lastPathComponent == Home.cakedCommandName {
			arguments.append("--system")
		}

		return PrivilegedLaunch(executableURL: sudoURL, arguments: arguments, environment: environment, viaSudo: true)
	}

	/// Whether the real user `uid` belongs to the `admin` group (what `sudo` requires on macOS).
	static func isAdministrator(uid: uid_t) -> Bool {
		guard uid != 0 else {
			return true
		}

		guard let user = getpwuid(uid), let admin = getgrnam("admin") else {
			return false
		}

		let adminGID = Int32(bitPattern: admin.pointee.gr_gid)
		var count: Int32 = 32
		var groups = [Int32](repeating: 0, count: Int(count))

		while getgrouplist(user.pointee.pw_name, Int32(bitPattern: user.pointee.pw_gid), &groups, &count) < 0 {
			guard Int(count) > groups.count else {
				return false
			}

			groups = [Int32](repeating: 0, count: Int(count))
		}

		return groups.prefix(Int(count)).contains(adminGID)
	}

	#if USE_SETUID
		/// A setuid-root `caked` gets root for whoever executes it. Called first thing in `main`: when the real user isn't
		/// an administrator, give the privileges back (`seteuid`) so the process runs as that user, as if it wasn't setuid.
		public static func dropSetuidPrivilegesIfUnauthorized() {
			let uid = getuid()

			guard geteuid() == 0 && uid != 0 /*&& isAdministrator(uid: uid) == false*/ else {
				return
			}

			if seteuid(uid) != 0 || setuid(uid) != 0 {
				Logger("SUDO").error("Unable to drop setuid privileges: \(String(cString: strerror(errno)))")
				exit(EXIT_FAILURE)
			}
		}

		/// Called at startup by a setuid-root `caked` launched with `becomeRootEnvironmentKey`: switch the real (and saved) uid to root,
		/// as `sudo` would have, then drop the variable so children don't inherit it. Does nothing when the key is absent or the process isn't root.
		public static func becomeRootIfRequested() {
			guard getenv(becomeRootEnvironmentKey) != nil else {
				return
			}

			unsetenv(becomeRootEnvironmentKey)

			if getuid() != 0 {
				/*if seteuid(0) != 0 {
					Logger("SUDO").error("seteuid(0) failed: \(String(cString: strerror(errno)))")
				}*/

				if setuid(0) != 0 {
					Logger("SUDO").error("setuid(0) failed: \(String(cString: strerror(errno)))")
				}
			}
		}
	#endif

	public static func checkIfSudoable(command: String) throws -> (Bool, URL, URL) {
		guard let binary = URL.binary(command) else {
			throw ServiceError(String(localized: "\(command) not found in path"))
		}

		guard let sudoURL = URL.binary(SUDO) else {
			throw ServiceError(String(localized: "sudo not found in path"))
		}

		return (try checkIfSudoable(sudoURL: sudoURL, binary: binary), sudoURL, binary)
	}

	public static func checkIfSudoable() throws -> (Bool, URL, URL) {
		return try checkIfSudoable(command: Home.cakedCommandName)
	}

	public static func checkIfSudoable(sudoURL: URL, binary: URL) throws -> Bool {
		if geteuid() == 0 {
			return true
		}

		let info = try FileManager.default.attributesOfItem(atPath: binary.path(percentEncoded: false)) as NSDictionary

		if info.fileOwnerAccountID() == 0 && (info.filePosixPermissions() & Int(S_ISUID)) != 0 {
			return true
		}

		let process = Process()

		process.executableURL = sudoURL
		process.environment = try Utilities.environment(runMode: .user)
		process.arguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", binary.path(percentEncoded: false), "--help"]
		process.standardInput = nil

		#if XDEBUG
			process.standardOutput = FileHandle.standardOutput
			process.standardError = FileHandle.standardError
		#else
			process.standardOutput = nil
			process.standardError = nil
		#endif

		try process.run()

		process.waitUntilExit()

		if process.terminationStatus == 0 {
			return true
		}

		return false
	}
}

// MARK: - /etc/sudoers.d/caked

/// The rule that lets one user run the bundled `caked` as root without a password (the fallback used when the
/// privileged helper can't do the job).
///
/// It is deliberately narrow, because it outlives the process that installed it and names a path inside an application bundle:
/// - it names one user (`#uid`), never `%everyone`;
/// - it pins the binary with its SHA-256 (`sha256:<digest>`), which sudo checks every time it runs the command. A `caked`
///   that was replaced, or a bundle moved aside and swapped for another one at the same path, is refused instead of run as root;
/// - it is only written for a `caked` that is itself unmodifiable by non-root users (see `isProtectedBundledBinary(_:)`).
///
/// Because the digest changes with every `caked`, the rule has to be rewritten on each update: `isCurrent(for:)` tells whether it
/// still accepts the given binary.
extension SudoCaked {
	/// Where the rule of the user `uid` lives. There is one file per user, so that several users of the same Mac (fast user
	/// switching, or two administrators) each have a rule and installing one never replaces another's. Mind that sudo skips
	/// files whose name contains a dot.
	public static func sudoersRulePath(uid: uid_t) -> String {
		"\(sudoersDirectory)/\(sudoersRulePrefix)\(uid)"
	}

	public static let sudoersDirectory = "/etc/sudoers.d"
	static let sudoersRulePrefix = "caked-pinned-"

	/// Files earlier versions wrote, to be removed whenever a current rule is installed: `caked` held the `%everyone` rule,
	/// `caked-pinned` a single rule for one user.
	public static let legacySudoersRulePaths = ["/etc/sudoers.d/caked", "/etc/sudoers.d/caked-pinned"]

	/// The users that have a rule installed in `directory`. A new digest invalidates every one of them, not just the user
	/// who updated the application.
	public static func installedRuleUIDs(in directory: String = sudoersDirectory) -> [uid_t] {
		let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []

		return names.compactMap { name -> uid_t? in
			guard name.hasPrefix(sudoersRulePrefix) else {
				return nil
			}

			let suffix = String(name.dropFirst(sudoersRulePrefix.count))

			// Only the canonical form, so that `caked-pinned-0501` or `caked-pinned-501.bak` are not taken for a rule.
			guard let uid = uid_t(suffix), String(uid) == suffix else {
				return nil
			}

			return uid
		}.sorted()
	}

	/// Whether `url` is owned by root and can't be modified by anybody else.
	static func isRootProtected(_ url: URL) -> Bool {
		guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)) as NSDictionary else {
			return false
		}

		return attributes.fileOwnerAccountID()?.uint32Value == 0 && (attributes.filePosixPermissions() & Int(S_IWGRP | S_IWOTH)) == 0
	}

	/// Whether `binary` and every directory between it and the outermost `.app` bundle containing it are owned by root and
	/// not writable by others. A package installs a bundle like that; a drag-and-drop install or a build in DerivedData doesn't.
	///
	/// This doesn't cover the directory the bundle sits in (`/Applications` is writable by the admin group): that is what the digest is for.
	public static func isProtectedBundledBinary(_ binary: URL) -> Bool {
		let resolved = binary.resolvingSymlinksInPath().standardizedFileURL
		var chain: [URL] = [resolved]
		var directory = resolved.deletingLastPathComponent()

		// Every directory up to the outermost `.app` containing the binary; nothing at all above it.
		var outermost: Int? = nil

		while directory.path != "/" {
			chain.append(directory)

			if directory.pathExtension == "app" {
				outermost = chain.count
			}

			directory = directory.deletingLastPathComponent()
		}

		return chain.prefix(outermost ?? 1).allSatisfy { isRootProtected($0) }
	}

	public static func sha256Hex(of url: URL) throws -> String {
		var hasher = SHA256()
		let handle = try FileHandle(forReadingFrom: url)

		defer {
			try? handle.close()
		}

		while let chunk = try handle.read(upToCount: 1 << 20), chunk.isEmpty == false {
			hasher.update(data: chunk)
		}

		return hasher.finalize().map { String(format: "%02x", $0) }.joined()
	}

	/// A command path as sudoers wants it: the characters it uses as separators are escaped.
	static func escapedForSudoers(_ path: String) -> String {
		var result = ""

		for character in path {
			if " ,:=\\\"#!".contains(character) {
				result.append("\\")
			}

			result.append(character)
		}

		return result
	}

	/// The content of the rule file of the user `uid` (`sudoersRulePath(uid:)`) for the binary `caked`.
	/// Throws when `caked` can't be trusted with root (see `isProtectedBundledBinary(_:)`).
	public static func sudoersRule(uid: uid_t, caked: URL) throws -> String {
		guard isProtectedBundledBinary(caked) else {
			throw ServiceError("\(caked.path(percentEncoded: false)) must be owned by root and not writable by others to be run without a password")
		}

		let digest = try sha256Hex(of: caked.resolvingSymlinksInPath())

		return "#\(uid) ALL=(root:wheel) NOPASSWD:SETENV: sha256:\(digest) \(escapedForSudoers(caked.path(percentEncoded: false)))\n"
	}

	/// Whether the installed rule lets the current user run `caked` as root: sudo checks the user, the path and the digest.
	public static func isCurrent(for caked: URL) -> Bool {
		guard let sudo = URL.binary(SUDO) else {
			return false
		}

		return (try? checkIfSudoable(sudoURL: sudo, binary: caked)) ?? false
	}
}
