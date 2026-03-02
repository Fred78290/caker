import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Virtualization
import NIOPortForwarding

extension VirtualizedOS {
	public init?(_ from: Caked.Configuration.VirtualizedOS) {
		switch from {
		case .darwin:
			self = .darwin
		case .linux:
			self = .linux
		default:
			return nil
		}
	}
}

extension Architecture {
	public init?(_ from: Caked.Configuration.Architecture) {
		switch from {
		case .amd64:
			self = .amd64
		case .arm64:
			self = .arm64
		default:
			return nil
		}
	}
}

extension VMBuilder.ImageSource {
	public init?(_ from: Caked.Configuration.ImageSource) {
		switch from {
		case .raw:
			self = .raw
		case .cloud:
			self = .cloud
		case .oci:
			self = .oci
		case .template:
			self = .template
		case .stream:
			self = .stream
		case .iso:
			self = .iso
		case .ipsw:
			self = .ipsw
		default:
			return nil
		}
	}
}

extension SupportedPlatform {
	public init(_ from: Caked.Configuration.SupportedPlatform) {
		switch from {
		case .ubuntu:
			self = .ubuntu
		case .centos:
			self = .centos
		case .macos:
			self = .macos
		case .windows:
			self = .windows
		case .debian:
			self = .debian
		case .fedora:
			self = .fedora
		case .redhat:
			self = .redhat
		case .openSuse:
			self = .openSUSE
		case .alpine:
			self = .alpine
		default:
			self = .unknown
		}
	}
}

extension DiskAttachement {
	public init(_ from: Caked.Configuration.DiskAttachment) {
		self.init()

		self.diskPath = from.diskPath
		self.diskOptions = DiskOptions(readOnly: from.diskOptions.readOnly, syncMode: from.diskOptions.syncMode, cachingMode: from.diskOptions.cachingMode)
	}
}

extension DirectorySharingAttachment {
	public init(_ from: Caked.Configuration.DirectorySharingAttachment) {
		self.init()

		self._source = from.source

		if from.hasName {
			self._name = from.name
		}

		if from.hasDestination {
			self._destination = from.destination
		}
		
		if from.hasUid {
			self._uid = Int(from.uid)
		}

		if from.hasGid {
			self._gid = Int(from.gid)
		}
	}
}

extension BridgeAttachement {
	public init(_ from: Caked.Configuration.BridgeAttachment) {
		self.init(network: from.network, mode: .init(argument: from.mode), macAddress: from.hasMacAddress ? from.macAddress : nil)
	}
}

extension SocketDevice {
	public init(_ from: Caked.Configuration.SocketDevice) {
		self.init(mode: .init(from.mode)!, port: Int(from.port), bind: from.bind)
	}
}

extension MappedPort.Proto {
	public init(_ from: String) {
		switch from {
		case "tcp":
			self = .tcp
		case "udp":
			self = .udp
		case "both":
			self = .both
		default:
			self = .none
		}
	}
}

extension TunnelAttachement {
	public init(_ from: Caked.Configuration.TunnelAttachement) {
		self.init()
		switch from.port {
		case .forward(let value):
			self.init(host: Int(value.hostPort), guest: Int(value.guestPort), proto: .init(value.protocol))
		case .unixDomain(let value):
			self.init(host: value.hostPath, guest: value.guestPath, proto: .init(value.protocol))
		default:
			self.oneOf = .none
		}
	}
}

public struct CakedConfiguration: VirtualMachineConfiguration {
	public var locationURL: URL
	public var version: Int
	public var os: VirtualizedOS
	public var arch: Architecture
	public var diskSize: Int
	public var cpuCountMin: Int
	public var suspendable: Bool
	public var cpuCount: Int
	public var memorySizeMin: UInt64
	public var memorySize: UInt64
	public var macAddress: VZMACAddress?
	public var source: VMBuilder.ImageSource
	public var osName: String?
	public var osRelease: String?
	public var dynamicPortForwarding: Bool
	public var displayRefit: Bool
	public var instanceID: String
	public var dhcpClientID: String?
	public var sshPrivateKeyPath: String?
	public var sshPrivateKeyPassphrase: String?
	public var configuredUser: String
	public var configuredPassword: String?
	public var configuredGroup: String
	public var configuredGroups: [String]?
	public var configuredPlatform: SupportedPlatform
	public var clearPassword: Bool
	public var ifname: Bool
	public var autostart: Bool
	public var agent: Bool
	public var firstLaunch: Bool
	public var nested: Bool
	public var attachedDisks: [DiskAttachement]
	public var mounts: DirectorySharingAttachments
	public var networks: [BridgeAttachement]
	public var useCloudInit: Bool
	public var sockets: [SocketDevice]
	public var console: ConsoleAttachment?
	public var forwardedPorts: [TunnelAttachement]
	public var runningIP: String?
	public var display: DisplaySize
	public var vncPassword: String

	#if arch(arm64)
	public var ecid: VZMacMachineIdentifier
	public var hardwareModel: VZMacHardwareModel?
	#endif

	public init(_ from: Caked.Configuration) {
		// Map fields directly when available on `from`. For fields not present, use safe defaults.
		self.locationURL = URL(fileURLWithPath: "/dev/null")
		self.version = Int(from.version)
		self.os = .init(from.os)!
		self.arch = .init(from.arch)!
		self.diskSize = Int(from.diskSize)
		self.cpuCountMin = Int(from.cpuCountMin)
		self.suspendable = from.suspendable
		self.cpuCount = Int(from.cpuCount)
		self.memorySizeMin = from.memorySizeMin
		self.memorySize = from.memorySize
		self.macAddress = VZMACAddress(string: from.macAddress)
		self.source = .init(from.source)!
		self.osName = from.osName
		self.osRelease = from.osRelease
		self.dynamicPortForwarding = from.dynamicPortForwarding
		self.displayRefit = from.displayRefit
		self.instanceID = from.instanceID
		self.dhcpClientID = from.dhcpClientID
		self.sshPrivateKeyPath = from.sshPrivateKeyPath
		self.sshPrivateKeyPassphrase = from.sshPrivateKeyPassphrase
		self.configuredUser = from.configuredUser
		self.configuredPassword = from.configuredPassword
		self.configuredGroup = from.configuredGroup
		self.configuredGroups = from.configuredGroups
		self.configuredPlatform = .init(from.configuredPlatform)
		self.clearPassword = from.clearPassword_p
		self.ifname = from.ifname
		self.autostart = from.autostart
		self.agent = from.agent
		self.firstLaunch = from.firstLaunch
		self.nested = from.nested
		self.attachedDisks = from.attachedDisks.map({.init($0)})
		self.mounts = from.mounts.map({.init($0)})
		self.networks = from.networks.map({.init($0)})
		self.useCloudInit = from.useCloudInit
		self.sockets = from.sockets.map({.init($0)})
		if from.hasConsole {
			self.console = .init(argument: from.console.url)
		}
		self.forwardedPorts = from.forwardedPorts.map({.init($0)})
		self.runningIP = from.runningIp
		if from.hasDisplay {
			let display = from.display
			
			self.display = .init(width: Int(display.width), height: Int(display.height))
		} else {
			self.display = .init(width: 1024, height: 768)
		}
		self.vncPassword = from.vncPassword
		
		#if arch(arm64)
		self.ecid = .init()

		if from.hasEcid {
			if let ecid = VZMacMachineIdentifier(dataRepresentation: Data(base64Encoded: from.ecid)!) {
				self.ecid = ecid
			}
		}
		
		if from.hasHardwareModel {
			if let hardwareModel = VZMacHardwareModel(dataRepresentation: Data(base64Encoded: from.hardwareModel)!) {
				self.hardwareModel = hardwareModel
			}
		}
		#endif
	}
}

extension Caked.Configuration {
	var configuration: CakedConfiguration {
		CakedConfiguration(self)
	}
}

public struct InfosHandler {
	public static func infos(name: String, runMode: Utils.RunMode, client: CakeAgentHelper, callOptions: CallOptions?) throws -> (infos: VMInformations, config: CakeConfig) {
		let location = try StorageLocation(runMode: runMode).find(name)
		let config: CakeConfig = try location.config()
		var infos: VMInformations

		if location.status == .running {
			infos = .init(from: try client.info(callOptions: callOptions))
			if let vncURL = try? createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).vncURL {
				infos.vncURL = vncURL.map(\.absoluteString)
			} else {
				infos.vncURL = nil
			}
		} else {
			var diskInfos: [DiskInfo] = []

			diskInfos.append(DiskInfo(device: URL(fileURLWithPath: "disk.img", relativeTo: config.location).absoluteURL.path, mount: "/", fsType: "native", total: UInt64(try location.diskSize()), free: 0, used: 0))

			for disk in config.attachedDisks {
				let diskURL = URL(fileURLWithPath: disk.diskPath, relativeTo: config.location).absoluteURL

				diskInfos.append(DiskInfo(device: diskURL.path, mount: "not mounted", fsType: "native", total: UInt64(try diskURL.sizeBytes()), free: 0, used: 0))
			}

			infos = VMInformations.with {
				$0.osname = config.os.rawValue
				$0.status = .stopped
				$0.cpuCount = Int32(config.cpuCount)
				$0.diskInfos = diskInfos
				$0.memory = .with {
					$0.total = config.memorySize
				}

				if let runningIP = config.runningIP {
					$0.ipaddresses = [runningIP]
				}
			}
		}

		infos.name = name
		infos.mounts = config.mounts.map { $0.description }
		infos.attachedNetworks = config.networks.map { AttachedNetwork(network: $0.network, mode: $0.mode?.description ?? nil, macAddress: $0.macAddress ?? nil) }
		infos.tunnelInfos = config.forwardedPorts.compactMap { $0.tunnelInfo }
		infos.socketInfos = config.sockets.compactMap { $0.socketInfo }

		return (infos, config)
	}
}
