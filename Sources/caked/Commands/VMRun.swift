import ArgumentParser
import Synchronization
import Combine
import CakedLib
import CakeAgentLib
import Cocoa
import Foundation
import Gzip
import GRPCLib
import NIOPortForwarding
import System
import Virtualization
import Darwin

private final class TeeStandardIOWrapper: Cancellable {
	private let outputPipe = Pipe()
	private let errorPipe = Pipe()
	private let originalOutputHandle: FileHandle
	private let originalErrorHandle: FileHandle
	private let logURL: URL
	private let outputLogHandle: Mutex<FileHandle>
	private var rotationTimer: DispatchSourceTimer?
	private let ioQueue = DispatchQueue(label: "caker.vmrun.tee")
	private let stdoutFD = FileHandle.standardOutput.fileDescriptor
	private let stderrFD = FileHandle.standardError.fileDescriptor
	private let stopped = Mutex(false)
	private static let rotationInterval: DispatchTimeInterval = .seconds(15)

	init(logURL: URL) throws {
		self.logURL = logURL
		_ = try Self.rotateLog(to: logURL)

		let outputLogHandle = try FileHandle(forWritingTo: logURL)
		try outputLogHandle.seekToEnd()

		self.outputLogHandle = .init(outputLogHandle)

		let outputDupFD = dup(stdoutFD)
		let errorDupFD = dup(stderrFD)

		guard outputDupFD != -1, errorDupFD != -1 else {
			if outputDupFD != -1 {
				close(outputDupFD)
			}

			if errorDupFD != -1 {
				close(errorDupFD)
			}

			throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
		}

		self.originalOutputHandle = FileHandle(fileDescriptor: outputDupFD, closeOnDealloc: true)
		self.originalErrorHandle = FileHandle(fileDescriptor: errorDupFD, closeOnDealloc: true)

		outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handler in
			guard let self else {
				return
			}

			tee(handler, target: self.originalOutputHandle)
		}

		errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handler in
			guard let self else {
				return
			}

			self.tee(handler, target: self.originalErrorHandle)
		}

		guard dup2(outputPipe.fileHandleForWriting.fileDescriptor, stdoutFD) != -1 else {
			throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
		}

		guard dup2(errorPipe.fileHandleForWriting.fileDescriptor, stderrFD) != -1 else {
			throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
		}

		scheduleLogRotation()
	}

	private func tee(_ source: FileHandle, target: FileHandle) {
		let data = source.availableData

		guard data.isEmpty == false else {
			return
		}

		let logHandle = self.outputLogHandle
		self.ioQueue.async {
			logHandle.withLock { handle in
				try? target.write(contentsOf: data)
				try? handle.write(contentsOf: data)
			}
		}
	}

	private func scheduleLogRotation() {
		let timer = DispatchSource.makeTimerSource(queue: ioQueue)
		timer.schedule(deadline: .now() + Self.rotationInterval, repeating: Self.rotationInterval)
		timer.setEventHandler { [weak self] in
			self?.rotateAndRefreshHandleIfNeeded()
		}
		rotationTimer = timer
		timer.resume()
	}

	private func rotateAndRefreshHandleIfNeeded() {
		guard stopped.withLock({ $0 }) == false else {
			return
		}

		do {
			try self.outputLogHandle.withLock { outputLogHandle in
				let rotated = try Self.rotateLog(to: logURL, currentOutputHandle: outputLogHandle)

				guard rotated else {
					return
				}

				let newHandle = try FileHandle(forWritingTo: logURL)
				try newHandle.seekToEnd()

				outputLogHandle = newHandle
			}

		} catch {
			// Best effort: keep current handle when rotation fails.
		}
	}

	private static func rotateLog(to logURL: URL, currentOutputHandle: FileHandle? = nil) throws -> Bool {
		// Ensure directory exists
		try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)

		// Rotate logs if needed (size-based)
		let maxSize: UInt64 = 5 * 1024 * 1024  // 5 MB
		let maxFiles = 5
		let fm = FileManager.default
		var didRotate = false

		func rotatedURL(_ index: Int) -> URL {
			logURL.appendingPathExtension("\(index)")
		}

		func rotatedGZURL(_ index: Int) -> URL {
			rotatedURL(index).appendingPathExtension("gz")
		}

		if fm.fileExists(atPath: logURL.path) {
			if let fileSize = try? logURL.fileSize(), fileSize >= maxSize {
				didRotate = true

				if let currentOutputHandle = currentOutputHandle {
					try? currentOutputHandle.synchronize()
					try? currentOutputHandle.close()
				}

				// Delete the oldest rotated generation in either format.
				if fm.fileExists(atPath: rotatedURL(maxFiles).path) {
					try? fm.removeItem(at: rotatedURL(maxFiles))
				}

				if fm.fileExists(atPath: rotatedGZURL(maxFiles).path) {
					try? fm.removeItem(at: rotatedGZURL(maxFiles))
				}

				// Shift others
				if maxFiles >= 2 {
					for i in stride(from: maxFiles - 1, through: 1, by: -1) {
						let src = rotatedURL(i)
						let dst = rotatedURL(i + 1)
						let srcGZ = rotatedGZURL(i)
						let dstGZ = rotatedGZURL(i + 1)

						if fm.fileExists(atPath: srcGZ.path) {
							try? fm.moveItem(at: srcGZ, to: dstGZ)
						}

						if fm.fileExists(atPath: src.path) {
							try? fm.moveItem(at: src, to: dst)
						}
					}
				}

				// Move current to .1
				try? fm.moveItem(at: logURL, to: rotatedURL(1))

				// Keep rotated files consistently as .N.gz (and clean legacy .N files).
				for i in 1...maxFiles {
					let src = rotatedURL(i)
					let gz = rotatedGZURL(i)

					if fm.fileExists(atPath: src.path) {
						if fm.fileExists(atPath: gz.path) {
							try? fm.removeItem(at: src)
						} else if let d = try? Data(contentsOf: src), let gzData = try? d.gzipped() {
							try? gzData.write(to: gz, options: .atomic)
							try? fm.removeItem(at: src)
						}
					}
				}
			}
		}

		// Create file if missing
		if fm.fileExists(atPath: logURL.path) == false {
			fm.createFile(atPath: logURL.path, contents: nil)
		}

		return didRotate
	}

	func stop() {
		guard stopped.withLock({
			guard !$0 else {
				return false
			}
			$0 = true; return true
		}) else {
			return
		}

		outputPipe.fileHandleForReading.readabilityHandler = nil
		errorPipe.fileHandleForReading.readabilityHandler = nil

		_ = dup2(originalOutputHandle.fileDescriptor, stdoutFD)
		_ = dup2(originalErrorHandle.fileDescriptor, stderrFD)

		ioQueue.sync {
			self.rotationTimer?.setEventHandler {}
			self.rotationTimer?.cancel()
			self.rotationTimer = nil
			try? self.outputPipe.close()
			try? self.errorPipe.close()
			
			outputLogHandle.withLock { outputLogHandle in
				try? outputLogHandle.synchronize()
				try? outputLogHandle.close()
			}
		}
	}

	func cancel() {
		self.stop()
	}
	
	deinit {
		stop()
	}
}

struct VMRun: AsyncParsableCommand {
	static let configuration = CommandConfiguration(commandName: "vmrun", abstract: String(localized: "Run VM"), shouldDisplay: false, aliases: ["run"])

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Flag(name: [.customLong("service"), .customShort("l")], help: ArgumentHelp(String(localized: "VM running from service"), discussion: String(localized: "This option tell that vm run from service"), visibility: .private))
	var launchedFromService: Bool = false

	@Flag(name: [.customLong("lima"), .customShort("m")], help: ArgumentHelp(String(localized: "Use socket-vmnet for network"), visibility: .private))
	var useLimaVMNet: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "VM Display mode"), discussion: String(localized: "This option allows display window of running vm or vnc server"), visibility: .hidden))
	var display: VMRunHandler.DisplayMode = .none

	@Flag(help: ArgumentHelp(String(localized: "Service endpoint"), discussion: String(localized: "This option allows run vm in service mode"), visibility: .hidden))
	var mode: VMRunServiceMode = .grpc

	@Option(help: ArgumentHelp(String(localized: "VNC server password"), discussion: String(localized: "This option allows run vnc server with password"), visibility: .hidden))
	var vncPassword: String? = nil

	@Option(help: ArgumentHelp(String(localized: "VNC Server port"), discussion: String(localized: "This option allows run vnc server with custom port"), visibility: .hidden))
	var vncPort: Int = 0

	@Option(help: ArgumentHelp(String(localized: "Screen size"), discussion: String(localized: "This option allows setting custom screen size for the VM display"), visibility: .hidden))
	var screenSize: ViewSize?

	@Flag(name: [.customLong("gcd")], help: ArgumentHelp(String(localized: "Start grand central dispatch"), visibility: .private))
	var startGCD: Bool = false

	@Flag(name: [.customLong("tee")], help: ArgumentHelp(String(localized: "Tee standard output and error to log file"), visibility: .private))
	var tee: Bool = false

	@Flag(name: [.customLong("recovery")], help: ArgumentHelp(String(localized: "Launch vm in recovery mode"), discussion: String(localized: "This option allows starting the MacOS VM in recovery mode")))
	var recoveryMode: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Path to the VM disk.img or his name")))
	var path: String

	var locations: (StorageLocation, VMLocation) {
		if StorageLocation(runMode: self.common.runMode).exists(path) {
			let storageLocation = StorageLocation(runMode: self.common.runMode)
			let vm = try! storageLocation.find(path)

			return (storageLocation, vm)
		} else {
			let u: URL = URL(fileURLWithPath: path)
			let parent = u.deletingLastPathComponent()
			let storage = parent.deletingLastPathComponent()
			let storageLocation = StorageLocation(runMode: self.common.runMode, name: storage.lastPathComponent)
			let vm = VMLocation(rootURL: parent, template: storageLocation.template)

			return (storageLocation, vm)
		}
	}

	private func setupLogging(to logURL: URL) -> Cancellable? {
		guard self.tee else {
			return nil
		}

		do {
			return try TeeStandardIOWrapper(logURL: logURL)
		} catch {
			// Best effort: if tee setup fails, keep running without tee
		}
		
		return nil
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let (_, location) = self.locations

		VMRunHandler.launchedFromService = self.launchedFromService
		VMRunHandler.serviceMode = self.mode

		if location.inited == false {
			throw ValidationError(String(localized: "VM at \(path) does not exist"))
		}

		if case .running = location.status {
			throw ValidationError(String(localized: "VM at \(path) is already running"))
		}

		phUseLimaVMNet = self.useLimaVMNet
		MainApp.displayUI = display == .ui

		let config = try location.config()

		try config.sockets.forEach {
			try $0.validate()
		}

		if let console = config.console {
			try ConsoleAttachment(argument: console).validate()
		}

		if self.launchedFromService {
			self.display = .vnc
		}
	}

	@MainActor
	func run() async throws {
		let (storageLocation, location) = self.locations
		let config = try location.config()
		let vncPassword = self.vncPassword ?? config.vncPassword ?? UUID().uuidString
		let displaySize: CGSize
		var display = self.display
		var startGrandCentral = false
		let cancellable = self.setupLogging(to: location.outputLogURL)

		if case .running = location.status {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		if let screenSize = self.screenSize {
			displaySize = .init(width: screenSize.width, height: screenSize.height)
		} else {
			displaySize = config.display.cgSize
		}

		if (self.launchedFromService && self.startGCD) || (self.launchedFromService == false && ServiceHandler.isAgentRunning) {
			startGrandCentral = true

			if display == .none {
				display = .vnc
			} else if display == .ui {
				display = .all
			}
		}

		let runMode = self.common.runMode
		let handler = CakedLib.VMRunHandler(
			mode: mode,
			storageLocation: storageLocation,
			location: location,
			name: location.name,
			display: display,
			config: config,
			screenSize: displaySize,
			vncPassword: vncPassword,
			vncPort: vncPort,
			recoveryMode: self.recoveryMode,
			runMode: runMode)

		try handler.run { address, vm in
			let logger = Logger(self)

			address.whenSuccess { ip in
				if let ip {
					logger.info("VM Machine \(location.name) is now available at \(ip)")
				}
			}

			// Check also manual launch
			if startGrandCentral {
				logger.info("Start GCD for VM: \(location.name)")

				try? Utilities.group.next().makeFutureWithTask {
					try await vm.startGrandCentralUpdate(frequency: 1, runMode: runMode)
				}.wait()
			}

			if display == .all || display == .vnc {
				if let vncURL = try? vm.startVncServer(vncPassword: vncPassword, port: vncPort) {
					logger.info("VNC server started at \(vncURL.map(\.absoluteString).joined(separator: ", "))")
				} else {
					logger.info("Failed to start VNC server")
				}

			} else if display == .ui {
				vm.createVirtualMachineView()
			}

			if display == .ui || display == .all {
				MainApp.runUI(vm, params: handler, cancellation: cancellable)
			} else {
				NSApplication.shared.setActivationPolicy(.prohibited)
				NSApplication.shared.run()
				
				cancellable?.cancel()
			}
		}
	}
}
