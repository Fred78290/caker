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

	static func waitIPWithLease(vmLocation: VMLocation, wait: Int, asSystem: Bool, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let config = try vmLocation.config()
		let start: Date = Date.now
		let macAddress = vmLocation.macAddress?.string ?? ""
		var leases: DHCPLeaseProvider
		var count = 0

		repeat {
			if let startedProcess = startedProcess, startedProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Caked vmrun process is not running", message: "")
			}

			// Try also arp if dhcp is disabled
			if config.networks.isEmpty == false || count & 1 == 1 {
				leases = try ARPParser()
			} else {
				leases = try DHCPLeaseParser()
			}

			if let runningIP = leases[macAddress] {
				return runningIP
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: "Unable to get IP for VM \(vmLocation.name)", message: "")
	}

	static func waitIPWithAgent(vmLocation: VMLocation, wait: Int, asSystem: Bool, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let listeningAddress = vmLocation.agentURL
		let certLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem))).createCertificats()
		let conn = CakeAgentConnection(eventLoop: Root.group.any(), listeningAddress: listeningAddress, certLocation: certLocation, timeout: 5, retries: .none)

		let start: Date = Date.now
		var count = 0

		repeat {
			if let startedProcess = startedProcess, startedProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Caked vmrun process is not running", message: "")
			}

			if let infos = try? conn.infoFuture().wait() {
				if let runningIP = infos.ipaddresses.first {
					return runningIP
				}
			}

			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		throw ShellError(terminationStatus: -1, error: "Unable to get IP for VM \(vmLocation.name)", message: "")
	}

	static func waitIP(name: String, wait: Int, asSystem: Bool, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)
		let config = try vmLocation.config()

		if vmLocation.status != .running {
			throw ServiceError("VM \(name) is not running")
		}

		if config.useCloudInit {
			return try waitIPWithAgent(vmLocation: vmLocation, wait: wait, asSystem: asSystem, startedProcess: startedProcess)
		} else {
			return try waitIPWithLease(vmLocation: vmLocation, wait: wait, asSystem: asSystem, startedProcess: startedProcess)
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> String {
		try Self.waitIP(name: name, wait: wait, asSystem: asSystem)
	}

}
