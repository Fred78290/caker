import Foundation

struct CreateHandler: TartdCommand {
	var name: String = ""
	var fromIPSW: String?
	var linux: Bool = false
	var diskSize: UInt16 = 50

	func run() async throws -> String {
		var arguments: [String] = []

		arguments.append(name)

		if let fromIPSW = self.fromIPSW {
			arguments.append("--from-ipsw=\(fromIPSW)")
		}

		if linux {
			arguments.append("--linux")
		}

		if diskSize != 50 {
			arguments.append("--disk-size=\(diskSize)")
		}

		return try Shell.runTart(command: "create", arguments: arguments)
	}
}
