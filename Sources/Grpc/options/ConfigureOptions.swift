import ArgumentParser
import Foundation
import NIOPortForwarding
import CakeAgentLib

public struct ConfigureOptions: ParsableArguments, Sendable {
	public static let configuration = CommandConfiguration(abstract: "Reconfigure VM")

	@Argument(help: "VM name")
	public var name: String

	@Option(name: [.long, .customShort("u")], help: "Reconfigure the login user")
	public var user: String? = nil

	@Option(name: [.long, .customShort("w")], help: "Reconfigure the login password")
	public var password: String? = nil

	@Option(name: [.customLong("cpus"), .customShort("c")], help: ArgumentHelp("Number of VM CPUs", valueName: "num"))
	public var cpu: UInt16? = nil

	@Option(name: [.long, .customShort("m")], help: ArgumentHelp("VM memory size in megabytes", valueName: "MB"))
	public var memory: UInt64? = nil

	@Option(name: [.customLong("disk-size"), .customShort("d")], help: ArgumentHelp("Disk size in GB", valueName: "GB"))
	public var diskSize: UInt16? = nil

	@Option(name: [.customLong("disk")], help: ArgumentHelp("Other attached disk", valueName: "path"))
	public var disks: [String] = ["unset"]

	@Option(name: [.long, .customShort("a")], help: ArgumentHelp("Tell if the VM must be start at boot"))
	public var autostart: Bool? = nil

	@Option(name: [.long, .customShort("t")], help: ArgumentHelp("Enable nested virtualization if possible"))
	public var nested: Bool?

	#if arch(arm64)
		@Option(help: ArgumentHelp("Disables audio and entropy devices and switches to only Mac-specific input devices.", discussion: "Useful for running a VM that can be suspended via suspend command."))
	#endif
	public var suspendable: Bool?

	@Option(help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	public var displayRefit: Bool? = nil

	@Option(help: ArgumentHelp("Allow to use dynamic port forwarding, default is false", discussion: "This option is supported on linux platforms only"))
	public var dynamicPortForwarding: Bool? = nil

	@Option(name: [.customLong("publish"), .customShort("p")], help: ArgumentHelp("Optional forwarded port for VM, syntax like docker", discussion: "value is like host:guest/(tcp|udp|both)", valueName: "value"))
	internal var published: [String] = ["unset"]

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares", discussion: mount_help, valueName: "[name:]path[:options]"))
	internal var mount: [String] = ["unset"]

	@Option(name: [.customLong("network"), .customShort("n")], help: ArgumentHelp("Add a network interface to the instance", discussion: network_help, valueName: "<spec>"))
	internal var network: [String] = ["unset"]

	@Flag(help: ArgumentHelp("Generate a new random MAC address for the VM."))
	public var randomMAC: Bool = false

	@Option(name: [.customLong("display")], help: "Set the VM screen size.")
	public var screenSize: VMScreenSize? = nil

	@Option(
		name: [.customLong("socket")],
		help: ArgumentHelp("Allow to create virtio socket between guest and host, format like url: <bind|connect|tcp|udp>://<address>:<port number>/<file for unix socket>, eg. bind://dummy:1234/tmp/vsock.sock", discussion: socket_help))
	internal var socket: [String] = ["unset"]

	@Option(name: [.customLong("console")], help: ArgumentHelp("URL to the serial console (e.g. --console=unix, --console=file, or --console=\"fd://0,1\" or --console=\"unix:/tmp/serial.sock\")", discussion: console_help, valueName: "url"))
	public var console: String?

	public init(request: Caked_ConfigureRequest) {
		self.name = request.name
		self.displayRefit = false

		if request.hasUser {
			self.user = request.user
		} else {
			self.user = nil
		}

		if request.hasPassword {
			self.password = request.password
		} else {
			self.password = nil
		}

		if request.hasCpu {
			self.cpu = UInt16(request.cpu)
		} else {
			self.cpu = nil
		}

		if request.hasMemory {
			self.memory = UInt64(request.memory)
		} else {
			self.memory = nil
		}

		if request.hasDiskSize {
			self.diskSize = UInt16(request.diskSize)
		} else {
			self.diskSize = nil
		}

		if request.hasNested {
			self.nested = request.nested
		} else {
			self.nested = nil
		}

		if request.hasAutostart {
			self.autostart = request.autostart
		} else {
			self.autostart = nil
		}

		if request.hasAttachedDisks {
			self.disks = request.attachedDisks.components(separatedBy: String.grpcSeparator)
		} else {
			self.disks = ["unset"]
		}

		if request.hasMounts {
			self.mount = request.mounts.components(separatedBy: String.grpcSeparator)
		} else {
			self.mount = ["unset"]
		}

		if request.hasNetworks {
			self.network = request.networks.components(separatedBy: String.grpcSeparator)
		} else {
			self.network = ["unset"]
		}

		if request.hasRandomMac {
			self.randomMAC = request.randomMac
		}

		if request.hasForwardedPort {
			self.published = request.forwardedPort.components(separatedBy: String.grpcSeparator)
		} else {
			self.published = ["unset"]
		}

		if request.hasSockets {
			self.socket = request.sockets.components(separatedBy: String.grpcSeparator)
		} else {
			self.socket = []
		}

		if request.hasConsole {
			self.console = request.console
		}

		if request.hasDynamicPortForwarding {
			self.dynamicPortForwarding = request.dynamicPortForwarding
		} else {
			self.dynamicPortForwarding = nil
		}

		if request.hasSuspendable {
			self.suspendable = request.suspendable
		} else {
			self.suspendable = nil
		}

		if request.hasScreenSize {
			self.screenSize = VMScreenSize(width: Int(request.screenSize.width), height: Int(request.screenSize.height))
		} else {
			self.screenSize = nil
		}
	}

	public var consoleURL: ConsoleAttachment? {
		if let console = self.console {
			return ConsoleAttachment(argument: console)
		}

		return nil
	}

	public var attachedDisks: [DiskAttachement]? {
		if disks.contains("unset") {
			return nil
		}

		return disks.compactMap {
			DiskAttachement(argument: $0)
		}
	}

	public var forwardedPort: [TunnelAttachement]? {
		if published.contains("unset") {
			return nil
		}

		return published.compactMap {
			TunnelAttachement(argument: $0)
		}
	}

	public var sockets: [SocketDevice]? {
		if socket.contains("unset") {
			return nil
		}

		return socket.compactMap { SocketDevice(argument: $0) }
	}

	public var mounts: DirectorySharingAttachments? {
		if mount.contains("unset") {
			return nil
		}

		return mount.compactMap {
			DirectorySharingAttachment(argument: $0)
		}
	}

	public var networks: [BridgeAttachement]? {
		if network.contains("unset") {
			return nil
		}

		return network.compactMap { BridgeAttachement(argument: $0) }
	}

	mutating public func setMount(value: [String] = []) {
		mount = value
	}

	mutating public func setNetwork(value: [String] = []) {
		network = value
	}

	mutating public func setPublished(value: [String] = []) {
		published = value
	}

	mutating public func setSocket(value: [String] = []) {
		socket = value
	}

	public init() {
	}

	public func validate() throws {
		if let forwardedPorts = self.forwardedPort {
			try forwardedPorts.forEach { port in
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
}
