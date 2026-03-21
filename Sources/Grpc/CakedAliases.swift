import Foundation
import GRPC
import CakeAgentLib
import NIOPortForwarding

public typealias CakedServiceClient = Caked_ServiceNIOClient

public typealias Caked = Caked_Caked

public typealias Caked_ImageRequest = Caked.ImageRequest
public typealias Caked_ImageCommand = Caked.ImageRequest.ImageCommand

public typealias Caked_LoginRequest = Caked.LoginRequest
public typealias Caked_LogoutRequest = Caked.LogoutRequest
public typealias Caked_CloneRequest = Caked.CloneRequest
public typealias Caked_PushRequest = Caked.PushRequest

public typealias Caked_MountRequest = Caked.MountRequest
public typealias Caked_MountVirtioFS = Caked.MountRequest.MountVirtioFS

public typealias Caked_NetworkRequest = Caked.NetworkRequest
public typealias Caked_ConfigureNetworkRequest = Caked.NetworkRequest.ConfigureNetworkRequest
public typealias Caked_CreateNetworkRequest = Caked.NetworkRequest.CreateNetworkRequest

public typealias Caked_PurgeRequest = Caked.PurgeRequest
public typealias Caked_RemoteRequest = Caked.RemoteRequest
public typealias Caked_RemoteCommand = Caked.RemoteRequest.RemoteCommand
public typealias Caked_Reply = Caked.Reply
public typealias Caked_DeleteRemoteReply = Caked.Reply.RemoteReply.DeleteRemoteReply
public typealias Caked_CreateRemoteReply = Caked.Reply.RemoteReply.CreateRemoteReply

public typealias Caked_ImageReply = Caked.Reply.ImageReply
public typealias Caked_ImageInfo = Caked.Reply.ImageReply.ImageInfo
public typealias Caked_ImageInfoReply = Caked.Reply.ImageReply.ImageInfoReply
public typealias Caked_ListImagesInfo = Caked.Reply.ImageReply.ImageInfo
public typealias Caked_ListImagesInfoReply = Caked.Reply.ImageReply.ListImagesInfoReply
public typealias Caked_PulledImageInfo = Caked.Reply.ImageReply.PulledImageInfoReply.PulledImageInfo
public typealias Caked_PulledImageInfoReply = Caked.Reply.ImageReply.PulledImageInfoReply

public typealias Caked_MountReply = Caked.Reply.MountReply
public typealias Caked_MountVirtioFSReply = Caked.Reply.MountReply.MountVirtioFSReply

public typealias Caked_NetworksReply = Caked.Reply.NetworksReply
public typealias Caked_ListNetworksReply = Caked.Reply.NetworksReply.ListNetworksReply
public typealias Caked_NetworkInfo = Caked.Reply.NetworksReply.NetworkInfo
public typealias Caked_DeleteNetworkReply = Caked.Reply.NetworksReply.DeleteNetworkReply
public typealias Caked_ConfiguredNetworkReply = Caked.Reply.NetworksReply.ConfiguredNetworkReply
public typealias Caked_CreatedNetworkReply = Caked.Reply.NetworksReply.CreatedNetworkReply
public typealias Caked_StartedNetworkReply = Caked.Reply.NetworksReply.StartedNetworkReply
public typealias Caked_StoppedNetworkReply = Caked.Reply.NetworksReply.StoppedNetworkReply
public typealias Caked_NetworkInfoReply = Caked.Reply.NetworksReply.NetworkInfoReply

public typealias Caked_RemoteReply = Caked.Reply.RemoteReply
public typealias Caked_ListRemoteReply = Caked.Reply.RemoteReply.ListRemoteReply
public typealias Caked_RemoteEntry = Caked.Reply.RemoteReply.ListRemoteReply.RemoteEntry

public typealias Caked_RunReply = Caked.Reply.RunReply
public typealias Caked_OCIReply = Caked.Reply.OCIReply
public typealias Caked_LoginReply = Caked.Reply.OCIReply.LoginReply
public typealias Caked_LogoutReply = Caked.Reply.OCIReply.LogoutReply
public typealias Caked_PushReply = Caked.Reply.OCIReply.PushReply
public typealias Caked_PullReply = Caked.Reply.OCIReply.PullReply

public typealias Caked_TemplateReply = Caked.Reply.TemplateReply
public typealias Caked_CreateTemplateReply = Caked.Reply.TemplateReply.CreateTemplateReply
public typealias Caked_DeleteTemplateReply = Caked.Reply.TemplateReply.DeleteTemplateReply
public typealias Caked_ListTemplatesReply = Caked.Reply.TemplateReply.ListTemplatesReply
public typealias Caked_TemplateEntry = Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry

public typealias Caked_VirtualMachineReply = Caked.Reply.VirtualMachineReply
public typealias Caked_DeleteReply = Caked.Reply.VirtualMachineReply.DeleteReply
public typealias Caked_DeletedObject = Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject
public typealias Caked_InfoReply = Caked.Reply.VirtualMachineReply.StatusReply.InfoReply
public typealias Caked_InfoReplyCpuInfo = Caked.CpuInfo
public typealias Caked_InfoReplyCpuCoreInfo = Caked.CpuCoreInfo
public typealias Caked_BuildedReply = Caked.Reply.VirtualMachineReply.BuildedReply
public typealias Caked_ConfiguredReply = Caked.Reply.VirtualMachineReply.ConfiguredReply
public typealias Caked_LaunchReply = Caked.Reply.VirtualMachineReply.LaunchReply
public typealias Caked_StartedReply = Caked.Reply.VirtualMachineReply.StartedReply
public typealias Caked_StopReply = Caked.Reply.VirtualMachineReply.StopReply
public typealias Caked_RestartReply = Caked.Reply.VirtualMachineReply.RestartReply
public typealias Caked_ClonedReply = Caked.Reply.VirtualMachineReply.ClonedReply
public typealias Caked_DuplicatedReply = Caked.Reply.VirtualMachineReply.DuplicatedReply
public typealias Caked_ImportedReply = Caked.Reply.VirtualMachineReply.ImportedReply
public typealias Caked_SuspendReply = Caked.Reply.VirtualMachineReply.SuspendReply
public typealias Caked_WaitIPReply = Caked.Reply.VirtualMachineReply.WaitIPReply
public typealias Caked_PurgeReply = Caked.Reply.VirtualMachineReply.PurgeReply
public typealias Caked_RenameReply = Caked.Reply.VirtualMachineReply.RenameReply
public typealias Caked_StoppedObject = Caked.Reply.VirtualMachineReply.StopReply.StoppedObject
public typealias Caked_SuspendedObject = Caked.Reply.VirtualMachineReply.SuspendReply.SuspendedObject
public typealias Caked_RestartObject = Caked.Reply.VirtualMachineReply.RestartReply.RestartedObject
public typealias Caked_VirtualMachineInfoReply = Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply
public typealias Caked_VirtualMachineInfo = Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo
public typealias Caked_VirtualMachineStatusReply = Caked.Reply.VirtualMachineReply.StatusReply
public typealias Caked_VirtualMachineStatus = Caked.VirtualMachineStatus
public typealias Caked_BuildStreamReply = Caked.Reply.VirtualMachineReply.BuildStreamReply
public typealias Caked_LaunchStreamReply = Caked.Reply.VirtualMachineReply.LaunchStreamReply
public typealias Caked_CurrentStatusReply = Caked.Reply.CurrentStatusReply
public typealias Caked_CurrentStatus = Caked.Reply.CurrentStatusReply.CurrentStatus
public typealias Caked_CurrentUsageReply = Caked.Reply.CurrentUsageReply
public typealias Caked_PingReply = Caked.Reply.PingReply
public typealias Caked_ScreenSizeReply = Caked.Reply.ScreenSizeReply
public typealias Caked_InstalledAgentReply = Caked.Reply.VirtualMachineReply.InstalledAgentReply

public typealias Caked_BuildRequest = Caked.VMRequest.BuildRequest
public typealias Caked_CommonBuildRequest = Caked.VMRequest.CommonBuildRequest
public typealias Caked_ScreenSize = Caked.ScreenSize
public typealias Caked_ConfigureRequest = Caked.VMRequest.ConfigureRequest
public typealias Caked_DeleteRequest = Caked.VMRequest.DeleteRequest
public typealias Caked_DuplicateRequest = Caked.VMRequest.DuplicateRequest
public typealias Caked_ExecuteRequest = Caked.VMRequest.ExecuteRequest
public typealias Caked_ExecuteCommand = Caked.VMRequest.ExecuteRequest.ExecuteCommand
public typealias Caked_Command = Caked.VMRequest.ExecuteRequest.ExecuteCommand.Command
public typealias Caked_TerminalSize = Caked.VMRequest.ExecuteRequest.TerminalSize
public typealias Caked_ExecuteResponse = Caked.VMRequest.ExecuteResponse
public typealias Caked_InfoRequest = Caked.VMRequest.InfoRequest
public typealias Caked_LaunchRequest = Caked.VMRequest.LaunchRequest
public typealias Caked_ListRequest = Caked.VMRequest.ListRequest
public typealias Caked_RenameRequest = Caked.VMRequest.RenameRequest
public typealias Caked_RunCommand = Caked.VMRequest.RunCommand
public typealias Caked_StartRequest = Caked.VMRequest.StartRequest
public typealias Caked_StopRequest = Caked.VMRequest.StopRequest
public typealias Caked_SuspendRequest = Caked.VMRequest.SuspendRequest
public typealias Caked_RestartRequest = Caked.VMRequest.RestartRequest
public typealias Caked_TemplateRequest = Caked.VMRequest.TemplateRequest
public typealias Caked_WaitIPRequest = Caked.VMRequest.WaitIPRequest
public typealias Caked_PingRequest = Caked.PingRequest
public typealias Caked_CurrentStatusRequest = Caked.CurrentStatusRequest
public typealias Caked_GetScreenSizeRequest = Caked.GetScreenSizeRequest
public typealias Caked_SetScreenSizeRequest = Caked.SetScreenSizeRequest
public typealias Caked_InstallAgentRequest = Caked.InstallAgentRequest
public typealias Caked_ImageSource = Caked.Configuration.ImageSource

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

extension ImageSource {
	public init?(_ from: Caked_ImageSource) {
		switch from {
		case .raw:
			self = .raw
		case .cloud:
			self = .qcow2
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

public struct CakedConfiguration: VirtualMachineConfiguration, Codable, Identifiable, Hashable {
	public var id: URL {
		self.locationURL
	}

	public var locationURL: URL
	public var version: Int
	public var os: VirtualizedOS
	public var arch: Architecture
	public var diskSize: UInt64
	public var cpuCountMin: UInt16
	public var suspendable: Bool
	public var cpuCount: UInt16
	public var memorySizeMin: UInt64
	public var memorySize: UInt64
	public var macAddress: String?
	public var source: ImageSource
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
	public var console: String?
	public var forwardedPorts: [TunnelAttachement]
	public var runningIP: String?
	public var display: ViewSize
	public var vncPassword: String?
	public var ecid: Data?
	public var hardwareModel: Data?

	public init(_ from: VirtualMachineConfiguration) {
		// Map fields directly when available on `from`. For fields not present, use safe defaults.
		self.locationURL = from.locationURL
		self.version = from.version
		self.os = from.os
		self.arch = from.arch
		self.diskSize = from.diskSize
		self.cpuCountMin = from.cpuCountMin
		self.suspendable = from.suspendable
		self.cpuCount = from.cpuCount
		self.memorySizeMin = from.memorySizeMin
		self.memorySize = from.memorySize
		self.macAddress = from.macAddress
		self.source = from.source
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
		self.configuredPlatform = from.configuredPlatform
		self.clearPassword = from.clearPassword
		self.ifname = from.ifname
		self.autostart = from.autostart
		self.agent = from.agent
		self.firstLaunch = from.firstLaunch
		self.nested = from.nested
		self.attachedDisks = from.attachedDisks
		self.mounts = from.mounts
		self.networks = from.networks
		self.useCloudInit = from.useCloudInit
		self.sockets = from.sockets
		self.console = from.console
		self.forwardedPorts = from.forwardedPorts
		self.runningIP = from.runningIP
		self.display = from.display
		self.vncPassword = from.vncPassword
		self.ecid = from.ecid
		self.hardwareModel = from.hardwareModel
	}

	public init(_ from: Caked.Configuration) {
		// Map fields directly when available on `from`. For fields not present, use safe defaults.
		self.locationURL = URL(fileURLWithPath: "/dev/null")
		self.version = Int(from.version)
		self.os = .init(from.os)!
		self.arch = .init(from.arch)!
		self.diskSize = from.diskSize
		self.cpuCountMin = UInt16(from.cpuCountMin)
		self.suspendable = from.suspendable
		self.cpuCount = UInt16(from.cpuCount)
		self.memorySizeMin = from.memorySizeMin
		self.memorySize = from.memorySize
		self.macAddress = from.macAddress
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
			self.console = from.console
		}
		self.forwardedPorts = from.forwardedPorts.map({.init($0)})
		self.runningIP = from.runningIp
		if from.hasDisplay {
			let display = from.display
			
			self.display = .init(width: Int(display.width), height: Int(display.height))
		} else {
			self.display = .init(width: 1024, height: 768)
		}

		if from.hasVncPassword {
			self.vncPassword = from.vncPassword
		}
		
		if from.hasEcid {
			self.ecid = from.ecid
		}
		
		if from.hasHardwareModel {
			self.hardwareModel = from.hardwareModel
		}
	}
}

extension Caked.Configuration {
	var configuration: CakedConfiguration {
		CakedConfiguration(self)
	}
}

extension Caked_VirtualMachineStatus: CustomStringConvertible {
	public var description: String {
		switch self {
		case .stopped:
			"stopped"
		case .running:
			"running"
		case .paused:
			"paused"
		case .deleted:
			"deleted"
		case .error:
			"error"
		case .agentReady:
			"agentReady"
		case .UNRECOGNIZED(let value):
			"unrecognized: \(value)"
		case .new:
			"new"
		}
	}
	
	init (agentStatus: CakeAgentLib.Status) {
		switch agentStatus {
		case .running:
			self = .running
		case .stopped:
			self = .stopped
		default:
			self = .UNRECOGNIZED(-1)
		}
	}

	var agentStatus: CakeAgentLib.Status {
		switch self {
			case .running:
				return .running
			case .stopped:
				return .stopped
			default:
				return .unknown
		}
	}
}

extension Caked_CommonBuildRequest {
	public init(buildOptions: BuildOptions) throws {
		let mounts = buildOptions.mounts.map { $0.description }
		let networks = buildOptions.networks.map { $0.description }
		let sockets = buildOptions.sockets.map { $0.description }

		self.init()
		self.name = buildOptions.name
		self.cpu = UInt32(buildOptions.cpu)
		self.memory = buildOptions.memory
		self.diskSize = buildOptions.diskSize
		self.user = buildOptions.user
		self.mainGroup = buildOptions.mainGroup
		self.otherGroups = buildOptions.otherGroup.joined(separator: ",")
		self.sshPwAuth = buildOptions.clearPassword
		self.autostart = buildOptions.autostart
		self.autoinstall = buildOptions.autoinstall
		self.nested = buildOptions.nested
		self.image = buildOptions.image
		self.ifnames = buildOptions.netIfnames
		self.suspendable = buildOptions.suspendable
		self.screenSize = Caked_ScreenSize.with {
			$0.width = Int32(buildOptions.screenSize.width)
			$0.height = Int32(buildOptions.screenSize.height)
		}

		if mounts.isEmpty == false {
			self.mounts = mounts.joined(separator: String.grpcSeparator)
		}

		if networks.isEmpty == false {
			self.networks = networks.joined(separator: String.grpcSeparator)
		}

		if sockets.isEmpty == false {
			self.sockets = sockets.joined(separator: String.grpcSeparator)
		}

		if let console = buildOptions.consoleURL {
			self.console = console.description
		}

		if buildOptions.forwardedPorts.isEmpty == false {
			self.forwardedPort = buildOptions.forwardedPorts.map { forwardedPort in
				return forwardedPort.description
			}.joined(separator: String.grpcSeparator)
		}

		if let sshAuthorizedKey = buildOptions.sshAuthorizedKey {
			self.sshAuthorizedKey = try Data(contentsOf: URL(filePath: sshAuthorizedKey))
		}

		if let vendorData = buildOptions.vendorData {
			self.vendorData = try Data(contentsOf: URL(filePath: vendorData))
		}

		if let userData = buildOptions.userData {
			if userData == "-" {
				if let input = (readLine(strippingNewline: true))?.split(whereSeparator: { $0 == " " }).map(String.init) {
					self.userData = input.joined(separator: "\n").data(using: .utf8)!
				}
			} else {
				self.userData = try Data(contentsOf: URL(filePath: userData))
			}
		}

		if let networkConfig = buildOptions.networkConfig {
			self.networkConfig = try Data(contentsOf: URL(filePath: networkConfig))
		}

		self.dynamicPortForwarding = buildOptions.dynamicPortForwarding

		if let imageSource = buildOptions.imageSource {
			self.imageSource = .init(imageSource)
		}
	}
}

extension Caked_BuildRequest {
	public init(buildOptions: BuildOptions) throws {
		self.init()
		self.options = try Caked_CommonBuildRequest(buildOptions: buildOptions)
	}
}

extension Caked_ConfigureRequest {
	public init(options: ConfigureOptions) {
		self.init()
		self.name = options.name

		if let user = options.user {
			self.user = user
		}

		if let password = options.password {
			self.password = password
		}

		if let cpu = options.cpu {
			self.cpu = UInt32(cpu)
		}

		if let memory = options.memory {
			self.memory = memory
		}

		if let diskSize = options.diskSize {
			self.diskSize = diskSize
		}

		if let displayRefit = options.displayRefit {
			self.displayRefit = displayRefit
		}

		if let autostart = options.autostart {
			self.autostart = autostart
		}

		if let nested = options.nested {
			self.nested = nested
		}

		if let mounts = options.mounts {
			self.mounts = mounts.map { $0.description }.joined(separator: String.grpcSeparator)
		}

		if let networks = options.networks {
			self.networks = networks.map { $0.description }.joined(separator: String.grpcSeparator)
		}

		if let sockets = options.sockets {
			self.networks = sockets.map { $0.description }.joined(separator: String.grpcSeparator)
		}

		if let consoleURL = options.consoleURL {
			self.console = consoleURL.description
		}

		if let forwardedPort = options.forwardedPort {
			self.forwardedPort = forwardedPort.map { $0.description }.joined(separator: String.grpcSeparator)
		}

		if let dynamicPortForwarding = options.dynamicPortForwarding {
			self.dynamicPortForwarding = dynamicPortForwarding
		}

		if let screenSize = options.screenSize {
			self.screenSize = Caked_ScreenSize.with {
				$0.width = Int32(screenSize.width)
				$0.height = Int32(screenSize.height)
			}
		}

		self.randomMac = options.randomMAC
	}
}
