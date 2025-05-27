// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016, 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import Darwin
import Foundation
import Synchronization

extension NSObject {
	static func unretainedReference<R: NSObject>(_ value: UnsafeRawPointer) -> R {
		return unsafeBitCast(value, to: R.self)
	}

	static func unretainedReference<R: NSObject>(_ value: UnsafeMutableRawPointer) -> R {
		return unretainedReference(UnsafeRawPointer(value))
	}

	func withRetainedReference<T, R>(_ work: (UnsafePointer<T>) -> R) -> R {
		let selfPtr = Unmanaged.passRetained(self).toOpaque().assumingMemoryBound(to: T.self)
		return work(selfPtr)
	}

	func withRetainedReference<T, R>(_ work: (UnsafeMutablePointer<T>) -> R) -> R {
		let selfPtr = Unmanaged.passRetained(self).toOpaque().assumingMemoryBound(to: T.self)
		return work(selfPtr)
	}

	func withUnretainedReference<T, R>(_ work: (UnsafePointer<T>) -> R) -> R {
		let selfPtr = Unmanaged.passUnretained(self).toOpaque().assumingMemoryBound(to: T.self)
		return work(selfPtr)
	}

	func withUnretainedReference<T, R>(_ work: (UnsafeMutablePointer<T>) -> R) -> R {
		let selfPtr = Unmanaged.passUnretained(self).toOpaque().assumingMemoryBound(to: T.self)
		return work(selfPtr)
	}
}

extension NSLock {
	internal func synchronized<T>(_ closure: () -> T) -> T {
		self.lock()
		defer { self.unlock() }
		return closure()
	}
}

extension ProcessWithSharedFileHandle {
	public enum TerminationReason: Int, Sendable {
		case exit
		case uncaughtSignal
	}
}

internal func _NSErrorWithErrno(_ posixErrno: Int32, reading: Bool, path: String? = nil, url: URL? = nil, extraUserInfo: [String: Any]? = nil) -> NSError {
	var cocoaError: CocoaError.Code
	if reading {
		switch posixErrno {
		case EFBIG: cocoaError = .fileReadTooLarge
		case ENOENT: cocoaError = .fileReadNoSuchFile
		case EPERM, EACCES: cocoaError = .fileReadNoPermission
		case ENAMETOOLONG: cocoaError = .fileReadUnknown
		default: cocoaError = .fileReadUnknown
		}
	} else {
		switch posixErrno {
		case ENOENT: cocoaError = .fileNoSuchFile
		case EPERM, EACCES: cocoaError = .fileWriteNoPermission
		case ENAMETOOLONG: cocoaError = .fileWriteInvalidFileName
		case EDQUOT, ENOSPC: cocoaError = .fileWriteOutOfSpace
		case EROFS: cocoaError = .fileWriteVolumeReadOnly
		case EEXIST: cocoaError = .fileWriteFileExists
		default: cocoaError = .fileWriteUnknown
		}
	}

	var userInfo = extraUserInfo ?? [String: Any]()
	if let path = path {
		userInfo[NSFilePathErrorKey] = path
	} else if let url = url {
		userInfo[NSURLErrorKey] = url
	}

	userInfo[NSUnderlyingErrorKey] = NSError(domain: NSPOSIXErrorDomain, code: Int(posixErrno))

	return NSError(domain: NSCocoaErrorDomain, code: cocoaError.rawValue, userInfo: userInfo)
}
typealias CFPosixSpawnFileActionsRef = UnsafeMutablePointer<posix_spawn_file_actions_t?>
typealias CFPosixSpawnAttrRef = UnsafeMutablePointer<posix_spawnattr_t?>

private func CFPosixSpawnFileActionsAlloc() -> CFPosixSpawnFileActionsRef {
	let p = malloc(MemoryLayout.size(ofValue: MemoryLayout<posix_spawn_file_actions_t>.size))
	let ret = p!.assumingMemoryBound(to: posix_spawn_file_actions_t?.self)

	return ret
}

private func CFPosixSpawnFileActionsDealloc(_ file_actions: CFPosixSpawnFileActionsRef) {
	free(file_actions)
}

@discardableResult private func CFPosixSpawnFileActionsInit(_ file_actions: CFPosixSpawnFileActionsRef) -> Int32 {
	return posix_spawn_file_actions_init(file_actions)
}

@discardableResult private func CFPosixSpawnFileActionsDestroy(_ file_actions: CFPosixSpawnFileActionsRef) -> Int32 {
	return posix_spawn_file_actions_destroy(file_actions)
}

@discardableResult private func CFPosixSpawnFileActionsAddDup2(_ file_actions: CFPosixSpawnFileActionsRef, _ filedes: Int32, _ newfiledes: Int32) -> Int32 {
	return posix_spawn_file_actions_adddup2(file_actions, filedes, newfiledes)
}

@discardableResult private func CFPosixSpawnFileActionsAddClose(_ file_actions: CFPosixSpawnFileActionsRef, _ filedes: Int32) -> Int32 {
	return posix_spawn_file_actions_addclose(file_actions, filedes)
}

@discardableResult private func CFPosixSpawn(
	_ pid: UnsafeMutablePointer<pid_t>, _ path: String, _ file_actions: CFPosixSpawnFileActionsRef, _ attrp: CFPosixSpawnAttrRef?, _ argv: UnsafePointer<UnsafeMutablePointer<CChar>?>!, _ envp: UnsafePointer<UnsafeMutablePointer<CChar>?>!
) -> Int32 {
	return posix_spawn(pid, path, file_actions, attrp, argv, envp)
}

private func WIFEXITED(_ status: Int32) -> Bool {
	return _WSTATUS(status) == 0
}

private func _WSTATUS(_ status: Int32) -> Int32 {
	return status & 0x7f
}

private func WIFSIGNALED(_ status: Int32) -> Bool {
	return (_WSTATUS(status) != 0) && (_WSTATUS(status) != 0x7f)
}

private func WEXITSTATUS(_ status: Int32) -> Int32 {
	return (status >> 8) & 0xff
}

private func WTERMSIG(_ status: Int32) -> Int32 {
	return status & 0x7f
}

// Protected by 'Once' below in `setup`
private nonisolated(unsafe) var managerThreadRunLoop: RunLoop? = nil

// Protected by managerThreadRunLoopIsRunningCondition
private nonisolated(unsafe) var managerThreadRunLoopIsRunning = false
private let managerThreadRunLoopIsRunningCondition = NSCondition()

internal let kCFSocketNoCallBack: CFOptionFlags = 0  // .noCallBack cannot be used because empty option flags are imported as unavailable.
internal let kCFSocketAcceptCallBack = CFSocketCallBackType.acceptCallBack.rawValue
internal let kCFSocketDataCallBack = CFSocketCallBackType.dataCallBack.rawValue

internal let kCFSocketSuccess = CFSocketError.success
internal let kCFSocketError = CFSocketError.error
internal let kCFSocketTimeout = CFSocketError.timeout

extension CFSocketError {
	init?(_ value: CFIndex) {
		self.init(rawValue: value)
	}
}

private func emptyRunLoopCallback(_ context: UnsafeMutableRawPointer?) {}

// Retain method for run loop source
private func runLoopSourceRetain(_ pointer: UnsafeRawPointer?) -> UnsafeRawPointer? {
	let ref = Unmanaged<AnyObject>.fromOpaque(pointer!).takeUnretainedValue()
	let retained = Unmanaged<AnyObject>.passRetained(ref)
	return unsafeBitCast(retained, to: UnsafeRawPointer.self)
}

// Release method for run loop source
private func runLoopSourceRelease(_ pointer: UnsafeRawPointer?) {
	Unmanaged<AnyObject>.fromOpaque(pointer!).release()
}

// Equal method for run loop source

private func runloopIsEqual(_ a: UnsafeRawPointer?, _ b: UnsafeRawPointer?) -> DarwinBoolean {

	let unmanagedrunLoopA = Unmanaged<AnyObject>.fromOpaque(a!)
	guard let runLoopA = unmanagedrunLoopA.takeUnretainedValue() as? RunLoop else {
		return false
	}

	let unmanagedRunLoopB = Unmanaged<AnyObject>.fromOpaque(a!)
	guard let runLoopB = unmanagedRunLoopB.takeUnretainedValue() as? RunLoop else {
		return false
	}

	guard runLoopA == runLoopB else {
		return false
	}

	return true
}

// Equal method for process in run loop source
private func processIsEqual(_ a: UnsafeRawPointer?, _ b: UnsafeRawPointer?) -> DarwinBoolean {

	let unmanagedProcessA = Unmanaged<AnyObject>.fromOpaque(a!)
	guard let processA = unmanagedProcessA.takeUnretainedValue() as? ProcessWithSharedFileHandle else {
		return false
	}

	let unmanagedProcessB = Unmanaged<AnyObject>.fromOpaque(a!)
	guard let processB = unmanagedProcessB.takeUnretainedValue() as? ProcessWithSharedFileHandle else {
		return false
	}

	guard processA == processB else {
		return false
	}

	return true
}

open class ProcessWithSharedFileHandle: NSObject, @unchecked Sendable {
	private static func setup() {
		struct Once {
			static var done = false
			static let lock = NSLock()
		}

		Once.lock.synchronized {
			if !Once.done {
				let thread = Thread {
					managerThreadRunLoop = RunLoop.current
					var emptySourceContext = CFRunLoopSourceContext()
					emptySourceContext.version = 0
					emptySourceContext.retain = runLoopSourceRetain
					emptySourceContext.release = runLoopSourceRelease
					emptySourceContext.equal = runloopIsEqual
					emptySourceContext.perform = emptyRunLoopCallback
					managerThreadRunLoop!.withUnretainedReference {
						(refPtr: UnsafeMutablePointer<UInt8>) in
						emptySourceContext.info = UnsafeMutableRawPointer(refPtr)
					}

					CFRunLoopAddSource(managerThreadRunLoop?.getCFRunLoop(), CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &emptySourceContext), CFRunLoopMode.defaultMode)

					managerThreadRunLoopIsRunningCondition.lock()

					CFRunLoopPerformBlock(managerThreadRunLoop?.getCFRunLoop(), "kCFRunLoopDefaultMode" as CFString) {
						managerThreadRunLoopIsRunning = true
						managerThreadRunLoopIsRunningCondition.broadcast()
						managerThreadRunLoopIsRunningCondition.unlock()
					}

					managerThreadRunLoop?.run()
					fatalError("ProcessWithSharedFileHandle manager run loop exited unexpectedly; it should run forever once initialized")
				}
				thread.start()
				managerThreadRunLoopIsRunningCondition.lock()
				while managerThreadRunLoopIsRunning == false {
					managerThreadRunLoopIsRunningCondition.wait()
				}
				managerThreadRunLoopIsRunningCondition.unlock()
				Once.done = true
			}
		}
	}

	// Create an ProcessWithSharedFileHandle which can be run at a later time
	// An ProcessWithSharedFileHandle can only be run once. Subsequent attempts to
	// run an ProcessWithSharedFileHandle will raise.
	// Upon process death a notification will be sent
	//   { Name = ProcessDidTerminateNotification; object = process; }
	//

	public override init() {

	}

	// These properties can only be set before a launch.
	private var _executable: URL?
	open var executableURL: URL? {
		get { _executable }
		set {
			guard let url = newValue, url.isFileURL else {
				fatalError("must provide a launch path")
			}
			_executable = url
		}
	}

	private var _currentDirectoryPath = FileManager.default.currentDirectoryPath
	open var currentDirectoryURL: URL? {
		get { _currentDirectoryPath == "" ? nil : URL(fileURLWithPath: _currentDirectoryPath, isDirectory: true) }
		set {
			// Setting currentDirectoryURL to nil resets to the current directory
			if let url = newValue {
				guard url.isFileURL else { fatalError("non-file URL argument") }
				_currentDirectoryPath = url.path
			} else {
				_currentDirectoryPath = FileManager.default.currentDirectoryPath
			}
		}
	}

	open var arguments: [String]?
	open var environment: [String: String]?  // if not set, use current

	@available(*, deprecated, renamed: "executableURL")
	open var launchPath: String? {
		get { return executableURL?.path }
		set { executableURL = (newValue != nil) ? URL(fileURLWithPath: newValue!) : nil }
	}

	@available(*, deprecated, renamed: "currentDirectoryURL")
	open var currentDirectoryPath: String {
		get { _currentDirectoryPath }
		set { _currentDirectoryPath = newValue }
	}

	// Standard I/O channels; could be either a FileHandle or a Pipe

	open var standardInput: Any? = FileHandle.standardInput {
		willSet {
			precondition(
				newValue is Pipe || newValue is FileHandle || newValue == nil,
				"standardInput must be either Pipe or FileHandle")
		}
	}

	open var standardOutput: Any? = FileHandle.standardOutput {
		willSet {
			precondition(
				newValue is Pipe || newValue is FileHandle || newValue == nil,
				"standardOutput must be either Pipe or FileHandle")
		}
	}

	open var standardError: Any? = FileHandle.standardError {
		willSet {
			precondition(
				newValue is Pipe || newValue is FileHandle || newValue == nil,
				"standardError must be either Pipe or FileHandle")
		}
	}

	open var sharedFileHandles: [FileHandle]? = nil

	private class NonexportedCFRunLoopSourceContextStorage {
		internal var value: CFRunLoopSourceContext?
	}

	private class NonexportedCFRunLoopSourceStorage {
		internal var value: CFRunLoopSource?
	}

	private var _runLoopSourceContextStorage = NonexportedCFRunLoopSourceContextStorage()
	private final var runLoopSourceContext: CFRunLoopSourceContext? {
		get { _runLoopSourceContextStorage.value }
		set { _runLoopSourceContextStorage.value = newValue }
	}

	private var _runLoopSourceStorage = NonexportedCFRunLoopSourceStorage()
	private final var runLoopSource: CFRunLoopSource? {
		get { _runLoopSourceStorage.value }
		set { _runLoopSourceStorage.value = newValue }
	}

	fileprivate weak var runLoop: RunLoop? = nil

	private var processLaunchedCondition = NSCondition()

	// Actions

	@available(*, deprecated, renamed: "run")
	open func launch() {
		do {
			try run()
		} catch let nserror as NSError {
			if let path = nserror.userInfo[NSFilePathErrorKey] as? String, path == currentDirectoryPath {
				// Foundation throws an NSException when changing the working directory fails,
				// and unfortunately launch() is not marked `throws`, so we get away with a
				// fatalError.
				switch CocoaError.Code(rawValue: nserror.code) {
				case .fileReadNoSuchFile:
					fatalError("ProcessWithSharedFileHandle: The specified working directory does not exist.")
				case .fileReadNoPermission:
					fatalError("ProcessWithSharedFileHandle: The specified working directory cannot be accessed.")
				default:
					fatalError("ProcessWithSharedFileHandle: The specified working directory cannot be set.")
				}
			} else {
				fatalError(String(describing: nserror))
			}
		} catch {
			fatalError(String(describing: error))
		}
	}

	open func run() throws {

		func _throwIfPosixError(_ posixErrno: Int32) throws {
			if posixErrno != 0 {
				// When this is called, self.executableURL is already known to be non-nil
				let userInfo: [String: Any] = [NSURLErrorKey: self.executableURL!]
				throw NSError(domain: NSPOSIXErrorDomain, code: Int(posixErrno), userInfo: userInfo)
			}
		}

		self.processLaunchedCondition.lock()
		defer {
			self.processLaunchedCondition.broadcast()
			self.processLaunchedCondition.unlock()
		}

		// Dispatch the manager thread if it isn't already running
		ProcessWithSharedFileHandle.setup()

		// Check that the process isnt run more than once
		guard hasStarted == false && hasFinished == false else {
			throw NSError(domain: NSCocoaErrorDomain, code: NSExecutableLoadError)
		}

		// Ensure that the launch path is set
		guard let launchPath = self.executableURL?.path else {
			throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
		}

		// Initial checks that the launchPath points to an executable file. posix_spawn()
		// can return success even if executing the program fails, eg fork() works but execve()
		// fails, so try and check as much as possible beforehand.
		var fsRep = FileManager.default.fileSystemRepresentation(withPath: launchPath)

		var statInfo = stat()
		guard stat(fsRep, &statInfo) == 0 else {
			throw _NSErrorWithErrno(errno, reading: true, path: launchPath)
		}

		let isRegularFile: Bool = statInfo.st_mode & S_IFMT == S_IFREG
		guard isRegularFile == true else {
			throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
		}

		guard access(fsRep, X_OK) == 0 else {
			throw _NSErrorWithErrno(errno, reading: true, path: launchPath)
		}

		// Convert the arguments array into a posix_spawn-friendly format

		var args = [launchPath]
		if let arguments = self.arguments {
			args.append(contentsOf: arguments)
		}

		let argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?> = args.withUnsafeBufferPointer {
			let array: UnsafeBufferPointer<String> = $0
			let buffer = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: array.count + 1)
			buffer.initialize(from: array.map { $0.withCString(strdup) }, count: array.count)
			buffer[array.count] = nil
			return buffer
		}

		defer {
			for arg in argv..<argv + args.count {
				free(UnsafeMutableRawPointer(arg.pointee))
			}
			argv.deallocate()
		}

		var env: [String: String]
		if let e = environment {
			env = e
		} else {
			env = ProcessInfo.processInfo.environment
		}

		let nenv = env.count
		let envp = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: 1 + nenv)
		envp.initialize(from: env.map { strdup("\($0)=\($1)") }, count: nenv)
		envp[env.count] = nil

		defer {
			for pair in envp..<envp + env.count {
				free(UnsafeMutableRawPointer(pair.pointee))
			}
			envp.deallocate()
		}

		var taskSocketPair: [Int32] = [0, 0]
		socketpair(AF_UNIX, SOCK_STREAM, 0, &taskSocketPair)
		var context = CFSocketContext()
		context.version = 0
		context.retain = runLoopSourceRetain
		context.release = runLoopSourceRelease
		context.info = Unmanaged.passUnretained(self).toOpaque()

		let socket = CFSocketCreateWithNative(
			nil, taskSocketPair[0], CFOptionFlags(kCFSocketDataCallBack),
			{
				(socket, type, address, data, info) in

				let process: ProcessWithSharedFileHandle = NSObject.unretainedReference(info!)

				process.processLaunchedCondition.lock()
				while process.isRunning == false {
					process.processLaunchedCondition.wait()
				}

				process.processLaunchedCondition.unlock()

				var exitCode: Int32 = 0
				var waitResult: Int32 = 0

				repeat {
					waitResult = waitpid(process.processIdentifier, &exitCode, 0)
				} while (waitResult == -1) && (errno == EINTR)

				if WIFSIGNALED(exitCode) {
					process._terminationStatus = WTERMSIG(exitCode)
					process._terminationReason = .uncaughtSignal
				} else {
					assert(WIFEXITED(exitCode))
					process._terminationStatus = WEXITSTATUS(exitCode)
					process._terminationReason = .exit
				}

				// Signal waitUntilExit() and optionally invoke termination handler.
				process.terminateRunLoop()

				CFSocketInvalidate(socket)

			}, &context)

		CFSocketSetSocketFlags(socket, CFOptionFlags(kCFSocketCloseOnInvalidate))

		let source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0)
		CFRunLoopAddSource(managerThreadRunLoop?.getCFRunLoop(), source, CFRunLoopMode.defaultMode)

		let fileActions = CFPosixSpawnFileActionsAlloc()
		defer {
			CFPosixSpawnFileActionsDestroy(fileActions)
			CFPosixSpawnFileActionsDealloc(fileActions)
		}
		try _throwIfPosixError(CFPosixSpawnFileActionsInit(fileActions))

		// File descriptors to duplicate in the child process. This allows
		// output redirection to NSPipe or NSFileHandle.
		var adddup2 = [Int32: Int32]()

		// File descriptors to close in the child process. A set so that
		// shared pipes only get closed once. Would result in EBADF on OSX
		// otherwise.
		var addclose = Set<Int32>()

		var _devNull: FileHandle?
		func devNullFd() throws -> Int32 {
			_devNull = try _devNull ?? FileHandle(forUpdating: URL(fileURLWithPath: "/dev/null", isDirectory: false))
			return _devNull!.fileDescriptor
		}

		switch standardInput {
		case let pipe as Pipe:
			adddup2[STDIN_FILENO] = pipe.fileHandleForReading.fileDescriptor
			addclose.insert(pipe.fileHandleForWriting.fileDescriptor)

		// nil or NullDevice map to /dev/null
		case let handle as FileHandle where handle === FileHandle.nullDevice: fallthrough
		case .none:
			adddup2[STDIN_FILENO] = try devNullFd()

		// No need to dup stdin to stdin
		//case let handle as FileHandle where handle === FileHandle.standardInput: break

		case let handle as FileHandle:
			adddup2[STDIN_FILENO] = handle.fileDescriptor

		default: break
		}

		switch standardOutput {
		case let pipe as Pipe:
			adddup2[STDOUT_FILENO] = pipe.fileHandleForWriting.fileDescriptor
			addclose.insert(pipe.fileHandleForReading.fileDescriptor)

		// nil or NullDevice map to /dev/null
		case let handle as FileHandle where handle === FileHandle.nullDevice: fallthrough
		case .none:
			adddup2[STDOUT_FILENO] = try devNullFd()

		// No need to dup stdout to stdout
		//case let handle as FileHandle where handle === FileHandle.standardOutput: break

		case let handle as FileHandle:
			adddup2[STDOUT_FILENO] = handle.fileDescriptor

		default: break
		}

		switch standardError {
		case let pipe as Pipe:
			adddup2[STDERR_FILENO] = pipe.fileHandleForWriting.fileDescriptor
			addclose.insert(pipe.fileHandleForReading.fileDescriptor)

		// nil or NullDevice map to /dev/null
		case let handle as FileHandle where handle === FileHandle.nullDevice: fallthrough
		case .none:
			adddup2[STDERR_FILENO] = try devNullFd()

		// No need to dup stderr to stderr
		//case let handle as FileHandle where handle === FileHandle.standardError: break

		case let handle as FileHandle:
			adddup2[STDERR_FILENO] = handle.fileDescriptor

		default: break
		}

		if let sharedFileHandles {
			_ = sharedFileHandles.compactMap {
				adddup2[$0.fileDescriptor] = $0.fileDescriptor
			}
		}

		for (new, old) in adddup2 {
			try _throwIfPosixError(CFPosixSpawnFileActionsAddDup2(fileActions, old, new))
		}

		for fd in addclose.filter({ $0 >= 0 }) {
			try _throwIfPosixError(CFPosixSpawnFileActionsAddClose(fileActions, fd))
		}

		var spawnAttrs: posix_spawnattr_t? = nil

		try _throwIfPosixError(posix_spawnattr_init(&spawnAttrs))
		try _throwIfPosixError(posix_spawnattr_setflags(&spawnAttrs, .init(POSIX_SPAWN_SETPGROUP)))
		#if canImport(Darwin)
			try _throwIfPosixError(posix_spawnattr_setflags(&spawnAttrs, .init(POSIX_SPAWN_CLOEXEC_DEFAULT)))
		#else
			// POSIX_SPAWN_CLOEXEC_DEFAULT is an Apple extension so emulate it.
			for fd in 3...findMaximumOpenFD() {
				guard adddup2[fd] == nil && !addclose.contains(fd) && fd != taskSocketPair[1] else {
					continue  // Do not double-close descriptors, or close those pertaining to Pipes or FileHandles we want inherited.
				}
				try _throwIfPosixError(CFPosixSpawnFileActionsAddClose(fileActions, fd))
			}
		#endif

		let fileManager = FileManager()
		let previousDirectoryPath = fileManager.currentDirectoryPath
		if let dir = currentDirectoryURL?.path, !fileManager.changeCurrentDirectoryPath(dir) {
			throw _NSErrorWithErrno(errno, reading: true, url: currentDirectoryURL)
		}

		defer {
			// Reset the previous working directory path.
			fileManager.changeCurrentDirectoryPath(previousDirectoryPath)
		}

		// Launch
		var pid = pid_t()

		fsRep = FileManager.default.fileSystemRepresentation(withPath: launchPath)
		guard posix_spawn(&pid, fsRep, fileActions, &spawnAttrs, argv, envp) == 0 else {
			throw _NSErrorWithErrno(errno, reading: true, path: launchPath)
		}

		posix_spawnattr_destroy(&spawnAttrs)

		// Close the write end of the input and output pipes.
		if let pipe = standardInput as? Pipe {
			pipe.fileHandleForReading.closeFile()
		}
		if let pipe = standardOutput as? Pipe {
			pipe.fileHandleForWriting.closeFile()
		}
		if let pipe = standardError as? Pipe {
			pipe.fileHandleForWriting.closeFile()
		}

		close(taskSocketPair[1])

		self.runLoop = RunLoop.current
		self.runLoopSourceContext = CFRunLoopSourceContext(
			version: 0,
			info: Unmanaged.passUnretained(self).toOpaque(),
			retain: { return runLoopSourceRetain($0) },
			release: { runLoopSourceRelease($0) },
			copyDescription: nil,
			equal: { return processIsEqual($0, $1) },
			hash: nil,
			schedule: nil,
			cancel: nil,
			perform: { emptyRunLoopCallback($0) })
		self.runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &runLoopSourceContext!)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.defaultMode)

		isRunning = true

		self.processIdentifier = pid
	}

	open func interrupt() {
		precondition(hasStarted, "task not launched")
		kill(processIdentifier, SIGINT)
	}

	open func terminate() {
		precondition(hasStarted, "task not launched")
		kill(processIdentifier, SIGTERM)
	}

	// Every suspend() has to be balanced with a resume() so keep a count of both.
	private var suspendCount = 0

	open func suspend() -> Bool {
		if kill(processIdentifier, SIGSTOP) == 0 {
			suspendCount += 1
			return true
		} else {
			return false
		}
	}

	open func resume() -> Bool {
		var success: Bool = true
		if suspendCount == 1 {
			success = kill(processIdentifier, SIGCONT) == 0
		}
		if success {
			suspendCount -= 1
		}
		return success
	}

	// status
	open private(set) var processIdentifier: Int32 = 0
	open private(set) var isRunning: Bool = false
	private var hasStarted: Bool { return processIdentifier > 0 }
	private var hasFinished: Bool { return !isRunning && processIdentifier > 0 }

	private var _terminationStatus: Int32 = 0
	public var terminationStatus: Int32 {
		precondition(hasStarted, "task not launched")
		precondition(hasFinished, "task still running")
		return _terminationStatus
	}

	private var _terminationReason: TerminationReason = .exit
	public var terminationReason: TerminationReason {
		precondition(hasStarted, "task not launched")
		precondition(hasFinished, "task still running")
		return _terminationReason
	}

	/*
	 A block to be invoked when the process underlying the ProcessWithSharedFileHandle terminates.  Setting the block to nil is valid, and stops the previous block from being invoked, as long as it hasn't started in any way.  The ProcessWithSharedFileHandle is passed as the argument to the block so the block does not have to capture, and thus retain, it.  The block is copied when set.  Only one termination handler block can be set at any time.  The execution context in which the block is invoked is undefined.  If the ProcessWithSharedFileHandle has already finished, the block is executed immediately/soon (not necessarily on the current thread).  If a terminationHandler is set on an ProcessWithSharedFileHandle, the ProcessDidTerminateNotification notification is not posted for that process.  Also note that -waitUntilExit won't wait until the terminationHandler has been fully executed.  You cannot use this property in a concrete subclass of ProcessWithSharedFileHandle which hasn't been updated to include an implementation of the storage and use of it.
	 */
	open var terminationHandler: (@Sendable (ProcessWithSharedFileHandle) -> Void)?
	open var qualityOfService: QualityOfService = .default  // read-only after the process is launched

	open class func run(_ url: URL, arguments: [String], terminationHandler: (@Sendable (ProcessWithSharedFileHandle) -> Void)? = nil) throws -> ProcessWithSharedFileHandle {
		let process = ProcessWithSharedFileHandle()
		process.executableURL = url
		process.arguments = arguments
		process.terminationHandler = terminationHandler
		try process.run()
		return process
	}

	@available(*, deprecated, renamed: "run(_:arguments:terminationHandler:)")
	// convenience; create and launch
	open class func launchedProcess(launchPath path: String, arguments: [String]) -> ProcessWithSharedFileHandle {
		let process = ProcessWithSharedFileHandle()
		process.launchPath = path
		process.arguments = arguments
		process.launch()

		return process
	}

	// poll the runLoop in defaultMode until process completes
	open func waitUntilExit() {
		let runInterval = 0.05
		let currentRunLoop = RunLoop.current

		let runRunLoop: () -> Void =
			(currentRunLoop == self.runLoop)
			? { _ = currentRunLoop.run(mode: .default, before: Date(timeIntervalSinceNow: runInterval)) }
			: { currentRunLoop.run(until: Date(timeIntervalSinceNow: runInterval)) }
		// update .runLoop to allow early wakeup triggered by terminateRunLoop.
		self.runLoop = currentRunLoop

		while self.isRunning {
			runRunLoop()
		}

		self.runLoop = nil
		self.runLoopSource = nil
	}

	private func terminateRunLoop() {
		// Ensure that the run loop source is invalidated before we mark the process
		// as no longer running.  This serves as a semaphore to
		// `waitUntilExit` to decrement the `runLoopSource` retain count,
		// potentially releasing it.
		CFRunLoopSourceInvalidate(self.runLoopSource)
		let runloopToWakeup = self.runLoop
		self.isRunning = false

		// Wake up the run loop, *AFTER* clearing .isRunning to avoid an extra time out period.
		if let cfRunLoop = runloopToWakeup?.getCFRunLoop() {
			CFRunLoopWakeUp(cfRunLoop)
		}

		if let handler = self.terminationHandler {
			let thread: Thread = Thread { handler(self) }
			thread.start()
		}
	}
}

extension ProcessWithSharedFileHandle {
	public static let didTerminateNotification = NSNotification.Name(rawValue: "NSTaskDidTerminateNotification")
}
