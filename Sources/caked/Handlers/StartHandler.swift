import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import NIOCore
import NIOPortForwarding
import Semaphore
import Shout

struct StartHandler: CakedCommand {
	var startMode: StartMode = .background
	var location: VMLocation
	var config: CakeConfig
	var waitIPTimeout: Int = 180
	
	enum StartMode: Int {
		case background = 0
		case foreground = 1
		case attach = 2
		case service = 3
	}
	
	init(location: VMLocation, config: CakeConfig, waitIPTimeout: Int, startMode: StartMode) {
		self.startMode = startMode
		self.location = location
		self.config = config
		self.waitIPTimeout = waitIPTimeout
	}
	
	init(location: VMLocation, waitIPTimeout: Int, startMode: StartMode) throws {
		self.location = location
		self.config = try location.config()
		self.waitIPTimeout = waitIPTimeout
		self.startMode = startMode
	}
	
	init(name: String, waitIPTimeout: Int, startMode: StartMode, asSystem: Bool) throws {
		let vmLocation: VMLocation = try StorageLocation(asSystem: asSystem).find(name)
		
		self.location = vmLocation
		self.config = try vmLocation.config()
		self.waitIPTimeout = waitIPTimeout
		self.startMode = startMode
	}
	
	private final class StartHandlerVMRun: Sendable {
		internal func start(vmLocation: VMLocation, waitIPTimeout: Int, startMode: StartMode, asSystem: Bool, promise: EventLoopPromise<String>? = nil) throws -> String {
			let config: CakeConfig = try vmLocation.config()
			let log: String = URL(fileURLWithPath: "output.log", relativeTo: vmLocation.rootURL).absoluteURL.path
			var arguments: [String] = ["exec", "caked", "vmrun", vmLocation.diskURL.absoluteURL.path]
			var sharedFileDescriptors: [Int32] = []
			
			try config.startNetworkServices(asSystem: asSystem)
			
			if startMode == .background {
				arguments.append(contentsOf: ["2>&1", ">", log])
			} else if startMode == .foreground{
				arguments.append("--display")
			} else if startMode == .service {
				arguments.append("--service")
			}
			
			config.sockets.forEach {
				if let fds = $0.sharedFileDescriptors {
					sharedFileDescriptors.append(contentsOf: fds)
				}
			}
			
			let process: ProcessWithSharedFileHandle = try runProccess(arguments: arguments, sharedFileDescriptors: sharedFileDescriptors, startMode: startMode, asSystem: asSystem) { process in
				Logger(self).debug("VM \(vmLocation.name) exited with code \(process.terminationStatus)")
				
				if let promise = promise {
					if process.terminationStatus == 0 {
						promise.succeed(vmLocation.name)
					} else {
						promise.fail(ShellError(terminationStatus: process.terminationStatus, error: "Failed", message: vmLocation.name))
					}
				}
			}
			
			do {
				let runningIP = try vmLocation.waitIPWithAgent(wait: 180, asSystem: asSystem, startedProcess: process)
				
				return runningIP
			} catch {
				Logger(self).error(error)
				
				if process.isRunning == false {
					if let promise: EventLoopPromise<String> = promise {
						promise.fail(error)
					}
					
					throw ServiceError("VM \"\(vmLocation.name)\" exited with code \(process.terminationStatus)")
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
	
	static func autostart(on: EventLoop, asSystem: Bool) throws {
		let storageLocation = StorageLocation(asSystem: asSystem)
		
		_ = try storageLocation.list().map { (name: String, vmLocation: VMLocation) in
			do {
				let config = try vmLocation.config()
				
				if config.autostart && vmLocation.status != .running {
					Task {
						Logger(self).info("VM \(name) starting")
						
						do {
							let runningIP = try StartHandler.startVM(on: on, vmLocation: vmLocation, config: config, waitIPTimeout: 120, startMode: .service, asSystem: asSystem)
							
							Logger(self).info("VM \(name) started with IP \(runningIP)")
						} catch {
							Logger(self).error(error)
						}
					}
				}
			} catch {
				Logger(self).error(error)
			}
			
			return vmLocation
		}
	}
	
	private static func runProccess(arguments: [String], sharedFileDescriptors: [Int32]?, startMode: StartMode, asSystem: Bool, terminationHandler: (@Sendable (ProcessWithSharedFileHandle) -> Void)?) throws -> ProcessWithSharedFileHandle {
		let process = ProcessWithSharedFileHandle()
		
		if startMode == .foreground || startMode == .attach {
			let outputPipe = Pipe()
			let errorPipe : Pipe = Pipe()
			
			outputPipe.fileHandleForReading.readabilityHandler = { handler in
				try? FileHandle.standardOutput.write(contentsOf: handler.availableData)
			}
			
			errorPipe.fileHandleForReading.readabilityHandler = { handler in
				try? FileHandle.standardError.write(contentsOf: handler.availableData)
			}
			
			process.standardError = errorPipe
			process.standardOutput = outputPipe
			process.standardInput = FileHandle.standardInput
		} else {
			process.standardError = FileHandle.nullDevice
			process.standardOutput = FileHandle.nullDevice
			process.standardInput = FileHandle.nullDevice
		}
		
		process.environment = try Root.environment(asSystem: asSystem)
		process.sharedFileHandles = sharedFileDescriptors?.map { FileHandle(fileDescriptor: $0, closeOnDealloc: true) }
		process.arguments = [ "-c", arguments.joined(separator: " ")]
		process.executableURL = URL(fileURLWithPath: "/bin/sh")
		process.terminationHandler = terminationHandler
		
		Logger(self).debug(process.arguments?.joined(separator: " ") ?? "")
		
		try process.run()
		
		return process
	}
	
	public static func internalStartVM(vmLocation: VMLocation, config: CakeConfig, waitIPTimeout: Int, startMode: StartMode, asSystem: Bool, promise: EventLoopPromise<String>? = nil) throws -> String {
		return try StartHandlerVMRun().start(vmLocation: vmLocation, waitIPTimeout: waitIPTimeout, startMode: startMode, asSystem: asSystem, promise: promise)
	}
	
	public static func startVM(on: EventLoop, vmLocation: VMLocation, config: CakeConfig, waitIPTimeout: Int, startMode: StartMode, asSystem: Bool) throws -> String {
		let promise: EventLoopPromise<String> = on.makePromise(of: String.self)
		
		promise.futureResult.whenComplete { result in
			switch result {
			case let .success(name):
				Logger(self).info("VM \(name) terminated")
			case let .failure(err):
				Logger(self).error(ServiceError("Failed to start VM \(vmLocation.name), \(err.localizedDescription)"))
			}
		}
		
		return try startVM(vmLocation: vmLocation, config: config, waitIPTimeout: waitIPTimeout, startMode: startMode, asSystem: asSystem, promise: promise)
	}
	
	public static func startVM(vmLocation: VMLocation, config: CakeConfig, waitIPTimeout: Int, startMode: StartMode, asSystem: Bool, promise: EventLoopPromise<String>? = nil) throws -> String {
		if FileManager.default.fileExists(atPath: vmLocation.diskURL.path) == false {
			throw ServiceError("VM does not exist")
		}
		
		if vmLocation.status == .running {
			return try vmLocation.waitIP(wait: 180, asSystem: asSystem)
		}
		
		return try StartHandlerVMRun().start(vmLocation: vmLocation, waitIPTimeout: waitIPTimeout, startMode: startMode, asSystem: asSystem, promise: promise)
	}
	
	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		let message = try StartHandler.startVM(on: on, vmLocation: self.location, config: self.config, waitIPTimeout: waitIPTimeout, startMode: .service, asSystem: asSystem)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.message = message
			}
		}
	}

}
