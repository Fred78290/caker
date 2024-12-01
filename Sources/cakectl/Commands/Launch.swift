import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Launch : GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Create a linux VM, initialize it with cloud-init and launch in background")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	@Option(name: [.long, .customShort("c")], help: "Number of VM CPUs")
	var cpu: UInt16 = 1

	@Option(name: [.long, .customShort("m")], help: "VM memory size in megabytes")
	var memory: UInt64 = 512

	@Option(name: [.long, .customShort("d")], help: ArgumentHelp("Disk size in GB"))
	var diskSize: UInt16 = 20

	@Option(name: [.long, .customShort("u")], help: "The user to use for the VM")
	var user: String = "admin"

	@Option(name: [.long, .customShort("g")], help: "The main existing group for the user")
	var mainGroup: String = "adm"

	@Flag(name: [.long, .customShort("k")], help: ArgumentHelp("Tell if the user admin allow password for ssh"))
	var clearPassword: Bool = false

	@Flag(name: [.long, .customShort("s")], help: ArgumentHelp("Tell if the VM must be start at boot"))
	var autostart: Bool = false

	@Option(name: [.long, .customLong("cloud")], help: ArgumentHelp("create a linux VM using a qcow2 cloud-image file or URL", valueName: "path"))
	var cloudImage: String?

	@Option(name: [.long, .customLong("alias")], help: ArgumentHelp("create a linux VM using a linux container cloud-image alias", valueName: "alias"))
	var aliasImage: String?

	@Option(name: [.long, .customLong("image")], help: ArgumentHelp("create a linux VM using a raw image file or URL", valueName: "path"))
	var fromImage: String?

	@Option(name: [.long, .customLong("oci")], help: ArgumentHelp("create a linux VM using an OCI image", valueName: "path"))
	var ociImage: String?

	@Option(name: [.long, .customShort("i")], help: ArgumentHelp("Optional ssh-authorized-key file path for linux VM", valueName: "path"))
	var sshAuthorizedKey: String?

	@Option(name: [.customLong("remote"), .customShort("r")], help: ArgumentHelp("URL of images linuxcontainer", valueName: "url"))
	var remoteContainerServer: String = defaultSimpleStreamsServer

	@Option(help: ArgumentHelp("Optional cloud-init vendor-data file path for linux VM", valueName: "path"))
	var vendorData: String?

	@Option(help: ArgumentHelp("Optional cloud-init user-data file path for linux VM", valueName: "path"))
	var userData: String?

	@Option(help: ArgumentHelp("Optional cloud-init network-config file path for linux VM", valueName: "path"))
	var networkConfig: String?

	@Option(help: ArgumentHelp("Additional directory shares with an optional read-only and mount tag options (e.g. --dir=\"~/src/build\" or --dir=\"~/src/sources:ro\")", discussion: "See tart help for more infos", valueName: "[name:]path[:options]"))
	var dir: [String] = []

	@Option(help: ArgumentHelp("Use bridged networking instead of the default shared (NAT) networking \n(e.g. --net-bridged=en0 or --net-bridged=\"Wi-Fi\")", discussion: "See tart help for more infos", valueName: "interface name"))
	var netBridged: [String] = []

	@Flag(help: ArgumentHelp("Use software networking instead of the default shared (NAT) networking", discussion: "See tart help for more infos"))
	var netSoftnet: Bool = false

	@Option(help: ArgumentHelp("Comma-separated list of CIDRs to allow the traffic to when using Softnet isolation\n(e.g. --net-softnet-allow=192.168.0.0/24)", valueName: "comma-separated CIDRs"))
	var netSoftnetAllow: String?

	@Flag(help: ArgumentHelp("Restrict network access to the host-only network"))
	var netHost: Bool = false

	@Flag(help: ArgumentHelp("Enable nested virtualization if possible"))
	var nested: Bool = false

	@Flag(inversion: .prefixedNo, help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	var displayRefit: Bool = true

	@Option(name: [.customLong("publish"), .customShort("p")], help: ArgumentHelp("Optional forwarded port for VM, syntax like docker", valueName: "host:guest/(tcp|udp|both)"))
	var forwardedPort: [ForwardedPort] = []

	func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		if fromImage == nil && cloudImage == nil && ociImage == nil && aliasImage == nil{
			throw ValidationError("Please specify either --from-img url or --cloud-image url or --oci-image url or --alias-image container image!")
		}

		var count = 0

		if fromImage != nil {
			count += 1
		}

		if cloudImage != nil {
			count += 1
		}

		if ociImage != nil{
			count += 1
		}

		if aliasImage != nil{
			count += 1
		}

		if count > 1 {
			throw ValidationError("--from-img url and --cloud-image url and --oci-image url and --alias-image are mutually exclusive!")
		}

		// check that not more than one network option is specified
		var netFlags = 0
		if netBridged.count > 0 { netFlags += 1 }
		if netSoftnet { netFlags += 1 }
		if netHost { netFlags += 1 }

		if netFlags > 1 {
			throw ValidationError("--net-bridged, --net-softnet and --net-host are mutually exclusive")
		}
	}

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.launch(Caked_LaunchRequest(command: self), callOptions: callOptions).response.wait()
	}
}
