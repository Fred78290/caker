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

	static func waitIPWithTart(vmLocation: VMLocation, wait: Int, asSystem: Bool, tartProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let config = try vmLocation.config()
		let start: Date = Date.now
		var arguments: [String]
		var count = 0

		repeat {
			if let tartProcess = tartProcess, tartProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Tart process is not running", message: "")
			}

			// Try also arp if dhcp is disabled
			if config.networks.isEmpty == false || count & 1 == 1 {
				arguments = [ vmLocation.name, "--wait=1", "--resolver=arp"]
			} else {
				arguments = [ vmLocation.name, "--wait=1"]
			}

			if let runningIP = try? Shell.runTart(command: "ip", arguments: arguments) {
				return runningIP
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: "Unable to get IP for VM \(vmLocation.name)", message: "")
	}

	static func waitIPWithAgent(vmLocation: VMLocation, wait: Int, asSystem: Bool, vmrunProcess: ProcessWithSharedFileHandle? = nil) async throws -> String {
		let listeningAddress = vmLocation.agentURL
		let certLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem))).createCertificats()
		let conn = CakeAgentConnection(eventLoop: Root.group.any(), listeningAddress: listeningAddress, certLocation: certLocation, timeout: 5, retries: .none)

		let start: Date = Date.now
		var count = 0

		repeat {
			if let vmrunProcess = vmrunProcess, vmrunProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Caked vmrun process is not running", message: "")
			}

			if let infos = try? conn.info() {
				if let runningIP = infos.ipaddresses.first {
					return runningIP
				}
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: "Unable to get IP for VM \(vmLocation.name)", message: "")
	}

	static func waitIP(name: String, wait: Int, asSystem: Bool, startedProcess: ProcessWithSharedFileHandle? = nil) async throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)

		if vmLocation.status != .running {
			throw ServiceError("VM \(name) is not running")
		}

		if Root.vmrunAvailable() {
			return try await waitIPWithAgent(vmLocation: vmLocation, wait: wait, asSystem: asSystem, vmrunProcess: startedProcess)
		} else {
			return try waitIPWithTart(vmLocation: vmLocation, wait: wait, asSystem: asSystem, tartProcess: startedProcess)
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)

		if vmLocation.status != .running {
			throw ServiceError("VM \(name) is not running")
		}

		return on.makeFutureWithTask {
			if Root.vmrunAvailable() {
				return try await Self.waitIPWithAgent(vmLocation: vmLocation, wait: wait, asSystem: asSystem)
			} else {
				return try Self.waitIPWithTart(vmLocation: vmLocation, wait: wait, asSystem: asSystem)
			}
		}
	}

}
