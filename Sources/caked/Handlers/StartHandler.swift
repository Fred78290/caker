import ArgumentParser
import Foundation
import SystemConfiguration

struct StartHandler: CakedCommand {
	var nested: Bool = true
	var foreground: Bool = false
	var name: String

	func run(asSystem: Bool) async throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)

		try StartHandler.startVM(vmLocation: vmLocation, nested: self.nested, foreground: foreground)

		return "started \(name)"
	}

	static func runningArguments(vmLocation: VMLocation, nested: Bool) throws -> [String] {
		let extras: URL = URL(fileURLWithPath: "extras.json", relativeTo: vmLocation.configURL)

		if try extras.exists() {
			let config: [String:Any] = try Dictionary(contentsOf: extras) as [String:Any]

			return config["runningArguments"] as? [String] ?? []
		} else {
			let cdrom = URL(fileURLWithPath: cloudInitIso, relativeTo: vmLocation.diskURL).absoluteURL
			var arguments: [String] = ["--no-graphics", "--no-audio"]

			if nested {
				arguments.append("--nested")
			}

			if try cdrom.exists() {
				arguments.append("--disk=\(cdrom.path())")
			}

			return arguments
		}
	}

	public static func startVM(vmLocation: VMLocation, args: [String], foreground: Bool) throws {
		let log: String = URL(fileURLWithPath: "output.log", relativeTo: vmLocation.rootURL).absoluteURL.path()
		let process: Process = Process()
		let cakeHome = try Utils.getHome(asSystem: runAsSystem)
		var environment = ProcessInfo.processInfo.environment
		var arguments: [String] = []

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

		do {
			try process.run()
		} catch {
			print(error)
			if process.terminationStatus != 0 {
				throw ServiceError("VM \"\(vmLocation.name)\" exited with code \(process.terminationStatus)")
			} else {
				throw error
			}
		}
	}

	public static func startVM(vmLocation: VMLocation, nested: Bool, foreground: Bool = false) throws {
		try Self.startVM(vmLocation: vmLocation, args: try Self.runningArguments(vmLocation: vmLocation, nested: nested), foreground: foreground)
	}
}
