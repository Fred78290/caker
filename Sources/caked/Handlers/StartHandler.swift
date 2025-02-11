import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import NIOCore
import NIOPortForwarding
import Semaphore

struct StartHandler: CakedCommand {
	var foreground: Bool = false
	var name: String
	var waitIPTimeout: Int = 180

	private class StartHandlerVMRun {
		var identifier: String? = nil

		internal func start(vmLocation: VMLocation, waitIPTimeout: Int, foreground: Bool, promise: EventLoopPromise<String>? = nil) async throws -> String {
			var config: CakeConfig = try vmLocation.config()
			let log: String = URL(fileURLWithPath: "output.log", relativeTo: vmLocation.rootURL).absoluteURL.path()
			let arguments: [String] = ["exec", "caked", "vmrun", vmLocation.name, "2>&1", ">", log]
			var sharedFileDescriptors: [Int32] = []

			config.sockets.forEach {
				if let fds = $0.sharedFileDescriptors {
					sharedFileDescriptors.append(contentsOf: fds)
				}
			}

			let process: ProcessWithSharedFileHandle = try runProccess(arguments: arguments, sharedFileDescriptors: sharedFileDescriptors, foreground: foreground) { process in
				Logger.info("VM \(vmLocation.name) exited with code \(process.terminationStatus)")

				if let id = self.identifier {	
					try? PortForwardingServer.closeForwardedPort(identifier: id)
				}

				if let promise = promise {
					if process.terminationStatus == 0 {
						promise.succeed(vmLocation.name)
					} else {
						promise.fail(ShellError(terminationStatus: process.terminationStatus, error: "Failed", message: vmLocation.name))
					}
				}
			}

			do {
				let runningIP = try await WaitIPHandler.waitIPWithAgent(name: vmLocation.name, wait: 180, asSystem: runAsSystem, vmrunProcess: process)

				config.runningIP = runningIP
				try config.save()

				return runningIP
			} catch {
				Logger.error(error)

				if process.isRunning == false {
					if let promise: EventLoopPromise<String> = promise {
						promise.fail(error)
					}

					throw ServiceError("VM \"\(vmLocation.name)\" exited with code \(process.terminationStatus)")
				} else {
					process.terminationHandler = { (p: ProcessWithSharedFileHandle) in
						if let id = self.identifier {
							try? PortForwardingServer.closeForwardedPort(identifier: id)
						}

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

	private class StartHandlerTart {
		var identifier: String? = nil

		private func runningArguments(vmLocation: VMLocation, foreground: Bool) throws -> ([String], [Int32]) {
			let config: CakeConfig = try vmLocation.config()
			let vsock = URL(fileURLWithPath: "agent.sock", relativeTo: vmLocation.rootURL).absoluteURL.path()
			let cloudInit = URL(fileURLWithPath: cloudInitIso, relativeTo: vmLocation.diskURL).absoluteURL.path()
			let log: String = URL(fileURLWithPath: "output.log", relativeTo: vmLocation.rootURL).absoluteURL.path()

			var arguments: [String] = ["exec", "tart", "run", vmLocation.name]
			var sharedFileDescriptors: [Int32] = []

			if foreground == false {
				arguments.append("--no-graphics")
				arguments.append("--no-audio")
			}

			if config.nestedVirtualization {
				arguments.append("--nested")
			}

			arguments.append(contentsOf: config.mounts.map {
				"--dir=\($0.description)"
			})

			arguments.append(contentsOf: config.disks.map {
				"--disk=\($0.description)"
			})

			arguments.append(contentsOf: config.networks.map {
				"--net-bridged=\($0.network)"
			})

			arguments.append(contentsOf: config.sockets.map {
				if let fds = $0.sharedFileDescriptors {
					sharedFileDescriptors.append(contentsOf: fds)
				}

				return "--vsock=\($0.description)"
			})

			arguments.append("--vsock=bind://any:5000\(vsock)")

			if FileManager.default.fileExists(atPath: cloudInit) {
				arguments.append("--disk=\(cloudInit)")
			}

			if let console = config.console {
				arguments.append("--console=\(console.description)")
			}

			arguments.append("2>&1")
			arguments.append(">")
			arguments.append(log)

			return (arguments, sharedFileDescriptors)
		}

		internal func start(vmLocation: VMLocation, waitIPTimeout: Int, foreground: Bool, promise: EventLoopPromise<String>?) throws -> String {
			let (arguments, sharedFileDescriptors) = try self.runningArguments(vmLocation: vmLocation, foreground: foreground)

			let process: ProcessWithSharedFileHandle = try runProccess(arguments: arguments, sharedFileDescriptors: sharedFileDescriptors, foreground: foreground) { process in
				Logger.info("VM \(vmLocation.name) exited with code \(process.terminationStatus)")

				if let id = self.identifier {	
					try? PortForwardingServer.closeForwardedPort(identifier: id)
				}

				if let promise = promise {
					if process.terminationStatus == 0 {
						promise.succeed(vmLocation.name)
					} else {
						promise.fail(ShellError(terminationStatus: process.terminationStatus, error: "Failed", message: vmLocation.name))
					}
				}
			}

			do {
				let runningIP = try WaitIPHandler.waitIPWithTart(name: vmLocation.name, wait: 180, asSystem: runAsSystem, tartProcess: process)
				var config: CakeConfig = try vmLocation.config()

				config.runningIP = runningIP
				try config.save()

				self.identifier = try PortForwardingServer.createForwardedPort(remoteHost: runningIP, forwardedPorts: config.forwardedPorts)

				return runningIP
			} catch {
				Logger.error(error)

				if process.isRunning == false {
					if let promise: EventLoopPromise<String> = promise {
						promise.fail(error)
					}

					throw ServiceError("VM \"\(vmLocation.name)\" exited with code \(process.terminationStatus)")
				} else {
					process.terminationHandler = { (p: ProcessWithSharedFileHandle) in
						if let id = self.identifier {
							try? PortForwardingServer.closeForwardedPort(identifier: id)
						}

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

	private static func vmrunAvailable() -> Bool {
		Root.configuration.subcommands.first { cmd in
			cmd.configuration.commandName == "vmrun"
		} != nil
	}

	static func autostart(on: EventLoop, asSystem: Bool) throws {
		let storageLocation = StorageLocation(asSystem: asSystem)

		_ = try storageLocation.list().map { (name: String, vmLocation: VMLocation) in
			do {
				let config = try vmLocation.config()

				if config.autostart && vmLocation.status != .running {
					Task {
						do {
							let handler: StartHandler = StartHandler(foreground: false, name: name)

							_ = try handler.run(on: on, asSystem: asSystem)
						} catch {
							Logger.error(error)
						}
					}
				}
			} catch {
				Logger.error(error)
			}

			return vmLocation
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		let vmLocation: VMLocation = try StorageLocation(asSystem: asSystem).find(name)
		let promise: EventLoopPromise<String> = on.makePromise(of: String.self)

		promise.futureResult.whenComplete { result in
			switch result {
			case let .success(name):
				Logger.info("VM \(name) terminated")
			case let .failure(err):
				Logger.error(ServiceError("Failed to start VM \(vmLocation.name), \(err.localizedDescription)"))
			}
		}

		return on.makeFutureWithTask {
			return try await StartHandler.startVM(vmLocation: vmLocation, waitIPTimeout: waitIPTimeout, foreground: false, promise: promise)
		}
	}

	private static func runProccess(arguments: [String], sharedFileDescriptors: [Int32]?, foreground: Bool, terminationHandler: (@Sendable (ProcessWithSharedFileHandle) -> Void)?) throws -> ProcessWithSharedFileHandle {
		let process = ProcessWithSharedFileHandle()
		var environment = ProcessInfo.processInfo.environment
		let cakeHome = try Utils.getHome(asSystem: runAsSystem)

		environment["TART_HOME"] = cakeHome.path()

		if foreground {
			process.standardError = FileHandle.standardError
			process.standardOutput = FileHandle.standardOutput
			process.standardInput = FileHandle.standardInput
		} else {
			process.standardError = FileHandle.nullDevice
			process.standardOutput = FileHandle.nullDevice
			process.standardInput = FileHandle.nullDevice
		}

		process.environment = environment
		process.sharedFileHandles = sharedFileDescriptors?.map { FileHandle(fileDescriptor: $0, closeOnDealloc: true) }
		process.arguments = [ "-c", arguments.joined(separator: " ")]
		process.executableURL = URL(fileURLWithPath: "/bin/sh")
		process.terminationHandler = terminationHandler

		Logger.debug(process.arguments?.joined(separator: " ") ?? "")	

		try process.run()

		return process
	}

	public static func startVM(vmLocation: VMLocation, waitIPTimeout: Int, foreground: Bool, promise: EventLoopPromise<String>? = nil) async throws -> String {
		if FileManager.default.fileExists(atPath: vmLocation.diskURL.path()) == false {
			throw ServiceError("VM does not exist")
		}

		if vmLocation.status == .running {
			return try await WaitIPHandler.waitIP(name: vmLocation.name, wait: 180, asSystem: runAsSystem)
		}

		if Root.vmrunAvailable() {
			return try await StartHandlerVMRun().start(vmLocation: vmLocation, waitIPTimeout: waitIPTimeout, foreground: foreground, promise: promise)
		} else {
			return try StartHandlerTart().start(vmLocation: vmLocation, waitIPTimeout: waitIPTimeout, foreground: foreground, promise: promise)
		}
	}
}
