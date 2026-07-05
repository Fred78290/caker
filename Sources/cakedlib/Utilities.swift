import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Socket
import Subprocess
import System
import Virtualization

extension Date {
	public func asTimeval() -> timeval {
		timeval(tv_sec: Int(timeIntervalSince1970), tv_usec: 0)
	}
}

extension Bundle {
	public static func createProcess() throws -> Process {
		guard Bundle.mustUseUnixTask == false else {
			throw ServiceError("Process can't be used with sandboxed Caker")
		}

		return Process()
	}

	public static func createProcessWithSharedFileHandle() throws -> ProcessWithSharedFileHandle {
		guard Bundle.mustUseUnixTask == false else {
			throw ServiceError("ProcessWithSharedFileHandle can't be used with sandboxed Caker")
		}

		return ProcessWithSharedFileHandle()
	}

	public var cakerBuildPlugInsPath: [String] {
		var paths: [String] = []

		if let cakedBundlePath = self.cakedBundlePath {
			paths.append(cakedBundlePath)
		}

		if let cakectlBundlePath = self.cakectlBundlePath {
			paths.append(cakectlBundlePath)
		}

		return paths
	}

	public var cakedBundlePath: String? {
		guard let url = self.cakedBundleURL else {
			return nil
		}

		return url.path
	}

	public var cakedBundleURL: URL? {
		guard let pluginURL = self.builtInPlugInsURL else {
			return nil
		}

		let cakedBundleURL = pluginURL.appendingPathComponent("caked.bundle/Contents/MacOS").absoluteURL
		var isDirectory: ObjCBool = false

		guard FileManager.default.fileExists(atPath: cakedBundleURL.path, isDirectory: &isDirectory) else {
			return nil
		}

		guard isDirectory.boolValue else {
			return nil
		}

		return cakedBundleURL
	}

	public var cakectlBundlePath: String? {
		guard let url = self.cakectlBundleURL else {
			return nil
		}

		return url.path
	}

	public var cakectlBundleURL: URL? {
		guard let pluginURL = self.builtInPlugInsURL else {
			return nil
		}

		let cakectlBundleURL = pluginURL.appendingPathComponent("cakectl.bundle/Contents/MacOS").absoluteURL
		var isDirectory: ObjCBool = false

		guard FileManager.default.fileExists(atPath: cakectlBundleURL.path, isDirectory: &isDirectory) else {
			return nil
		}

		guard isDirectory.boolValue else {
			return nil
		}

		return cakectlBundleURL
	}

	public func caked() throws -> URL {
		guard var pluginsURL = self.cakedBundleURL else {
			guard let executableURL = self.executableURL, executableURL.path(percentEncoded: false).hasSuffix(Home.cakedCommandName) else {
				guard let executableURL = URL.binary(Home.cakedCommandName) else {
					throw ServiceError(String(localized: "caked not found in path"))
				}

				return executableURL
			}

			return executableURL
		}

		pluginsURL = pluginsURL.appendingPathComponent(Home.cakedCommandName)

		guard try pluginsURL.exists() else {
			guard let executableURL = URL.binary(Home.cakedCommandName) else {
				throw ServiceError(String(localized: "caked not found in path"))
			}

			return executableURL
		}

		return pluginsURL
	}

	private static func buildScriptFile(_ executableURL: URL) throws -> URL {
		let uuid = UUID().uuidString
		let scriptsFile = try FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(executableURL.lastPathComponent)-\(uuid).sh")

		#if TRACE
			let stdout = scriptsFile.deletingPathExtension().appendingPathExtension("stdout.txt").path(percentEncoded: false)
			let stderr = scriptsFile.deletingPathExtension().appendingPathExtension("stderr.txt").path(percentEncoded: false)
			let scripts =
				"""
				#!/bin/bash
				exec > >(tee "\(stdout)") 2> >(tee "\(stderr)" >&2)

				"\(executableURL.path(percentEncoded: false))" "$@"
				"""
		#else
			let scripts =
				"""
				#!/bin/sh

				exec "\(executableURL.path(percentEncoded: false))" "$@"
				"""
		#endif

		try scripts.write(to: scriptsFile, atomically: true, encoding: .ascii)
		try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptsFile.path(percentEncoded: false))

		return scriptsFile
	}

	public static func runExecutableWithUnixTask(
		_ executableURL: URL,
		with arguments: [String],
		standardInput: Any?,
		standardOutput: Any?,
		standardError: Any?,
	) async throws {
		let scriptsFile = try buildScriptFile(executableURL)
		let userTask = try NSUserUnixTask(url: scriptsFile)

		if let standardInput = standardInput as? FileHandle {
			userTask.standardInput = FileHandle(fileDescriptor: dup(standardInput.fileDescriptor), closeOnDealloc: true)
		} else if let pipe = standardInput as? Pipe {
			userTask.standardInput = pipe.fileHandleForReading
		}

		if let standardOutput = standardOutput as? FileHandle {
			userTask.standardOutput = FileHandle(fileDescriptor: dup(standardOutput.fileDescriptor), closeOnDealloc: true)
		} else if let pipe = standardOutput as? Pipe {
			userTask.standardOutput = pipe.fileHandleForWriting
		}

		if let standardError = standardError as? FileHandle {
			userTask.standardError = FileHandle(fileDescriptor: dup(standardError.fileDescriptor), closeOnDealloc: true)
		} else if let pipe = standardError as? Pipe {
			userTask.standardError = pipe.fileHandleForWriting
		}

		defer {
			try? FileManager.default.removeItem(at: scriptsFile)
		}

		try await userTask.execute(withArguments: arguments)
	}

	public static func runExecutableWithUnixTask(
		_ executableURL: URL,
		with arguments: [String],
		standardInput: Any?,
		standardOutput: Any?,
		standardError: Any?,
		completionHandler handler: NSUserUnixTask.CompletionHandler? = nil
	) throws {
		let scriptsFile = try buildScriptFile(executableURL)
		let userTask = try NSUserUnixTask(url: scriptsFile)

		if let standardInput = standardInput as? FileHandle {
			userTask.standardInput = standardInput  //FileHandle(fileDescriptor: dup(standardInput.fileDescriptor), closeOnDealloc: true)
		} else if let pipe = standardInput as? Pipe {
			userTask.standardInput = pipe.fileHandleForReading
		}

		if let standardOutput = standardOutput as? FileHandle {
			userTask.standardOutput = standardOutput  //FileHandle(fileDescriptor: dup(standardOutput.fileDescriptor), closeOnDealloc: true)
		} else if let pipe = standardOutput as? Pipe {
			userTask.standardOutput = pipe.fileHandleForWriting
		}

		if let standardError = standardError as? FileHandle {
			userTask.standardError = standardError  //FileHandle(fileDescriptor: dup(standardError.fileDescriptor), closeOnDealloc: true)
		} else if let pipe = standardError as? Pipe {
			userTask.standardError = pipe.fileHandleForWriting
		}

		#if !DEBUG
			defer {
				try? FileManager.default.removeItem(at: scriptsFile)
			}
		#endif

		do {
			try Task.sync {
				try await userTask.execute(withArguments: arguments)
			}

			handler?(nil)
		} catch {
			handler?(error)
		}
	}

	public static func runCakedWithUnixTask(
		with arguments: [String],
		standardInput: Any? = FileHandle.standardInput,
		standardOutput: Any? = FileHandle.standardOutput,
		standardError: Any? = FileHandle.standardError,
	) async throws {
		try await runExecutableWithUnixTask(
			Bundle.main.caked(),
			with: arguments,
			standardInput: standardInput,
			standardOutput: standardOutput,
			standardError: standardError)
	}

	public static func runCakedWithUnixTask(
		with arguments: [String],
		standardInput: Any? = FileHandle.standardInput,
		standardOutput: Any? = FileHandle.standardOutput,
		standardError: Any? = FileHandle.standardError,
		completionHandler handler: NSUserUnixTask.CompletionHandler? = nil
	) throws {
		try runExecutableWithUnixTask(
			Bundle.main.caked(),
			with: arguments,
			standardInput: standardInput,
			standardOutput: standardOutput,
			standardError: standardError,
			completionHandler: handler)
	}

	public static func runExecutable(
		_ executableURL: URL,
		with arguments: [String],
		sudo: Bool = false,
		standardInput: Any? = FileHandle.standardInput,
		standardOutput: Any? = FileHandle.standardOutput,
		standardError: Any? = FileHandle.standardError,
		runMode: Utils.RunMode,
		completionHandler handler: NSUserUnixTask.CompletionHandler? = nil
	) throws {
		if Bundle.mustUseUnixTask {
			if sudo {
				throw ServiceError(String(localized: "Sudo is not supported in sandboxed mode"))
			}

			try runExecutableWithUnixTask(executableURL, with: arguments, standardInput: standardInput, standardOutput: standardOutput, standardError: standardError, completionHandler: handler)
		} else {
			var executableURL = executableURL
			let process = Process()
			var runningArguments: [String] = []

			if sudo {
				guard let sudoURL = URL.binary(SUDO) else {
					throw ServiceError(String(localized: "sudo not found in path"))
				}

				guard try SudoCaked.checkIfSudoable(sudoURL: sudoURL, binary: executableURL) else {
					throw ServiceError(String(localized: "\(executableURL.lastPathComponent) is not sudoable"))
				}

				runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", executableURL.path]

				if runMode.isSystem {
					runningArguments.append("--system")
				}

				executableURL = sudoURL
			}

			runningArguments.append(contentsOf: arguments)

			Logger(self).debug("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

			process.executableURL = executableURL
			process.environment = try Utilities.environment(runMode: runMode)
			process.arguments = runningArguments

			process.standardOutput = standardOutput
			process.standardError = standardError
			process.standardInput = standardInput
			process.terminationHandler = { process in
				if let handler {
					if process.terminationStatus == 0 {
						handler(nil)
					} else {
						handler(NSError(domain: NSPOSIXErrorDomain, code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: process.terminationReason]))
					}
				}
			}

			try process.run()
		}
	}

	public static func runExecutable(
		_ executableURL: URL,
		with arguments: [String],
		sudo: Bool = false,
		sharedFileHandles: [FileHandle],
		standardInput: Any? = FileHandle.standardInput,
		standardOutput: Any? = FileHandle.standardOutput,
		standardError: Any? = FileHandle.standardError,
		runMode: Utils.RunMode,
		completionHandler handler: NSUserUnixTask.CompletionHandler? = nil
	) throws {
		if Bundle.mustUseUnixTask {
			if sudo {
				throw ServiceError(String(localized: "Sudo is not supported in sandboxed mode"))
			}

			try runExecutableWithUnixTask(executableURL, with: arguments, standardInput: standardInput, standardOutput: standardOutput, standardError: standardError, completionHandler: handler)
		} else {
			var executableURL = executableURL
			let process = ProcessWithSharedFileHandle()
			var runningArguments: [String] = []

			if sudo {
				guard let sudoURL = URL.binary(SUDO) else {
					throw ServiceError(String(localized: "sudo not found in path"))
				}

				guard try SudoCaked.checkIfSudoable(sudoURL: sudoURL, binary: executableURL) else {
					throw ServiceError(String(localized: "\(executableURL.lastPathComponent) is not sudoable"))
				}

				runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", executableURL.path]

				if runMode.isSystem {
					runningArguments.append("--system")
				}

				executableURL = sudoURL
			}

			runningArguments.append(contentsOf: arguments)

			Logger(self).debug("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

			process.executableURL = executableURL
			process.environment = try Utilities.environment(runMode: runMode)
			process.arguments = runningArguments

			process.sharedFileHandles = sharedFileHandles
			process.standardOutput = standardOutput
			process.standardError = standardError
			process.standardInput = standardInput
			process.terminationHandler = { process in
				if let handler {
					if process.terminationStatus == 0 {
						handler(nil)
					} else {
						handler(NSError(domain: NSPOSIXErrorDomain, code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: process.terminationReason]))
					}
				}
			}

			try process.run()
		}
	}

	public static func runCaked(
		with arguments: [String],
		sudo: Bool = false,
		standardInput: Any? = FileHandle.standardInput,
		standardOutput: Any? = FileHandle.standardOutput,
		standardError: Any? = FileHandle.standardError,
		runMode: Utils.RunMode,
		completionHandler handler: NSUserUnixTask.CompletionHandler? = nil
	) throws {
		try runExecutable(
			Bundle.main.caked(),
			with: arguments,
			sudo: sudo,
			standardInput: standardInput,
			standardOutput: standardOutput,
			standardError: standardError,
			runMode: runMode,
			completionHandler: handler)
	}

	public static func runCaked(
		with arguments: [String],
		sudo: Bool = false,
		sharedFileHandles: [FileHandle],
		standardInput: Any? = FileHandle.standardInput,
		standardOutput: Any? = FileHandle.standardOutput,
		standardError: Any? = FileHandle.standardError,
		runMode: Utils.RunMode,
		completionHandler handler: NSUserUnixTask.CompletionHandler? = nil
	) throws {
		try runExecutable(
			Bundle.main.caked(),
			with: arguments,
			sudo: sudo,
			sharedFileHandles: sharedFileHandles,
			standardInput: standardInput,
			standardOutput: standardOutput,
			standardError: standardError,
			runMode: runMode,
			completionHandler: handler)
	}

	@discardableResult public static func execSandboxed(_ command: FilePath, with arguments: [String], _ completion: Shell.ExecCompletion? = nil) throws -> String {
		if Bundle.mustUseUnixTask {
			let stderr = Pipe()
			let stdout = Pipe()
			var outputData = Data()
			var errorData = Data()
			let outputQueue = ShellProcessQueues.commandOutput

			#if DEBUG
				var debug: [String] = [command.description]
				debug.append(contentsOf: arguments)
				print("🚀 \(debug.joined(separator: " "))")
			#endif

			stdout.fileHandleForReading.readabilityHandler = { handler in
				let data = handler.availableData
				outputQueue.async {
					outputData.append(data)
				}
			}

			stderr.fileHandleForReading.readabilityHandler = { handler in
				let data = handler.availableData
				outputQueue.async {
					errorData.append(data)
				}
			}

			defer {
				try? stderr.close()
				try? stdout.close()
			}

			do {
				try Self.runExecutableWithUnixTask(URL(filePath: command)!, with: arguments, standardInput: nil, standardOutput: stdout.fileHandleForWriting, standardError: stderr.fileHandleForWriting)

				let output = outputQueue.sync {
					return (stdout: String(data: outputData, encoding: .utf8) ?? "", stderr: String(data: errorData, encoding: .utf8) ?? "")
				}

				guard let completion else {
					return output.stdout
				}

				return try completion(0, output.stdout, output.stderr)
			} catch {
				let output = outputQueue.sync {
					return (stdout: String(data: outputData, encoding: .utf8) ?? "", stderr: String(data: errorData, encoding: .utf8) ?? "")
				}

				guard let completion else {
					return output.stdout
				}

				return try completion(1, output.stdout, output.stderr)
			}
		} else {
			return try Shell.exec(command, arguments: arguments, completion)
		}
	}
}

public func processExist(_ runningPID: pid_t) throws -> (running: Bool, processName: String, pid: pid_t) {
	// Requesting the pid of 0 from systcl will return all pids
	var mib = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
	var bufferSize = 0

	// To find the needed buffer size you call sysctl with a nil results pointer.
	// This sets the size of the buffer needed in the bufferSize pointer.
	if sysctl(&mib, UInt32(mib.count), nil, &bufferSize, nil, 0) < 0 {
		throw ServiceError(errno)
	}

	// Determine how many kinfo_proc struts will be returned.
	// Using stride rather than size will take alligment into account.
	let entryCount = bufferSize / MemoryLayout<kinfo_proc>.stride

	// Create our buffer to be filled with the list of processes and allocate it.
	// Use defer to make sure it's deallocated when the scope ends.
	var procList: UnsafeMutablePointer<kinfo_proc>?
	procList = UnsafeMutablePointer.allocate(capacity: bufferSize)
	defer {
		procList?.deallocate()
	}

	// Now we actually perform our query to get all the processes.
	if sysctl(&mib, UInt32(mib.count), procList, &bufferSize, nil, 0) < 0 {
		throw ServiceError(errno)
	}

	// Simply step through the returned bytes and lookup the data you want.
	// If the pid is 0 that means it's invalid and should be ignored.
	for index in 0...entryCount {
		guard let proc = procList?[index] else {
			continue
		}

		if proc.kp_proc.p_pid != 0 && runningPID == proc.kp_proc.p_pid {
			let comm = proc.kp_proc.p_comm
			let name = String(cString: Mirror(reflecting: comm).children.map { $0.value as! CChar })

			return (true, name, runningPID)
		}
	}

	return (false, String.empty, runningPID)
}

extension URL: Purgeable {
	public var fingerprint: String? {
		nil
	}

	// Optional: Check if the boot drive image appears to be in ASIF format.
	// We consider files with a ".asif" extension or those whose first four bytes are "shdw" as ASIF format.
	public static func isASIFDisk(filePath: String) -> Bool {
		return URL(fileURLWithPath: filePath).asifDisk
	}

	public var diskSize: UInt64 {
		var diskSize: UInt64 = 0

		if let fileSize = try? self.fileSize() {
			diskSize = fileSize
		}

		guard self.pathExtension == "img" || self.pathExtension == "asif" else {
			return diskSize
		}

		if let asifSize = self.asifDiskSize {
			diskSize = asifSize
		}

		return diskSize
	}

	// Logical size of an ASIF disk image, read from its header (https://github.com/huven/asif-format).
	// Integers are big-endian: magic "shdw" at 0x00, sector count (UInt64) at 0x30, block size (UInt16) at 0x44.
	// Logical size = sector count * block size, matching "Size Info > Total Bytes" from `diskutil image info`.
	public var asifDiskSize: UInt64? {
		guard let handle = try? FileHandle(forReadingFrom: self) else {
			return nil
		}

		defer {
			try? handle.close()
		}

		guard let header = try? handle.read(upToCount: 0x46), header.count == 0x46 else {
			return nil
		}

		guard String(bytes: header.prefix(4), encoding: .ascii) == "shdw" else {
			return nil
		}

		let sectorCount = header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x30, as: UInt64.self) }.bigEndian
		let blockSize = header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x44, as: UInt16.self) }.bigEndian

		let (size, overflow) = sectorCount.multipliedReportingOverflow(by: UInt64(blockSize))

		guard overflow == false, size > 0 else {
			return nil
		}

		return size
	}

	public var asifDisk: Bool {
		if self.pathExtension.lowercased() == "asif" {
			return true
		}

		guard let handle = try? FileHandle(forReadingFrom: self) else {
			return false
		}

		defer {
			try? handle.close()
		}

		guard let header = try? handle.read(upToCount: 4), header.count == 4 else {
			return false
		}

		return String(bytes: header, encoding: .ascii) == "shdw"
	}

	public var url: URL {
		self
	}

	public func writePID() throws {
		let pid = getpid()

		try "\(pid)".write(to: self, atomically: true, encoding: .ascii)

		// Set file mode to 0644 for the PID file
		let mode: mode_t = 0o644

		let result = self.path.withCString { cstr in
			chmod(cstr, mode)
		}

		if result != 0 {
			throw ServiceError(String(localized: "Failed to set permissions 0644 on PID file at \(self.path): errno=\(errno)"))
		}
	}

	public func readPID() -> Int32? {
		if FileManager.default.fileExists(atPath: self.absoluteURL.path) == false {
			return nil
		}

		guard let pid = try? String(contentsOf: self, encoding: .ascii) else {
			return nil
		}

		guard let pid: Int32 = Int32(pid.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			return nil
		}

		return pid
	}

	public func killPID(_ signal: Int32 = SIGTERM) -> Int32 {
		if FileManager.default.fileExists(atPath: self.absoluteURL.path) == false {
			return ENODATA
		}

		guard let pid = try? String(contentsOf: self, encoding: .ascii) else {
			return ENODATA
		}

		guard let pid: Int32 = Int32(pid.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			return EINVAL
		}

		return kill(pid, signal)
	}

	public func isPIDRunning() -> (running: Bool, processName: String, pid: Int32?) {
		if let pid = readPID() {
			do {
				return try processExist(pid_t(pid))
			} catch {
				Logger(self).error("Error checking if PID \(pid) is running: \(error)")
			}
		}

		return (false, String.empty, nil)
	}

	public func isPIDRunning(_ expectedProcessName: [String]) -> (Bool, String) {
		let pid = self.isPIDRunning()

		return (pid.0 && expectedProcessName.contains(pid.1), pid.1)
	}

	public func isPIDRunning(_ expectedProcessName: String) -> Bool {
		let pid = self.isPIDRunning()

		return pid.0 && pid.1.contains(expectedProcessName)
	}

	public func isCakedRunning() -> Bool {
		self.isPIDRunning(Home.cakedCommandName)
	}

	public typealias WaitPIDHandler = () throws -> Void

	public func waitStopped(maxRetries: Int = 10, handler: WaitPIDHandler? = nil) throws {
		var retries = 0

		if let pid = readPID() {
			while retries < maxRetries {
				if let handler = handler {
					try handler()
				}

				if FileManager.default.fileExists(atPath: self.path) == false {
					return
				}

				if let exist = try? processExist(pid_t(pid)), exist.0 == false {
					return
				}

				Thread.sleep(forTimeInterval: 1)

				retries += 1
			}

			throw ServiceError(String(localized: "PID file \(self.path) did not stopped within the expected time"))
		}
	}

	public func waitPID(maxRetries: Int = 10, handler: WaitPIDHandler? = nil) throws {
		var retries = 0

		while retries < maxRetries {
			if let handler = handler {
				try handler()
			}

			if FileManager.default.fileExists(atPath: self.path) {
				guard self.isPIDRunning().0 else {
					throw ServiceError(String(localized: "PID file exists at \(self.path) but process died"))
				}

				return
			}

			Thread.sleep(forTimeInterval: 1)

			retries += 1
		}

		throw ServiceError(String(localized: "PID file \(self.path) did not appear within the expected time"))
	}

	public static func binary(_ name: String) -> URL? {
		if let executablePath = Bundle.main.path(forAuxiliaryExecutable: name) {
			let url = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath().absoluteURL

			if FileManager.default.fileExists(atPath: url.path) {
				return url
			}
		}

		let main = Bundle.main

		let pathd = [
			main.cakedBundlePath,
			main.builtInPlugInsPath,
			main.privateFrameworksPath,
			main.sharedFrameworksPath,
			main.sharedSupportPath,
			main.resourcePath,
			ProcessInfo.processInfo.environment["PATH"],
			"/usr/bin:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/sbin:/opt/bin:/opt/sbin",
		]

		return pathd.compactMap {
			guard let path = $0 else {
				return nil
			}

			return path.split(separator: ":").compactMap { dir in
				let url: URL = URL(fileURLWithPath: String(dir)).appendingPathComponent(name, isDirectory: false).resolvingSymlinksInPath().absoluteURL

				if FileManager.default.fileExists(atPath: url.path) {
					return url
				}

				return nil
			}.first
		}.first
	}

	public var source: String {
		self.deletingLastPathComponent().lastPathComponent
	}

	public var name: String {
		self.lastPathComponent.deletingPathExtension
	}

	public var fileExists: Bool {
		guard let found = try? self.exists() else {
			return false
		}

		return found
	}

	public func exists() throws -> Bool {
		if self.isFileURL || self.scheme == "unix" || self.scheme == "vsock" {
			return FileManager.default.fileExists(atPath: self.absoluteURL.path)
		}

		throw ServiceError(String(localized: "Not a file URL: \(self.hiddenPasswordURL.absoluteString)"))
	}

	public func deleteIfFileExists() throws {
		if self.isFileURL || self.scheme == "unix" || self.scheme == "vsock" {
			if FileManager.default.fileExists(atPath: self.absoluteURL.path) {
				try FileManager.default.removeItem(at: URL(fileURLWithPath: self.absoluteURL.path))
			}
		}
	}

	public func delete() throws {
		try FileManager.default.removeItem(at: self)
	}

	public func sizeBytes() throws -> UInt64 {
		if self.isDirectory {
			var totalFileSize: UInt64 = 0

			if let fileURLs: FileManager.DirectoryEnumerator = FileManager.default.enumerator(at: self, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: .skipsHiddenFiles) {
				for case let fileURL as URL in fileURLs {
					totalFileSize += try fileURL.sizeBytes()
				}
			}

			return totalFileSize
		} else if self.isFileURL {
			guard let totalFileSize = try self.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize else {
				return 0
			}

			return UInt64(totalFileSize)
		} else {
			throw ServiceError(String(localized: "Not a file URL: \(self.hiddenPasswordURL.absoluteString)"))
		}
	}

	public func allocatedSizeBytes() throws -> UInt64 {
		if self.isDirectory {
			var totalFileAllocatedSize: UInt64 = 0

			if let fileURLs: FileManager.DirectoryEnumerator = FileManager.default.enumerator(at: self, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: .skipsHiddenFiles) {
				for case let fileURL as URL in fileURLs {
					totalFileAllocatedSize += try fileURL.allocatedSizeBytes()
				}
			}

			return totalFileAllocatedSize
		} else if self.isFileURL {
			guard let totalFileAllocatedSize = try self.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize else {
				return 0
			}

			return UInt64(totalFileAllocatedSize)
		} else {
			throw ServiceError(String(localized: "Not a file URL: \(self.hiddenPasswordURL.absoluteString)"))
		}
	}

	public func creationDate() throws -> Date {
		let attrs = try self.resourceValues(forKeys: [.creationDateKey])
		guard let date = attrs.creationDate else {
			throw ServiceError(String(localized: "Creation date not available for: \(self.hiddenPasswordURL.absoluteString)"))
		}
		return date
	}

	public func updatedDate() throws -> Date {
		let attrs = try self.resourceValues(forKeys: [.contentModificationDateKey])
		guard let date = attrs.contentModificationDate else {
			throw ServiceError(String(localized: "Modification date not available for: \(self.hiddenPasswordURL.absoluteString)"))
		}
		return date
	}

	public func accessDate() throws -> Date {
		let attrs = try self.resourceValues(forKeys: [.contentAccessDateKey])
		guard let date = attrs.contentAccessDate else {
			throw ServiceError(String(localized: "Access date not available for: \(self.hiddenPasswordURL.absoluteString)"))
		}
		return date
	}

	public func updateAccessDate(_ accessDate: Date = Date()) throws {
		let attrs = try self.resourceValues(forKeys: [.contentModificationDateKey])
		guard let modificationDate = attrs.contentModificationDate else {
			throw ServiceError(String(localized: "Modification date not available for: \(self.hiddenPasswordURL.absoluteString)"))
		}

		let times = [accessDate.asTimeval(), modificationDate.asTimeval()]
		let ret = utimes(path, times)
		if ret != 0 {
			let details = Errno(rawValue: CInt(errno))

			throw ServiceError(String(localized: "utimes(2) failed: \(details.description)"))
		}
	}
}

extension DirectorySharingAttachments {
	public var multipleDirectoryShares: VZDirectoryShare {
		var directories: [String: VZSharedDirectory] = [:]

		self.forEach {
			if let config = $0.configuration {
				directories[$0.human] = config
			}
		}

		return VZMultipleDirectoryShare(directories: directories)
	}

	public var singleDirectoryShares: [VZDirectoryShare] {
		self.compactMap { mount in
			VZSingleDirectoryShare(directory: .init(url: mount.path, readOnly: mount.readOnly))
		}
	}

	public func directorySharingAttachments(os: VirtualizedOS) -> [VZDirectorySharingDeviceConfiguration] {
		if self.isEmpty {
			return []
		}

		if os == .darwin {
			let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag)

			sharingDevice.share = self.multipleDirectoryShares

			return [sharingDevice]
		}

		return self.compactMap { mount in
			let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: mount.name)

			sharingDevice.share = VZSingleDirectoryShare(directory: .init(url: mount.path, readOnly: mount.readOnly))

			return sharingDevice
		}
	}
}

extension Socket {
	static func create(host: String, port: Int) throws -> Socket {
		let signature = try Socket.Signature(protocolFamily: .inet, socketType: .stream, proto: .tcp, hostname: "localhost", port: Int32(port))!

		return try Socket.create(connectedUsing: signature)
	}
}

public struct Utilities {
	public static let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
	public static let keychainID = "com.aldunelabs.caker"

	public static func cakeagentBinary(os: VirtualizedOS, runMode: Utils.RunMode, observer: ProgressObserver? = nil) async throws -> URL {
		let arch = Architecture.current().rawValue
		let os = os.rawValue
		let home: Home = try Home(runMode: runMode)
		let localAgent = home.agentDirectory.appendingPathComponent("cakeagent-\(CAKEAGENT_SNAPSHOT)-\(os)-\(arch)", isDirectory: false)

		if FileManager.default.fileExists(atPath: localAgent.path) == false {
			guard let remoteURL = URL(string: "https://github.com/Fred78290/cakeagent/releases/download/SNAPSHOT-\(CAKEAGENT_SNAPSHOT)/cakeagent-\(os)-\(arch)") else {
				throw ServiceError(String(localized: "unable to get remote cakeagent"))
			}

			try await Curl(fromURL: remoteURL).get(store: localAgent)
		}

		return localAgent
	}

	public static func createCakeAgentClient(on: EventLoopGroup, runMode: Utils.RunMode, vmURL: URL, connectionTimeout: Int64 = 30, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentClient {
		return try createCakeAgentClient(on: on, runMode: runMode, location: try VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode).validate(), retries: retries)
	}

	public static func createCakeAgentClient(on: EventLoopGroup, runMode: Utils.RunMode, location: VMLocation, connectionTimeout: Int64 = 30, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentClient {
		return try createCakeAgentClient(on: on, runMode: runMode, listeningAddress: location.agentURL, retries: retries)
	}

	public static func createCakeAgentClient(on: EventLoopGroup, runMode: Utils.RunMode, name: String, connectionTimeout: Int64 = 30, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentClient {
		return try createCakeAgentClient(on: on, runMode: runMode, location: try StorageLocation(runMode: runMode).find(name), retries: retries)
	}

	public static func createCakeAgentClient(on: EventLoopGroup, runMode: Utils.RunMode, listeningAddress: URL, connectionTimeout: Int64 = 30, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentClient {
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)

		return try CakeAgentHelper.createClient(
			on: on,
			listeningAddress: listeningAddress,
			connectionTimeout: connectionTimeout,
			caCert: certificates.caCertURL.path,
			tlsCert: certificates.clientCertURL.path,
			tlsKey: certificates.clientKeyURL.path,
			retries: retries
		)
	}

	public static func waitPortReady(host: String = String.empty, port: Int, timeout: TimeInterval = 60) -> Bool {
		let start = Date()

		while Date().timeIntervalSince(start) < timeout {
			do {
				let socket = try Socket.create(host: host, port: port)
				socket.close()
				return true
			} catch {
			}

			Thread.sleep(forTimeInterval: 0.05)
		}

		return false
	}

	public static func findFreePort(_ address: String = "127.0.0.1") throws -> Int {
		let socketFD = socket(AF_INET, SOCK_STREAM, 0)

		if socketFD == -1 {
			throw ServiceError(errno)
		}

		defer {
			close(socketFD)
		}

		var addr = sockaddr_in()

		addr.sin_family = sa_family_t(AF_INET)
		addr.sin_addr = in_addr(s_addr: inet_addr(address))
		addr.sin_port = in_port_t(0).bigEndian

		let bindResult = withUnsafePointer(to: &addr) {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
				bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
			}
		}

		guard bindResult == 0 else {
			throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
		}

		var len = socklen_t(MemoryLayout<sockaddr_in>.size)

		getsockname(
			socketFD,
			withUnsafeMutablePointer(to: &addr) {
				$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
					UnsafeMutablePointer($0)
				}
			}, &len)

		return Int(UInt16(bigEndian: addr.sin_port))
	}

	public static func environment(runMode: Utils.RunMode) throws -> [String: String] {
		var environment = ProcessInfo.processInfo.environment
		let home = try Utils.getHome(runMode: runMode)

		environment["TART_HOME"] = home.path

		if environment["CAKE_HOME"] == nil {
			environment["CAKE_HOME"] = home.path
		}

		return environment
	}

	// MARK: - Async helpers
	/// Load raw Data from a URL. If the URL is a file URL, it uses async file IO; otherwise it performs a network request.
	@discardableResult
	public static func loadData(_ url: URL, timeout: TimeInterval = 60) async throws -> Data {
		if url.isFileURL {
			// Async file read on a background thread
			return try await withCheckedThrowingContinuation { continuation in
				DispatchQueue.global(qos: .utility).async {
					do {
						let data = try Data(contentsOf: url)
						continuation.resume(returning: data)
					} catch {
						continuation.resume(throwing: error)
					}
				}
			}
		} else {
			var request = URLRequest(url: url)
			request.timeoutInterval = timeout
			let (data, response) = try await URLSession.shared.data(for: request)
			if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
				throw ServiceError(String(localized: "HTTP error: \(http.statusCode) for URL: \(url.hiddenPasswordURL.absoluteString)"))
			}
			return data
		}
	}

	/// Decode JSON from a URL into a Decodable type using `loadData(from:)`.
	public static func loadJSON<T: Decodable>(from url: URL, as type: T.Type = T.self, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
		let data = try await loadData(url)
		do {
			return try decoder.decode(T.self, from: data)
		} catch {
			throw ServiceError(String(localized: "JSON decode failed for URL: \(url.hiddenPasswordURL.absoluteString) with error: \(error.reason)"))
		}
	}
}

extension Thread {
	public static var currentThread: Thread {
		Thread.current
	}
}

extension Utilities {
	public static var isRunningWithGUI: Bool {
		NSApp != nil
	}

	public static func mountedVolumes(forDisk diskPath: String) -> [String] {
		var fsptr: UnsafeMutablePointer<statfs>?
		let count = getmntinfo(&fsptr, MNT_NOWAIT)
		guard count > 0, let fsptr else { return [] }

		var mounted: [String] = []
		for i in 0..<Int(count) {
			let fs = fsptr[i]
			let fromName = withUnsafeBytes(of: fs.f_mntfromname) { ptr in
				String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
			}
			let isPartitionOfDisk = fromName == diskPath || (fromName.hasPrefix(diskPath) && fromName.dropFirst(diskPath.count).first == "s")
			if isPartitionOfDisk {
				let onName = withUnsafeBytes(of: fs.f_mntonname) { ptr in
					String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
				}
				mounted.append(onName)
			}
		}
		return mounted
	}

	public static func unmountDisk(_ diskPath: String) throws {
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
		process.arguments = ["unmountDisk", diskPath]

		let pipe = Pipe()
		process.standardOutput = pipe
		process.standardError = pipe

		try process.run()
		process.waitUntilExit()

		if process.terminationStatus != 0 {
			let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
			throw ValidationError(String(localized: "Failed to unmount \(diskPath): \(output.trimmingCharacters(in: .whitespacesAndNewlines))"))
		}
	}

	public static func confirmUnmount(diskPath: String, volumes: [String]) throws -> Bool {
		guard isRunningWithGUI else {
			throw ValidationError(String(localized: "\(diskPath) has mounted volumes. Please unmount them before use."))
		}

		let alert = NSAlert()

		alert.messageText = String(localized: "Disk has mounted volumes")
		alert.informativeText = String(localized: "\(diskPath) has the following mounted volumes:\n\(volumes.joined(separator: "\n"))\n\nDo you want to unmount them to use this disk with the virtual machine?")
		alert.alertStyle = .warning
		alert.addButton(withTitle: String(localized: "Unmount"))
		alert.addButton(withTitle: String(localized: "Cancel"))
		return alert.runModal() == .alertFirstButtonReturn
	}

}
