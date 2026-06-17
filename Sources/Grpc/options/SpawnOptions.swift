import ArgumentParser
import Foundation
import NIOPortForwarding
import CakeAgentLib

public struct SpawnOptions: ParsableArguments {
	public static let spawn = CommandConfiguration(
		commandName: "spawn",
		abstract: String(localized: "Create a VM using an existing root disk (physical device or image file)"),
		aliases: ["create-from-disk"]
	)

	public static let spawnAndStart = CommandConfiguration(
		commandName: "spawn-start",
		abstract: String(localized: "Create a VM using an existing root disk then start it")
	)

	@Option(name: [.customLong("cpus"), .customShort("c")], help: ArgumentHelp(String(localized: "Number of VM CPUs"), valueName: "num"))
	public var cpu: UInt16 = 1

	@Option(name: [.long, .customShort("m")], help: ArgumentHelp(String(localized: "VM memory size in megabytes"), valueName: "MB"))
	public var memory: UInt64 = 512

	@Option(name: [.customLong("disk")], help: ArgumentHelp(String(localized: "Additional attached disk"), valueName: "path"))
	public var attachedDisks: [DiskAttachement] = []

	@Option(name: [.customLong("os")], help: ArgumentHelp(String(localized: "OS type for the VM: linux or darwin"), valueName: "type"))
	public var os: VirtualizedOS = .linux

	@Option(name: [.long, .customShort("u")], help: ArgumentHelp(String(localized: "The user to use for the VM")))
	public var user: String = "admin"

	@Option(name: [.long, .customShort("w")], help: ArgumentHelp(String(localized: "The user password for login, none by default")))
	public var password: String?

	@Flag(name: [.long, .customShort("a")], help: ArgumentHelp(String(localized: "Start the VM automatically at boot")))
	public var autostart: Bool = false

	@Flag(name: [.long, .customShort("t")], help: ArgumentHelp(String(localized: "Enable nested virtualization if possible")))
	public var nested: Bool = false

	@Option(name: [.long, .customShort("g")], help: ArgumentHelp(String(localized: "The main existing group for the user")))
	public var mainGroup: String = "adm"

	@Option(name: [.customLong("other-group"), .customShort("o")], help: ArgumentHelp(String(localized: "The other existing group for the user")))
	public var otherGroup: [String] = ["sudo"]

	@Flag(name: [.long, .customShort("k")], help: ArgumentHelp(String(localized: "Tell if the user admin allow password for ssh")))
	public var clearPassword: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "Tell if cloud-init must be configured")))
	public var useCloudInit: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "Disables audio and entropy devices and switches to only Mac-specific input devices."), discussion: String(localized: "Useful for running a VM that can be suspended via suspend command.")))
	public var suspendable: Bool = false

	@Option(name: [.long, .customShort("i")], help: ArgumentHelp(String(localized: "Optional ssh-authorized-key file path for linux VM"), valueName: "path"))
	public var sshAuthorizedKey: String?

	@Option(help: .private)
	public var vendorData: String?

	@Option(name: [.customLong("cloud-init")], help: ArgumentHelp(String(localized: "Optional cloud-init user-data file path for linux VM"), discussion: String(localized: "Path or URL to a user-data cloud-init configuration, or '-' for stdin"), valueName: "path"))
	public var userData: String?

	@Option(help: ArgumentHelp(String(localized: "Optional cloud-init network-config file path for linux VM"), valueName: "path"))
	public var networkConfig: String?

	@Flag(help: ArgumentHelp(String(localized: "Whether to automatically reconfigure the VM's display to fit the window")))
	public var displayRefit: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "Allow to use dynamic port forwarding, default is false"), discussion: String(localized: "This option is supported on linux platforms only")))
	public var dynamicPortForwarding: Bool = false

	@Option(name: [.customLong("publish"), .customShort("p")], help: ArgumentHelp(String(localized: "Optional forwarded port for VM, syntax like docker"), discussion: String(localized: "value is like host:guest/(tcp|udp|both)"), valueName: "value"))
	public var forwardedPorts: [TunnelAttachement] = []

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp(String(localized: "Additional directory shares"), discussion: String(localized: "mount_help")))
	public var mounts: DirectorySharingAttachments = []

	@Option(name: [.customLong("network"), .customShort("n")], help: ArgumentHelp(String(localized: "Add a network interface to the instance"), discussion: String(localized: "network_help"), valueName: "spec"))
	public var networks: [BridgeAttachement] = []

	@Flag(name: [.customLong("bridged")], help: ArgumentHelp(String(localized: "Adds one `--network bridged` network.")))
	public var bridgedNetwork: Bool = false

	@Option(name: [.customLong("net.ifnames")], help: ArgumentHelp(String(localized: "Use ifnames for network interfaces instead of eth0, eth1, etc. This is the default on most modern Linux distributions.")))
	public var netIfnames: Bool = true

	@Option(name: [.customLong("display")], help: ArgumentHelp(String(localized: "Set the VM screen size.")))
	public var screenSize: ViewSize = ViewSize.standard

	@Option(
		name: [.customLong("socket")],
		help: ArgumentHelp(String(localized: "Allow to create virtio socket between guest and host, format like url: <bind|connect|tcp|udp>://<address>:<port number>/<file for unix socket>, eg. bind://dummy:1234/tmp/vsock.sock"), discussion: String(localized: "socket_help")))
	public var sockets: [SocketDevice] = []

	@Option(name: [.customLong("console")], help: ArgumentHelp(String(localized: "URL to the serial console (e.g. --console=unix, --console=file, or --console=\"fd://0,1\" or --console=\"unix:/tmp/serial.sock\")"), discussion: String(localized: "console_help"), valueName: "url"))
	public var consoleURL: ConsoleAttachment?

	@Option(name: [.customLong("nvram")], help: ArgumentHelp(String(localized: "Optional path to an existing NVRAM file (could be required for macOS VMs on Apple Silicon)"), valueName: "path"))
	public var nvram: String?

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	public var name: String

	@Argument(help: ArgumentHelp(String(localized: "Path to an existing root disk image or physical block device"), valueName: "root-disk"))
	public var root: String

	public init() {
	}

	public init(
		name: String,
		root: String,
		os: VirtualizedOS = .linux,
		cpu: UInt16 = 1,
		memory: UInt64 = 512,
		screenSize: ViewSize = .standard,
		attachedDisks: [DiskAttachement] = [],
		nvram: String? = nil,
		user: String = "admin",
		password: String? = nil,
		autostart: Bool = false,
		nested: Bool = false,
		suspendable: Bool = false,
		netIfnames: Bool = true,
		displayRefit: Bool = false,
		forwardedPorts: [TunnelAttachement] = [],
		mounts: DirectorySharingAttachments = [],
		networks: [BridgeAttachement] = [],
		sockets: [SocketDevice] = [],
		consoleURL: ConsoleAttachment? = nil,
		bridgedNetwork: Bool = false,
		dynamicPortForwarding: Bool = false
	) {
		self.name = name
		self.root = root
		self.os = os
		self.cpu = cpu
		self.memory = memory
		self.screenSize = screenSize
		self.attachedDisks = attachedDisks
		self.nvram = nvram
		self.user = user
		self.password = password
		self.autostart = autostart
		self.nested = nested
		self.suspendable = suspendable
		self.netIfnames = netIfnames
		self.displayRefit = displayRefit
		self.forwardedPorts = forwardedPorts
		self.mounts = mounts
		self.networks = networks
		self.sockets = sockets
		self.consoleURL = consoleURL
		self.bridgedNetwork = bridgedNetwork
		self.dynamicPortForwarding = dynamicPortForwarding
	}

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError(String(localized: "\(name) should be a local name"))
		}

		if nested && Utils.isNestedVirtualizationSupported() == false {
			self.nested = false
		}

		try self.forwardedPorts.forEach { port in
			if case .none = port.oneOf {
				throw ValidationError(String(localized: "Port is not set"))
			}

			if case .unixDomain(let value) = port.oneOf {
				if value.host.utf8.count > 103 {
					throw ValidationError(String(localized: "Unix domain socket name is too long"))
				}
				if value.guest.utf8.count > 103 {
					throw ValidationError(String(localized: "Unix domain socket name is too long"))
				}
			}
		}

		let expandedRoot = root.expandingTildeInPath
		guard FileManager.default.fileExists(atPath: expandedRoot) else {
			throw ValidationError(String(localized: "Root disk not found: \(root)"))
		}

		if let nvram {
			let expandedNvram = nvram.expandingTildeInPath
			guard FileManager.default.fileExists(atPath: expandedNvram) else {
				throw ValidationError(String(localized: "NVRAM file not found: \(nvram)"))
			}
		}
	}
}

extension SpawnOptions {
	public var allNetworks: [BridgeAttachement] {
		guard self.bridgedNetwork else { return self.networks }

		return self.networks.filter {
			$0.network != "bridged"
		} + [BridgeAttachement.bridgedNetwork()]
	}
}

extension VirtualizedOS: ExpressibleByArgument {
	public init?(argument: String) {
		self.init(rawValue: argument.lowercased())
	}

	public static var allValueStrings: [String] {
		["linux", "darwin"]
	}
}
