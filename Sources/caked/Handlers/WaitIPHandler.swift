import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import NIOCore

struct WaitIPHandler: CakedCommand {
	var name: String
	var wait: Int

	static func waitIP(name: String, wait: Int, asSystem: Bool, tartProcess: Process? = nil) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)
		let config = try CakeConfig(baseURL: vmLocation.configURL)
/*		let arguments: [String]

		if config.netBridged.isEmpty {
			arguments = [ name, "--wait=\(wait)"]
		} else {
			arguments = [ name, "--wait=\(wait)", "--resolver=arp"]
		}

		return try Shell.runTart(command: "ip", arguments: arguments)
*/

		let start: Date = Date.now
		var arguments: [String]
		var count = 0

		repeat {
			if let tartProcess = tartProcess, tartProcess.isRunning == false {
				throw ShellError(terminationStatus: -1, error: "Tart process is not running", message: "")
			}

			// Try also arp if dhcp is disabled
			if config.netBridged.isEmpty == false || count & 1 == 1 {
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

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		on.submit {
			return try Self.waitIP(name: self.name, wait: self.wait, asSystem: runAsSystem)
		}
	}

}
