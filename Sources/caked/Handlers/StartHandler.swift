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

	static func autostart(asSystem: Bool) throws {
		let storageLocation = StorageLocation(asSystem: asSystem)

		_ = try storageLocation.list().map { (name: String, vmLocation: VMLocation) in
			do {
				let config = try CakeConfig(baseURL: vmLocation.rootURL)

				if config.autostart && vmLocation.status != .running {
					Task {
						do {
							let handler: StartHandler = StartHandler(foreground: false, name: name)

							_ = try await handler.run(asSystem: asSystem)
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

	func run(asSystem: Bool) async throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)
		let runningIP = try StartHandler.startVM(vmLocation: vmLocation, waitIPTimeout: self.waitIPTimeout, foreground: foreground)

		return "started \(name) with IP:\(runningIP)"
	}

	static func runningArguments(vmLocation: VMLocation) throws -> [String] {
		let config: CakeConfig = try CakeConfig(baseURL: vmLocation.rootURL)
		let cdrom = URL(fileURLWithPath: cloudInitIso, relativeTo: vmLocation.diskURL).absoluteURL
		var arguments: [String] = []

		if config.nestedVirtualization {
			arguments.append("--nested")
		}

		for mount in config.mounts {
			arguments.append("--dir=\(mount)")
		}

		for net in config.netBridged {
			arguments.append("--net-bridged=\(net)")
		}

//		if config.netSoftnet {
//			arguments.append("--net-softnet")
//		}
//
//		if let netSoftnetAllow = config.netSoftnetAllow {
//			arguments.append("--net-softnet-allow=\(netSoftnetAllow)")
//		}
//
//		if config.netHost {
//			arguments.append("--net-host")
//		}

		if try cdrom.exists() {
			arguments.append("--disk=\(cdrom.path())")
		}

		return arguments
	}

	private static func startVM(vmLocation: VMLocation, args: [String], waitIPTimeout: Int, foreground: Bool, promise: EventLoopPromise<Void>? = nil) throws -> String {
		//let config: CakeConfig = try CakeConfig(baseURL: vmLocation.rootURL)
		let log: String = URL(fileURLWithPath: "output.log", relativeTo: vmLocation.rootURL).absoluteURL.path()
		let process: Process = Process()
		let cakeHome = try Utils.getHome(asSystem: runAsSystem)
		var environment = ProcessInfo.processInfo.environment
		var arguments: [String] = []
		var identifier: String? = nil

		environment["TART_HOME"] = cakeHome.path()

		arguments.append(contentsOf: args)

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
		process.arguments = [ "-c", "exec tart run \(vmLocation.name) " + arguments.joined(separator: " ")]
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

		try process.run()

		do {
			let runningIP = try WaitIPHandler.waitIP(name: vmLocation.name, wait: 180, asSystem: runAsSystem)
			var config: CakeConfig = try CakeConfig(baseURL: vmLocation.rootURL)

			config.runningIP = runningIP
			try config.save(to: vmLocation.configURL)

			identifier = try PortForwardingServer.createForwardedPort(remoteHost: runningIP, forwardedPorts: config.forwardedPorts)

			return runningIP
		} catch {
			Logger.error(error)

			if process.isRunning == false {
				throw ServiceError("VM \"\(vmLocation.name)\" exited with code \(process.terminationStatus)")
			} else {
				process.terminationHandler = { process in
					if let identifier = identifier {
						try? PortForwardingServer.closeForwardedPort(identifier: identifier)
					}

					if let promise = promise {
						promise.fail(error)
					}
				}

				process.terminate()

				throw error
			}
		}
	}

	public static func startVM(on: EventLoopGroup, vmLocation: VMLocation, waitIPTimeout: Int, promise: EventLoopPromise<Void>?) -> EventLoopFuture<String> {
		return on.any().submit {
			return try Self.startVM(vmLocation: vmLocation, args: try Self.runningArguments(vmLocation: vmLocation), waitIPTimeout: waitIPTimeout, foreground: false, promise: promise)
		}
	}

	public static func startVM(vmLocation: VMLocation, waitIPTimeout: Int, foreground: Bool = false) throws -> String {
		return try Self.startVM(vmLocation: vmLocation, args: try Self.runningArguments(vmLocation: vmLocation), waitIPTimeout: waitIPTimeout, foreground: foreground, promise: nil)
	}
}
