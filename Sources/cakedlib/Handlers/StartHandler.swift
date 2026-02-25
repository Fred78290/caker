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

		internal init(location: VMLocation, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode) {
			self.location = location
			self.screenSize = screenSize
			self.vncPassword = vncPassword
			self.vncPort = vncPort
			self.waitIPTimeout = waitIPTimeout
			self.startMode = startMode
			self.runMode = runMode
		}

		internal func start(promise: EventLoopPromise<String>? = nil) throws -> String {
			let config: CakeConfig = try location.config()
			let log: String = URL(fileURLWithPath: "output.log", relativeTo: location.rootURL).absoluteURL.path

			guard let caked = URL.binary(Home.cakedCommandName) else {
				throw ServiceError("caked not found")
			}

			var arguments: [String] = ["exec", "'\(caked.path())'", "vmrun", "'\(location.diskURL.absoluteURL.path)'", "--log-level=\(Logger.LoggingLevel().rawValue)"]
			var sharedFileDescriptors: [Int32] = []

			try config.startNetworkServices(runMode: runMode)

			if startMode == .foreground {
				arguments.append("--ui")
			} else if startMode == .background {
				arguments.append("--vnc")
			} else if startMode == .service {
				arguments.append("--service")
				arguments.append("--vnc")
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
				arguments.append(contentsOf: ["2>&1", "|", "tee", "'\(log)'"])
			}

			config.sockets.forEach {
				if let fds = $0.sharedFileDescriptors {
					sharedFileDescriptors.append(contentsOf: fds)
				}
			}

			let vmName = location.name
			let process: ProcessWithSharedFileHandle = try runProccess(arguments: arguments, sharedFileDescriptors: sharedFileDescriptors, startMode: startMode, runMode: runMode) { process in
				#if DEBUG
					Logger(self).debug("VM \(vmName) exited with code \(process.terminationStatus)")
				#endif
				if let promise = promise {
					if process.terminationStatus == 0 {
						promise.succeed(vmName)
					} else {
						promise.fail(ShellError(terminationStatus: process.terminationStatus, error: "Failed", message: vmName))
					}
				}
			}

			do {
				let runningIP = try location.waitIPWithAgent(wait: 180, runMode: runMode, startedProcess: process)

				return runningIP
			} catch {
				Logger(self).error(error)

				if process.isRunning == false {
					if let promise: EventLoopPromise<String> = promise {
						promise.fail(error)
					}

					throw ServiceError("VM \"\(location.name)\" exited with code \(process.terminationStatus)")
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

	public static func autostart(on: EventLoop, runMode: Utils.RunMode) throws {
		let storageLocation = StorageLocation(runMode: runMode)

		_ = try storageLocation.list().map { (name: String, location: VMLocation) in
			do {
				let config = try location.config()

				if config.autostart && location.status != .running {
					Task {
						Logger(self).info("VM \(name) starting")

						let reply = StartHandler.startVM(on: on, location: location, screenSize: config.display.screenSize, vncPassword: config.vncPassword, vncPort: 0, waitIPTimeout: 120, startMode: .service, runMode: runMode)

						if reply.started {
							Logger(self).info("VM \(name) started with IP \(reply.ip)")
						} else {
							Logger(self).error("VM \(name) failed to start: \(reply.reason)")
						}
					}
				}
			} catch {
				Logger(self).error(error)
			}

			return location
		}
	}

	private static func runProccess(arguments: [String], sharedFileDescriptors: [Int32]?, startMode: StartMode, runMode: Utils.RunMode, terminationHandler: (@Sendable (ProcessWithSharedFileHandle) -> Void)?) throws -> ProcessWithSharedFileHandle {
		let process = ProcessWithSharedFileHandle()

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
		process.arguments = ["-c", arguments.joined(separator: " ")]
		process.executableURL = URL(fileURLWithPath: "/bin/sh")
		process.terminationHandler = terminationHandler

		#if DEBUG
			Logger(self).debug(process.arguments?.joined(separator: " ") ?? "")
		#endif

		try process.run()

		return process
	}

	public static func internalStartVM(location: VMLocation, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> String {
		return try StartHandlerVMRun(location: location, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, runMode: runMode).start(promise: promise)
	}

	public static func startVM(on: EventLoop, location: VMLocation, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode) -> StartedReply {
		let promise: EventLoopPromise<String> = on.makePromise(of: String.self)

		promise.futureResult.whenComplete { result in
			switch result {
			case .success(let name):
				Logger(self).info("VM \(name) terminated")
			case .failure(let err):
				Logger(self).error(ServiceError("Failed to start VM \(location.name), \(err.localizedDescription)"))
			}
		}

		return startVM(location: location, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, runMode: runMode, promise: promise)
	}

	public static func startVM(location: VMLocation, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) -> StartedReply {
		do {
			if FileManager.default.fileExists(atPath: location.diskURL.path) == false {
				return StartedReply(name: location.name, ip: "", started: false, reason: "VM not found")
			}

			var ip: String

			if location.status == .running {
				ip = try location.waitIP(wait: 180, runMode: runMode)
			} else {
				ip = try internalStartVM(location: location, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, runMode: runMode, promise: promise)
			}

			return StartedReply(name: location.name, ip: ip, started: true, reason: "VM started")
		} catch {
			return StartedReply(name: location.name, ip: "", started: false, reason: "\(error)")
		}
	}

	public static func startVM(name: String, screenSize: ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> StartedReply {
		try Self.startVM(location: StorageLocation(runMode: runMode).find(name), screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, runMode: runMode)
	}
}
