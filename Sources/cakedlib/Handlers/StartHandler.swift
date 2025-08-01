import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import NIOPortForwarding
import Semaphore
import Shout
import SystemConfiguration

public struct StartHandler {
	public enum StartMode: Int {
		case background = 0
		case foreground = 1
		case attach = 2
		case service = 3
	}

	private final class StartHandlerVMRun: Sendable {
		internal func start(location: VMLocation, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> String {
			let config: CakeConfig = try location.config()
			let log: String = URL(fileURLWithPath: "output.log", relativeTo: location.rootURL).absoluteURL.path

			guard let caked = URL.binary("caked") else {
				throw ServiceError("caked not found")
			}

			var arguments: [String] = ["exec", caked.path(), "vmrun", location.diskURL.absoluteURL.path, "--log-level=\(Logger.LoggingLevel().rawValue)"]
			var sharedFileDescriptors: [Int32] = []

			try config.startNetworkServices(runMode: runMode)

			if startMode == .foreground {
				arguments.append("--display")
			} else if startMode == .service {
				arguments.append("--service")
			}

			if startMode == .service || startMode == .background {
				arguments.append(contentsOf: ["2>&1", "|", "tee", log])
			}

			config.sockets.forEach {
				if let fds = $0.sharedFileDescriptors {
					sharedFileDescriptors.append(contentsOf: fds)
				}
			}

			let process: ProcessWithSharedFileHandle = try runProccess(arguments: arguments, sharedFileDescriptors: sharedFileDescriptors, startMode: startMode, runMode: runMode) { process in
				Logger(self).debug("VM \(location.name) exited with code \(process.terminationStatus)")

				if let promise = promise {
					if process.terminationStatus == 0 {
						promise.succeed(location.name)
					} else {
						promise.fail(ShellError(terminationStatus: process.terminationStatus, error: "Failed", message: location.name))
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

						do {
							let runningIP = try StartHandler.startVM(on: on, location: location, config: config, waitIPTimeout: 120, startMode: .service, runMode: runMode)

							Logger(self).info("VM \(name) started with IP \(runningIP)")
						} catch {
							Logger(self).error(error)
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

		Logger(self).debug(process.arguments?.joined(separator: " ") ?? "")

		try process.run()

		return process
	}

	public static func internalStartVM(location: VMLocation, config: CakeConfig, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> String {
		return try StartHandlerVMRun().start(location: location, waitIPTimeout: waitIPTimeout, startMode: startMode, runMode: runMode, promise: promise)
	}

	public static func startVM(on: EventLoop, location: VMLocation, config: CakeConfig, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode) throws -> String {
		let promise: EventLoopPromise<String> = on.makePromise(of: String.self)

		promise.futureResult.whenComplete { result in
			switch result {
			case let .success(name):
				Logger(self).info("VM \(name) terminated")
			case let .failure(err):
				Logger(self).error(ServiceError("Failed to start VM \(location.name), \(err.localizedDescription)"))
			}
		}

		return try startVM(location: location, config: config, waitIPTimeout: waitIPTimeout, startMode: startMode, runMode: runMode, promise: promise)
	}

	public static func startVM(location: VMLocation, config: CakeConfig, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> String {
		if FileManager.default.fileExists(atPath: location.diskURL.path) == false {
			throw ServiceError("VM does not exist")
		}

		if location.status == .running {
			return try location.waitIP(wait: 180, runMode: runMode)
		}

		return try StartHandlerVMRun().start(location: location, waitIPTimeout: waitIPTimeout, startMode: startMode, runMode: runMode, promise: promise)
	}

}
