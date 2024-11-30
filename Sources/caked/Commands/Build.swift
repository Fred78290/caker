import ArgumentParser

struct Build: AsyncParsableCommand, BuildArguments {
	static var configuration = CommandConfiguration(abstract: "Create a linux VM and initialize it with cloud-init")

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

	@Flag(help: ArgumentHelp("Enable nested virtualization if possible"))
	var nested: Bool = false

	@Option(name: [.long, .customLong("cloud")], help: ArgumentHelp("create a linux VM using a qcow2 cloud-image file or URL", valueName: "path"))
	var cloudImage: String?

	@Option(name: [.long, .customLong("alias")], help: ArgumentHelp("create a linux VM using a linux container cloud-image alias", valueName: "alias"))
	var aliasImage: String?

	@Option(name: [.long, .customLong("image")], help: ArgumentHelp("create a linux VM using a raw image file or URL", valueName: "path"))
	var fromImage: String?

	@Option(name: [.long, .customLong("oci")], help: ArgumentHelp("create a linux VM using an OCI image", valueName: "path"))
	var ociImage: String?

	@Option(name: [.customLong("remote"), .customShort("r")], help: ArgumentHelp("URL of images linuxcontainer", valueName: "url"))
	var remoteContainerServer: String = defaultSimpleStreamsServer

	@Option(name: [.long, .customShort("i")], help: ArgumentHelp("Optional ssh-authorized-key file path for linux VM", valueName: "path"))
	var sshAuthorizedKey: String?

	@Option(help: ArgumentHelp("Optional cloud-init vendor-data file path for linux VM", valueName: "path"))
	var vendorData: String?

	@Option(help: ArgumentHelp("Optional cloud-init user-data file path for linux VM", valueName: "path"))
	var userData: String?

	@Option(help: ArgumentHelp("Optional cloud-init network-config file path for linux VM", valueName: "path"))
	var networkConfig: String?

	@Flag(inversion: .prefixedNo, help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	var displayRefit: Bool = true

	func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		if StorageLocation(asSystem: false).exists(name) {
			throw ValidationError("\(name) already exists")
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
	}

	mutating func run() async throws {
		try await BuildHandler.build(name: self.name, arguments: self, asSystem: false)
	}
}
