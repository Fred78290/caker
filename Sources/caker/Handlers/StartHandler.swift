//
//  StartHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//
import Foundation
import CakedLib
import GRPCLib
import GRPC
import NIO

extension StartHandler {
	public static func startVM(client: CakedServiceClient?, vmURL: URL, screenSize: GRPCLib.ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, recoveryMode: Bool, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> StartedReply {

		guard let client, vmURL.isFileURL == false else {
			if Bundle.mustUseUnixTask {
				return try startVMSandboxed(vmURL: vmURL, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, recoveryMode: recoveryMode, runMode: runMode, promise: promise)
			}
			return try startVM(vmURL: vmURL, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, gcd: false, recoveryMode: recoveryMode, runMode: runMode, promise: promise)
		}

		return try StartedReply(client.start(.with {
			$0.name = vmURL.vmName
			$0.recoveryMode = recoveryMode
			if let screenSize {
				$0.screenSize = .with {
					$0.width = Int32(screenSize.width)
					$0.height = Int32(screenSize.height)
				}
			}

			if let vncPassword {
				$0.vncPassword = vncPassword
			}
			if let vncPort {
				$0.vncPort = Int32(vncPort)
			}
			$0.waitIptimeout = Int32(waitIPTimeout)
		}).response.wait().vms.started)
	}

	private static func startVMSandboxed(vmURL: URL, screenSize: GRPCLib.ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, recoveryMode: Bool, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> StartedReply {
		let location = try VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode)

		guard FileManager.default.fileExists(atPath: location.configURL.path) else {
			return StartedReply(name: location.name, ip: String.empty, started: false, reason: String(localized: "VM not found"))
		}

		if case .running = location.status {
			let ip = try location.waitIP(wait: waitIPTimeout, runMode: runMode)
			return StartedReply(name: location.name, ip: ip, started: true, reason: String(localized: "VM started"))
		}

		let config: CakeConfig = try location.config()
		var arguments: [String] = ["vmrun", location.configURL.absoluteURL.path, "--log-level=\(Logger.LoggingLevel().rawValue)"]
		try config.startNetworkServices(runMode: runMode)

		if startMode == .foreground {
			arguments.append("--ui")
		} else if startMode == .background {
			arguments.append("--vnc")
		} else if startMode == .service {
			arguments.append("--service")
			arguments.append("--vnc")
		}

		if recoveryMode {
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

		let standardOutput: FileHandle = startMode == .foreground || startMode == .attach || startMode == .service ? FileHandle.standardOutput : FileHandle.nullDevice
		let standardError: FileHandle = startMode == .foreground || startMode == .attach || startMode == .service ? FileHandle.standardError : FileHandle.nullDevice

		let vmName = location.name

		try Bundle.runCaked(
			with: arguments,
			standardInput: FileHandle.nullDevice,
			standardOutput: standardOutput,
			standardError: standardError,
			runMode: runMode
		) { error in
			if let promise {
				if let error {
					promise.fail(error)
				} else {
					promise.succeed(vmName)
				}
			}
		}

		do {
			try waitForRunningState(location: location, timeout: waitIPTimeout)
			let ip = try location.waitIP(config: config, wait: waitIPTimeout, runMode: runMode)
			return StartedReply(name: location.name, ip: ip, started: true, reason: String(localized: "VM started"))
		} catch {
			return StartedReply(name: location.name, ip: String.empty, started: false, reason: error.reason)
		}
	}

	private static func waitForRunningState(location: VMLocation, timeout: Int) throws {
		let start = Date.now

		repeat {
			if case .running = location.status {
				return
			}

			Thread.sleep(forTimeInterval: 0.1)
		} while Date.now.timeIntervalSince(start) < TimeInterval(timeout)

		throw ServiceError(String(localized: "VM \(location.name) is not running"))
	}
}
