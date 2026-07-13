import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import NIOPortForwarding
import Semaphore
import Shout
import SystemConfiguration
import CakeAgentLib

public struct StartHandler {
	public enum StartMode: Int, Sendable {
		case background = 0
		case foreground = 1
		case attach = 2
		case service = 3
	}

	private final class StartHandlerVMRun: Sendable {
		let location: VMLocation
		let screenSize: ViewSize?
		let vncPassword: String?
		let vncPort: Int?
		let waitIPTimeout: Int
		let startMode: StartMode
		let runMode: Utils.RunMode
		let gcd: Bool
		let recoveryMode: Bool

		internal init(location: VMLocation, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, gcd: Bool, recoveryMode: Bool, runMode: Utils.RunMode) {
			self.location = location
			self.screenSize = screenSize
			self.vncPassword = vncPassword
			self.vncPort = vncPort
			self.waitIPTimeout = waitIPTimeout
			self.startMode = startMode
			self.runMode = runMode
			self.gcd = gcd
			self.recoveryMode = recoveryMode
		}

		internal func start(promise: EventLoopPromise<String>? = nil) throws -> String {
			let executableURL = try Bundle.main.caked()

			let config: CakeConfig = try location.config()
			var arguments: [String] = ["vmrun", location.configURL.absoluteURL.path, "--log-level=\(Logger.LoggingLevel().rawValue)"]
			var sharedFileDescriptors: [Int32] = []

			try config.startNetworkServices(runMode: runMode)

			if startMode == .foreground {
				arguments.append("--ui")
			} else if startMode == .background {
				arguments.append("--vnc")
			} else if startMode == .service {
				arguments.append("--service")
				arguments.append("--vnc")
				
				if self.gcd {
					arguments.append("--gcd")
				}
			}

			if self.recoveryMode {
				arguments.append("--recovery")
			}

			if let screenSize {
				arguments.append("--screen-size=\(Int(screenSize.width))x\(Int(screenSize.height))")
			}

			if let vncPassword {
				arguments.append("--vnc-password=\(vncPassword)")
			}

			if let vncPort {
				arguments.append("--vnc-port=\(vncPort)")
			}

			if startMode == .service || startMode == .background {
				arguments.append("--tee")
			}

			config.sockets.forEach {
				if let fds = $0.sharedFileDescriptors {
					sharedFileDescriptors.append(contentsOf: fds)
				}
			}

			let vmName = location.name
			let process: ProcessWithSharedFileHandle = try runCaked(executableURL, arguments: arguments, sharedFileDescriptors: sharedFileDescriptors, startMode: startMode, runMode: runMode) { process in
				#if DEBUG
					Logger(self).debug("VM \(vmName) exited with code \(process.terminationStatus)")
				#endif

				// Fires regardless of exit reason (clean stop, crash, kill) so daemon-side
				// observers (e.g. IMDSCoordinator) never leak state for a VM that's gone.
				VMLifecycleHooks.notify(.stopped(location: self.location, runMode: self.runMode))

				if let promise = promise {
					if process.terminationStatus == 0 {
						promise.succeed(vmName)
					} else {
						promise.fail(ShellError(terminationStatus: process.terminationStatus, error: String(localized: "Failed"), message: vmName))
					}
				}
			}

			do {
				let runningIP = try location.waitIP(config: config, wait: 180, runMode: runMode, startedProcess: process)

				// Persist on the daemon's own (cached) config instance so that
				// VMLifecycleHooks observers (e.g. IMDSCoordinator), which read this same
				// cached CakeConfig via `location.config()`, see the current IP rather than
				// whatever was on disk before this VM started.
				config.runningIP = runningIP
				try? config.save()

				VMLifecycleHooks.notify(.started(location: location, runMode: runMode))

				return runningIP
			} catch {
				Logger(self).error(error)

				if process.isRunning == false {
					if let promise: EventLoopPromise<String> = promise {
						promise.fail(error)
					}

					throw ServiceError(String(localized: "VM \"\(location.name)\" exited with code \(process.terminationStatus)"))
				} else {
					process.terminationHandler = { (p: ProcessWithSharedFileHandle) in
						if let promise: EventLoopPromise<String> = promise {
							promise.fail(error)
						}
					}

					process.terminate()

					throw error
				}
			}
		}
	}

	public static func autostart(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Void> {
		let storageLocation = StorageLocation(runMode: runMode)

		// Collect autostart vm
		let vms = try storageLocation.list().compactMap {  (name: String, location: VMLocation) in
			if let config = try? location.config() {
				if location.status.isRunning == false && config.autostart {
					return (config, location)
				}
			}

			return nil
		}

		// Collect autotstart networks
		var networks = try vms.reduce(into: [BridgeAttachement]()) { (result, element) in
			try element.0.networks.forEach { network in
				if result.contains(network) == false {
					let socketURL = try CakedLib.NetworksHandler.vmnetEndpoint(networkName: network.network, runMode: runMode)

					if try socketURL.socket.exists() == false || (try socketURL.socket.exists() && socketURL.pidFile.isPIDRunning().running == false) {
						result.append(network)
					}
				}
			}
		}

		// The IMDS network isn't part of any VM's `config.networks` (it's attached
		// separately, unconditionally, for every Linux VM — see VirtualMachine.swift), so
		// it's never picked up by the loop above. When IMDS is enabled (off by default —
		// see IMDSNetworkInterface.imdsEnabled), always pre-start it here too, regardless
		// of whether this particular autostart batch happens to include a Linux VM:
		// IMDSCoordinator can bind its server as soon as any Linux VM registers, including
		// ones started later outside this batch (e.g. via `cakectl start`) — if the network
		// isn't already up by then, that bind fails.
		if IMDSNetworkInterface.imdsEnabled {
			let imdsNetwork = BridgeAttachement(network: IMDSNetworkInterface.imdsNetworkName)
			let imdsSocketURL = try CakedLib.NetworksHandler.vmnetEndpoint(networkName: imdsNetwork.network, runMode: runMode)

			if try imdsSocketURL.socket.exists() == false || (try imdsSocketURL.socket.exists() && imdsSocketURL.pidFile.isPIDRunning().running == false) {
				networks.append(imdsNetwork)
			}
		}

		// Start networks
		try NetworksHandler.startNetworkServices(networks: networks, runMode: runMode)

		Thread.sleep(forTimeInterval: 1)

		// Start vms
		let future = vms.map { (config, location) in
			on.makeFutureWithTask {
				Logger(self).info("VM \(location.name) starting")

				let reply = StartHandler.startVM(on: on, location: location, screenSize: config.display, vncPassword: config.vncPassword, vncPort: 0, waitIPTimeout: 120, startMode: .service, gcd: false, recoveryMode: false, runMode: runMode)

				if reply.started {
					Logger(self).info("VM \(location.name) started with IP \(reply.ip)")
				} else {
					Logger(self).error("VM \(location.name) failed to start: \(reply.reason)")
				}
			}
		}

		return EventLoopFuture.andAllComplete(future, on: on)
	}

	private static func runCaked(_ caked: URL, arguments: [String], sharedFileDescriptors: [Int32]?, startMode: StartMode, runMode: Utils.RunMode, terminationHandler: (@Sendable (ProcessWithSharedFileHandle) -> Void)?) throws -> ProcessWithSharedFileHandle {

		let process = try Bundle.createProcessWithSharedFileHandle()

		if startMode == .foreground || startMode == .attach {
			let outputPipe = Pipe()
			let errorPipe: Pipe = Pipe()

			outputPipe.fileHandleForReading.readabilityHandler = { handler in
				try? FileHandle.standardOutput.write(contentsOf: handler.availableData)
			}

			errorPipe.fileHandleForReading.readabilityHandler = { handler in
				try? FileHandle.standardError.write(contentsOf: handler.availableData)
			}

			process.standardError = errorPipe
			process.standardOutput = outputPipe
			process.standardInput = FileHandle.standardInput
		} else if startMode == .service {
			process.standardError = FileHandle.standardError
			process.standardOutput = FileHandle.standardOutput
			process.standardInput = FileHandle.nullDevice
		} else {
			process.standardError = FileHandle.nullDevice
			process.standardOutput = FileHandle.nullDevice
			process.standardInput = FileHandle.nullDevice
		}

		process.environment = try Utilities.environment(runMode: runMode)
		process.sharedFileHandles = sharedFileDescriptors?.map { FileHandle(fileDescriptor: $0, closeOnDealloc: true) }
		process.arguments = arguments
		process.executableURL = caked
		process.terminationHandler = terminationHandler

		#if DEBUG
			Logger(self).debug(process.arguments?.joined(separator: " ") ?? String.empty)
		#endif

		try process.run()

		return process
	}

	public static func internalStartVM(location: VMLocation, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, gcd: Bool, recoveryMode: Bool, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> String {
		return try StartHandlerVMRun(location: location, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, gcd: gcd, recoveryMode: recoveryMode, runMode: runMode).start(promise: promise)
	}

	public static func startVM(on: EventLoop, location: VMLocation, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, gcd: Bool, recoveryMode: Bool, runMode: Utils.RunMode) -> StartedReply {
		let promise: EventLoopPromise<String> = on.makePromise(of: String.self)

		promise.futureResult.whenComplete { result in
			switch result {
			case .success(let name):
				Logger(self).info("VM \(name) terminated")
			case .failure(let err):
				Logger(self).error(ServiceError(String(localized: "Failed to start VM \(location.name), \(err.localizedDescription)")))
			}
		}

		return startVM(location: location, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, gcd: gcd, recoveryMode: recoveryMode, runMode: runMode, promise: promise)
	}

	public static func startVM(location: VMLocation, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, gcd: Bool, recoveryMode: Bool, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) -> StartedReply {
		do {
			if FileManager.default.fileExists(atPath: location.configURL.path) == false {
				return StartedReply(name: location.name, ip: String.empty, started: false, reason: String(localized: "VM not found"))
			}

			var ip: String

			if case .running = location.status {
				ip = try location.waitIP(wait: waitIPTimeout, runMode: runMode)
			} else {
				ip = try internalStartVM(location: location, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, gcd: gcd, recoveryMode: recoveryMode, runMode: runMode, promise: promise)
			}

			return StartedReply(name: location.name, ip: ip, started: true, reason: String(localized: "VM started"))
		} catch {
			return StartedReply(name: location.name, ip: String.empty, started: false, reason: error.reason)
		}
	}

	public static func startVM(vmURL: URL, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, gcd: Bool, recoveryMode: Bool, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> StartedReply {
		try Self.startVM(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, gcd: gcd, recoveryMode: recoveryMode, runMode: runMode, promise: promise)
	}

	public static func startVM(name: String, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, gcd: Bool, recoveryMode: Bool, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> StartedReply {
		try Self.startVM(location: StorageLocation(runMode: runMode).find(name), screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, gcd: gcd, recoveryMode: recoveryMode, runMode: runMode)
	}
}
