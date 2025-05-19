import Foundation
import ArgumentParser
import NIOPortForwarding

public struct BuildOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: "Create a linux VM and initialize it with cloud-init")

	@Argument(help: "VM name")
	public var name: String

	@Option(name: [.customLong("cpus"), .customShort("c")], help: ArgumentHelp("Number of VM CPUs", valueName: "num"))
	public var cpu: UInt16 = 1

	@Option(name: [.long, .customShort("m")], help: ArgumentHelp("VM memory size in megabytes", valueName: "MB"))
	public var memory: UInt64 = 512

	@Option(name: [.customLong("disk-size"), .customShort("d")], help: ArgumentHelp("Disk size in GB", valueName: "GB"))
	public var diskSize: UInt16 = 10

	@Option(name: [.customLong("disk")], help: ArgumentHelp("Other attached disk", valueName: "path"))
	public var attachedDisks: [DiskAttachement] = []

	@Option(name: [.long, .customShort("u")], help: "The user to use for the VM")
	public var user: String = "admin"

	@Option(name: [.long, .customShort("w")], help: "The user password for login, none by default")
	public var password: String?

	@Option(name: [.long, .customShort("g")], help: "The main existing group for the user")
	public var mainGroup: String = "admin"

	@Flag(name: [.long, .customShort("k")], help: ArgumentHelp("Tell if the user admin allow password for ssh"))
	public var clearPassword: Bool = false

	@Flag(name: [.long, .customShort("a")], help: ArgumentHelp("Tell if the VM must be start at boot"))
	public var autostart: Bool = false

	@Flag(name: [.long, .customShort("t")], help: ArgumentHelp("Enable nested virtualization if possible"))
	public var nested: Bool = false

	@Argument(help: ArgumentHelp("create a linux VM using a cloud image", discussion: cloudimage_help, valueName: "url"))
	public var image: String = defaultUbuntuImage

	@Option(name: [.long, .customShort("i")], help: ArgumentHelp("Optional ssh-authorized-key file path for linux VM", valueName: "path"))
	public var sshAuthorizedKey: String?

	//@Option(help: ArgumentHelp("Optional cloud-init vendor-data file path for linux VM", valueName: "path"))
	@Option(help: .private)
	public var vendorData: String?

	@Option(name: [.customLong("cloud-init")], help: ArgumentHelp("Optional cloud-init user-data file path for linux VM", discussion: "Path or URL to a user-data cloud-init configuration, or '-' for stdin", valueName: "path"))
	public var userData: String?

	@Option(help: ArgumentHelp("Optional cloud-init network-config file path for linux VM", valueName: "path"))
	public var networkConfig: String?

	@Flag(help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	public var displayRefit: Bool = false

	@Flag(help: ArgumentHelp("Allow to use dynamic port forwarding, default is false", discussion: "This option is supported on linux platforms only"))
	public var dynamicPortForwarding: Bool = false

	@Option(name: [.customLong("publish"), .customShort("p")], help: ArgumentHelp("Optional forwarded port for VM, syntax like docker", discussion: "value is like host:guest/(tcp|udp|both)", valueName: "value"))
	public var forwardedPorts: [TunnelAttachement] = []

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares", discussion: mount_help))
	public var mounts: [DirectorySharingAttachment] = []

	@Option(name: [.customLong("network"), .customShort("n")], help: ArgumentHelp("Add a network interface to the instance", discussion: network_help , valueName: "spec"))
	public var networks: [BridgeAttachement] = []

	@Option(name: [.customLong("socket")], help: ArgumentHelp("Allow to create virtio socket between guest and host, format like url: <bind|connect|tcp|udp>://<address>:<port number>/<file for unix socket>, eg. bind://dummy:1234/tmp/vsock.sock", discussion: socket_help))
	public var sockets: [SocketDevice] = []

	@Option(name: [.customLong("console")], help: ArgumentHelp("URL to the serial console (e.g. --console=unix, --console=file, or --console=\"fd://0,1\" or --console=\"unix:/tmp/serial.sock\")", discussion: console_help, valueName: "url"))
	public var consoleURL: ConsoleAttachment?

	public init() {
	}

	public init(name: String, cpu: UInt16 = 2, memory: UInt64 = 2048, diskSize: UInt16 = 10,
	            attachedDisks: [DiskAttachement] = [],
	            user: String = "admin",
	            password: String? = "nil",
	            mainGroup: String = "admin",
	            clearPassword: Bool = false,
	            autostart: Bool = true,
	            nested: Bool = true,
	            image: String = defaultUbuntuImage,
	            sshAuthorizedKey: String? = nil,
	            vendorData: String? = nil,
	            userData: String? = nil,
	            networkConfig: String? = nil,
	            displayRefit: Bool = true,
	            forwardedPorts: [TunnelAttachement] = [],
	            mounts: [DirectorySharingAttachment] = ["~"].compactMap { DirectorySharingAttachment(argument: $0)},
	            networks: [BridgeAttachement] = [],
	            sockets: [SocketDevice]	= [],
	            consoleURL: ConsoleAttachment? = nil) {
		self.name = name
		self.cpu = cpu
		self.memory = memory
		self.diskSize = diskSize
		self.attachedDisks = attachedDisks
		self.user = user
		self.password = password
		self.mainGroup = mainGroup
		self.clearPassword = clearPassword
		self.autostart = autostart
		self.nested = nested
		self.image = image
		self.sshAuthorizedKey = sshAuthorizedKey
		self.vendorData = vendorData
		self.userData = userData
		self.networkConfig = networkConfig
		self.displayRefit = displayRefit
		self.forwardedPorts = forwardedPorts
		self.mounts = mounts
		self.networks = networks
		self.sockets = sockets
		self.consoleURL = consoleURL
		self.dynamicPortForwarding = false
	}

	public init(request: Caked_CommonBuildRequest) throws {
		self.name = request.name
		self.displayRefit = false

		if request.hasCpu {
			self.cpu = UInt16(request.cpu)
		} else {
			self.cpu = 1
		}

		if request.hasMemory {
			self.memory = UInt64(request.memory)
		} else {
			self.memory = 512
		}

		if request.hasDiskSize {
			self.diskSize = UInt16(request.diskSize)
		} else {
			self.diskSize = 20
		}

		if request.hasAttachedDisks {
			self.attachedDisks = try request.attachedDisks.components(separatedBy: ",").compactMap {
				try DiskAttachement(parseFrom: $0)
			}
		} else {
			self.attachedDisks = []
		}

		if request.hasUser {
			self.user = request.user
		} else {
			self.user = "admin"
		}

		if request.hasPassword {
			self.password = request.password
		} else {
			self.password = nil
		}

		if request.hasMainGroup {
			self.mainGroup = request.mainGroup
		} else {
			self.mainGroup = "admin"
		}

		if request.hasSshPwAuth {
			self.clearPassword = request.sshPwAuth
		} else {
			self.clearPassword = false
		}

		if request.hasNested {
			self.nested = request.nested
		} else {
			self.nested = true
		}

		if request.hasAutostart {
			self.autostart = request.autostart
		} else {
			self.autostart = false
		}

		if request.hasImage && request.image.isEmpty == false {
			self.image = request.image
		} else {
			self.image = defaultUbuntuImage
		}

		if request.hasSshAuthorizedKey && request.sshAuthorizedKey.isEmpty == false {
			self.sshAuthorizedKey = try Utils.saveToTempFile(request.sshAuthorizedKey)
		} else {
			self.sshAuthorizedKey = nil
		}

		if request.hasUserData && request.userData.isEmpty == false {
			self.userData = try Utils.saveToTempFile(request.userData)
		} else {
			self.userData = nil
		}

		if request.hasVendorData && request.vendorData.isEmpty == false {
			self.vendorData = try Utils.saveToTempFile(request.vendorData)
		} else {
			self.vendorData = nil
		}

		if request.hasNetworkConfig && request.networkConfig.isEmpty == false {
			self.networkConfig = try Utils.saveToTempFile(request.networkConfig)
		} else {
			self.networkConfig = nil
		}

		if request.hasForwardedPort && request.forwardedPort.isEmpty == false {
			self.forwardedPorts = request.forwardedPort.components(separatedBy: ",").compactMap { argument in
				return TunnelAttachement(argument: argument)
			}
		} else {
			self.forwardedPorts = []
		}

		if request.hasMounts && request.mounts.isEmpty == false {
			self.mounts = try request.mounts.components(separatedBy: ",").compactMap {
				try DirectorySharingAttachment(parseFrom: $0)
			}
		} else {
			self.mounts = []
		}

		if request.hasNetworks && request.networks.isEmpty == false {
			self.networks = try request.networks.components(separatedBy: ",").compactMap {
				try BridgeAttachement(parseFrom: $0) }
		} else {
			self.networks = []
		}

		if request.hasSockets && request.sockets.isEmpty == false {
			self.sockets = try request.sockets.components(separatedBy: ",").compactMap {
				try SocketDevice(parseFrom: $0)
			}
		} else {
			self.sockets = []
		}

		if request.hasConsole && request.console.isEmpty == false {
			self.consoleURL = ConsoleAttachment(argument: request.console)
		} else {
			self.consoleURL = nil
		}

		if request.hasDynamicPortForwarding {
			self.dynamicPortForwarding = request.dynamicPortForwarding
		} else {
			self.dynamicPortForwarding = false
		}
	}

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		if nested && Utils.isNestedVirtualizationSupported() == false {
			self.nested = false
		}

		try self.forwardedPorts.forEach { port in
			if case .none = port.oneOf {
				throw ValidationError("Port is not set")
			}
			if case .unixDomain(let value) = port.oneOf {
				if value.host.utf8.count > 103 {
					throw ValidationError("Unix domain socket name is too long")
				}
				if value.guest.utf8.count > 103 {
					throw ValidationError("Unix domain socket name is too long")
				}
			}
		}
	}
}

