import ArgumentParser
import Virtualization

struct Configure: AsyncParsableCommand, ConfigureArguments {
	static var configuration = CommandConfiguration(abstract: "Reconfigure VM")

	@Argument(help: "VM name")
	var name: String

	@Option(name: [.long, .customShort("c")], help: "Number of VM CPUs")
	var cpu: UInt16? = nil

	@Option(name: [.long, .customShort("m")], help: "VM memory size in megabytes")
	var memory: UInt64? = nil

	@Option(name: [.long, .customShort("d")], help: ArgumentHelp("Disk size in GB"))
	var diskSize: UInt16? = nil

	@Option(help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	var displayRefit: Bool? = nil

	@Option(name: [.long, .customShort("s")], help: ArgumentHelp("Tell if the VM must be start at boot"))
	var autostart: Bool? = nil

	@Option(help: ArgumentHelp("Enable nested virtualization if possible"))
	var nested: Bool?

	@Option(help: ArgumentHelp("Additional directory shares with an optional read-only and mount tag options (e.g. --dir=\"~/src/build\" or --dir=\"~/src/sources:ro\")", discussion: "See tart help for more infos", valueName: "[name:]path[:options]"))
	var dir: [String] = ["unset"]

	@Option(help: ArgumentHelp("Use bridged networking instead of the default shared (NAT) networking \n(e.g. --net-bridged=en0 or --net-bridged=\"Wi-Fi\")", discussion: "See tart help for more infos", valueName: "interface name"))
	var netBridged: [String] = ["unset"]

	@Option(help: ArgumentHelp("Use software networking instead of the default shared (NAT) networking", discussion: "See tart help for more infos"))
	var netSoftnet: Bool? = nil

	@Option(help: ArgumentHelp("Comma-separated list of CIDRs to allow the traffic to when using Softnet isolation\n(e.g. --net-softnet-allow=192.168.0.0/24)", valueName: "comma-separated CIDRs"))
	var netSoftnetAllow: String? = nil

	@Option(help: ("Restrict network access to the host-only network"))
	var netHost: Bool? = nil

	@Flag(help: ArgumentHelp("Generate a new random MAC address for the VM."))
	var randomMAC: Bool = false

	var mount: [String]? {
		get {
			if dir.contains("unset") == false {
				return nil
			}
			
			return dir
		}
	}
	
	var bridged: [String]? {
		get {
			if dir.contains("unset") == false {
				return nil
			}
			
			return dir
		}
	}


	mutating func run() async throws {
		try await ConfigureHandler.configure(name: self.name, arguments: self, asSystem: false)
	}
}
