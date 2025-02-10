import ArgumentParser
import Foundation
import SystemConfiguration
import GRPC
import GRPCLib
import NIOCore
import NIOPosix

struct WaitIPHandler: CakedCommand {
	var name: String
	var wait: Int

	static func waitIPWithTart(name: String, wait: Int, asSystem: Bool, tartProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)
		let config = try vmLocation.config()
		let start: Date = Date.now
		var arguments: [String]
		var count = 0

		repeat {
			if let tartProcess = tartProcess, tartProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Tart process is not running", message: "")
			} else if vmLocation.status != .running {
				throw ServiceError("VM \(name) is not running")
			}

			// Try also arp if dhcp is disabled
			if config.networks.isEmpty == false || count & 1 == 1 {
				arguments = [ name, "--wait=1", "--resolver=arp"]
			} else {
				arguments = [ name, "--wait=1"]
			}

			if let runningIP = try? Shell.runTart(command: "ip", arguments: arguments) {
				return runningIP
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: "Unable to get IP for VM \(name)", message: "")
	}

	static func waitIPWithAgent(name: String, wait: Int, asSystem: Bool, vmrunProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)
		let listeningAddress = vmLocation.agentURL
		let certLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem))).createCertificats()
		let conn = CakeAgentConnection(eventLoop: Root.group.any(), listeningAddress: listeningAddress, certLocation: certLocation, timeout: 1, retries: .none)

		let start: Date = Date.now
		var count = 0

		repeat {
			if let vmrunProcess = vmrunProcess, vmrunProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Caked vmrun process is not running", message: "")
			} else if vmLocation.status != .running {
				throw ServiceError("VM \(name) is not running")
			}

			let result: EventLoopFuture<String?> = Root.group.any().makeFutureWithTask {
				if let infos = try? await conn.info() {
					if let runningIP = infos.ipaddresses.first {
						return runningIP
					}
				} else {
					return nil
				}

				return nil
			}

			if let runningIP = try result.wait() {
				return runningIP
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: "Unable to get IP for VM \(name)", message: "")
	}

	static func waitIP(name: String, wait: Int, asSystem: Bool, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		if Root.vmrunAvailable() {
			return try waitIPWithAgent(name: name, wait: wait, asSystem: asSystem, vmrunProcess: startedProcess)
		} else {
			return try waitIPWithTart(name: name, wait: wait, asSystem: asSystem, tartProcess: startedProcess)
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		on.submit {
			if Root.vmrunAvailable() {
				return try Self.waitIPWithAgent(name: name, wait: wait, asSystem: asSystem)
			} else {
				return try Self.waitIPWithTart(name: name, wait: wait, asSystem: asSystem)
			}
		}
	}

}
