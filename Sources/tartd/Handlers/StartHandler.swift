import ArgumentParser
import Foundation
import SystemConfiguration

struct StartHandler: TartdCommand {
	var name: String

	func run(asSystem: Bool) async throws -> String {
		let vmDir = try StorageLocation(asSystem: asSystem).find(name)

		try StartHandler.startVM(vmDir: vmDir)

		return "started \(name)"
	}

	public static func startVM(vmDir: VMLocation) throws {
		let config: [String:Any] = try Dictionary(contentsOf: vmDir.configURL) as [String:Any]
		let log: String = URL(fileURLWithPath: "output.log", relativeTo: vmDir.rootURL).absoluteURL.path()
		let process: Process = Process()
		var arguments: [String] = config["runningArguments"] as? [String] ?? []

		arguments.append("2>&1")
		arguments.append(">")
		arguments.append(log)

		process.standardError = FileHandle.nullDevice
		process.environment = ProcessInfo.processInfo.environment
		process.standardOutput = FileHandle.nullDevice
		process.standardInput = FileHandle.nullDevice
		process.arguments = [ "-c", "exec tart run \(vmDir.name) " + arguments.joined(separator: " ")]
		process.executableURL = URL(fileURLWithPath: "/bin/bash")

		do {
			try process.run()
		} catch {
			print(error)
			if process.terminationStatus != 0 {
				throw ServiceError("VM \"\(vmDir.name)\" exited with code \(process.terminationStatus)")
			} else {
				throw error
			}
		}
	}
}
