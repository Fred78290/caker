import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import NIOCore
import NIOPortForwarding

struct StartHandler: CakedCommand {
	var foreground: Bool = false
	var name: String
	var waitIPTimeout: Int = 180

	static func autostart(on: EventLoop, asSystem: Bool) throws {
		let storageLocation = StorageLocation(asSystem: asSystem)

		_ = try storageLocation.list().map { (name: String, vmLocation: VMLocation) in
			do {
				let config = try CakeConfig(baseURL: vmLocation.rootURL)

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
		on.submit {
			let vmLocation: VMLocation = try StorageLocation(asSystem: asSystem).find(name)
			let runningIP = try StartHandler.startVM(vmLocation: vmLocation, waitIPTimeout: self.waitIPTimeout, foreground: foreground)

			return "started \(name) with IP:\(runningIP)"
		}
	}

	static func runningArguments(vmLocation: VMLocation) throws -> [String] {
		let config: CakeConfig = try CakeConfig(baseURL: vmLocation.rootURL)
		var arguments: [String] = []

		if config.nestedVirtualization {
			arguments.append("--nested")
		}

		config.mounts.forEach {
			arguments.append("--mount=\($0)")
		}

		config.networks.forEach {
			arguments.append("--network=\($0)")
		}

		config.forwardedPorts.forEach {
			arguments.append("--publish=\($0)")
		}

		config.networks.forEach {
			arguments.append("--socket=\($0.description)")
		}

		if let console = config.console {
			arguments.append("--console=\(console)")
		}

		return arguments
	}

	private static func startVM(vmLocation: VMLocation, args: [String], waitIPTimeout: Int, foreground: Bool, promise: EventLoopPromise<Void>? = nil) throws -> String {
		if vmLocation.status == .running {
			return try WaitIPHandler.waitIP(name: vmLocation.name, wait: 180, asSystem: runAsSystem)
		}

		//let config: CakeConfig = try CakeConfig(baseURL: vmLocation.rootURL)
		let log: String = URL(fileURLWithPath: "output.log", relativeTo: vmLocation.rootURL).absoluteURL.path()
		let process: Process = Process()
		let cakeHome = try Utils.getHome(asSystem: runAsSystem)
		var environment = ProcessInfo.processInfo.environment
		var arguments: [String] = []
		var identifier: String? = nil
		let vsock = URL(fileURLWithPath: "agent.sock", relativeTo: vmLocation.rootURL).absoluteURL.path()
		environment["TART_HOME"] = cakeHome.path()

		arguments.append(contentsOf: args)
		arguments.append("--vsock=bind://any:5000\(vsock)")

		if foreground == false {
			arguments.append("--no-graphics")
			arguments.append("--no-audio")
		}

		arguments.append("2>&1")
		arguments.append(">")
		arguments.append(log)

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
		process.arguments = [ "-c", "exec caked vmrun \(vmLocation.name) " + arguments.joined(separator: " ")]
		process.executableURL = URL(fileURLWithPath: "/bin/bash")
		process.terminationHandler = { process in
			Logger.info("VM \(vmLocation.name) exited with code \(process.terminationStatus)")

			if let identifier = identifier {
				try? PortForwardingServer.closeForwardedPort(identifier: identifier)
			}

			if let promise = promise {
				if process.terminationStatus == 0 {
					promise.succeed()
				} else {
					promise.fail(ShellError(terminationStatus: process.terminationStatus, error: "Failed", message: ""))
				}
			}
		}

		Logger.info(process.arguments?.joined(separator: " ") ?? "")	

		try process.run()

		do {
			let runningIP = try WaitIPHandler.waitIP(name: vmLocation.name, wait: 180, asSystem: runAsSystem, tartProcess: process)
			var config: CakeConfig = try CakeConfig(baseURL: vmLocation.rootURL)

			config.runningIP = runningIP
			try config.save(to: vmLocation.configURL)

			identifier = try PortForwardingServer.createForwardedPort(remoteHost: runningIP, forwardedPorts: config.forwardedPorts)

			return runningIP
		} catch {
			Logger.error(error)

			if process.isRunning == false {
				if let promise: EventLoopPromise<Void> = promise {
					promise.fail(error)
				}

				throw ServiceError("VM \"\(vmLocation.name)\" exited with code \(process.terminationStatus)")
			} else {
				process.terminationHandler = { process in
					if let identifier = identifier {
						try? PortForwardingServer.closeForwardedPort(identifier: identifier)
					}

					if let promise: EventLoopPromise<Void> = promise {
						promise.fail(error)
					}
				}

				process.terminate()

				throw error
			}
		}
	}

	public static func startVM(on: EventLoop, vmLocation: VMLocation, waitIPTimeout: Int, promise: EventLoopPromise<Void>?) -> EventLoopFuture<String> {
		return on.submit {
			if FileManager.default.fileExists(atPath: vmLocation.diskURL.path()) == false {
				throw ServiceError("VM does not exist")
			}

			return try Self.startVM(vmLocation: vmLocation, args: try Self.runningArguments(vmLocation: vmLocation), waitIPTimeout: waitIPTimeout, foreground: false, promise: promise)
		}
	}

	public static func startVM(vmLocation: VMLocation, waitIPTimeout: Int, foreground: Bool = false) throws -> String {
		return try Self.startVM(vmLocation: vmLocation, args: try Self.runningArguments(vmLocation: vmLocation), waitIPTimeout: waitIPTimeout, foreground: foreground, promise: nil)
	}
}
