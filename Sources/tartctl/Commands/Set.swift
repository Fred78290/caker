import ArgumentParser
import Foundation
import GRPCLib

struct VMDisplayConfig : CustomStringConvertible, ExpressibleByArgument {
	var width: Int = 1024
	var height: Int = 768

	var description: String {
		"\(width)x\(height)"
	}

	init(width: Int, height: Int) {
		self.width = width
		self.height = height
	}

	public init(argument: String) {
		let parts = argument.components(separatedBy: "x").map {
			Int($0) ?? 0
		}
		self.width = parts[0]
		self.height = parts[1]
	}
}

struct Set: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "set", abstract: "Modify VM's configuration")

	@Argument(help: "VM name")
	var name: String

	@Option(help: "Number of VM CPUs")
	var cpu: UInt16?

	@Option(help: "VM memory size in megabytes")
	var memory: UInt64?

	@Option(help: "VM display resolution in a format of <width>x<height>. For example, 1200x800")
	var display: VMDisplayConfig?

	@Flag(help: ArgumentHelp("Generate a new random MAC address for the VM."))
	var randomMAC: Bool = false

	#if arch(arm64)
		@Flag(help: ArgumentHelp("Generate a new random serial number for the macOS VM."))
	#endif
	var randomSerial: Bool = false

	@Option(help: ArgumentHelp("Replace the VM's disk contents with the disk contents at path.", valueName: "path"))
	var disk: String?

	@Option(help: ArgumentHelp("Resize the VMs disk to the specified size in GB (note that the disk size can only be increased to avoid losing data)",
	                           discussion: """
	                           Disk resizing works on most cloud-ready Linux distributions out-of-the box (e.g. Ubuntu Cloud Images
	                           have the \"cloud-initramfs-growroot\" package installed that runs on boot) and on the rest of the
	                           distributions by running the \"growpart\" or \"resize2fs\" commands.

	                           For macOS, however, things are a bit more complicated: you need to remove the recovery partition
	                           first and then run various \"diskutil\" commands, see Tart's packer plugin source code for more
	                           details[1].

	                           [1]: https://github.com/cirruslabs/packer-plugin-tart/blob/main/builder/tart/step_disk_resize.go
	                           """))
	var diskSize: UInt16?

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: "set", arguments: arguments)).response.wait()
	}
}

