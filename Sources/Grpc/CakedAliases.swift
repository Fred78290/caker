import Foundation
import GRPC
import CakeAgentLib

public typealias Caked = Caked_Caked

public typealias Caked_CakedCommandRequest = Caked.CakedCommandRequest
public typealias Caked_ImageRequest = Caked.ImageRequest
public typealias Caked_ImageCommand = Caked.ImageRequest.ImageCommand

public typealias Caked_LoginRequest = Caked.LoginRequest
public typealias Caked_LogoutRequest = Caked.LogoutRequest

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
public typealias Caked_ListImagesInfo = Caked.Reply.ImageReply.ImageInfo
public typealias Caked_ListImagesInfoReply = Caked.Reply.ImageReply.ListImagesInfoReply
public typealias Caked_PulledImageInfo = Caked.Reply.ImageReply.PulledImageInfo

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
public typealias Caked_TartReply = Caked.Reply.TartReply

public typealias Caked_TemplateReply = Caked.Reply.TemplateReply
public typealias Caked_CreateTemplateReply = Caked.Reply.TemplateReply.CreateTemplateReply
public typealias Caked_DeleteTemplateReply = Caked.Reply.TemplateReply.DeleteTemplateReply
public typealias Caked_ListTemplatesReply = Caked.Reply.TemplateReply.ListTemplatesReply
public typealias Caked_TemplateEntry = Caked.Reply.TemplateReply.ListTemplatesReply.TemplateEntry

public typealias Caked_VirtualMachineReply = Caked.Reply.VirtualMachineReply
public typealias Caked_DeleteReply = Caked.Reply.VirtualMachineReply.DeleteReply
public typealias Caked_DeletedObject = Caked.Reply.VirtualMachineReply.DeleteReply.DeletedObject
public typealias Caked_InfoReply = Caked.Reply.VirtualMachineReply.InfoReply
public typealias Caked_BuildedReply = Caked.Reply.VirtualMachineReply.BuildedReply
public typealias Caked_ConfiguredReply = Caked.Reply.VirtualMachineReply.ConfiguredReply
public typealias Caked_LaunchReply = Caked.Reply.VirtualMachineReply.LaunchReply
public typealias Caked_StartedReply = Caked.Reply.VirtualMachineReply.StartedReply
public typealias Caked_StopReply = Caked.Reply.VirtualMachineReply.StopReply
public typealias Caked_ClonedReply = Caked.Reply.VirtualMachineReply.ClonedReply
public typealias Caked_DuplicatedReply = Caked.Reply.VirtualMachineReply.DuplicatedReply
public typealias Caked_ImportedReply = Caked.Reply.VirtualMachineReply.ImportedReply
public typealias Caked_SuspendReply = Caked.Reply.VirtualMachineReply.SuspendReply
public typealias Caked_WaitIPReply = Caked.Reply.VirtualMachineReply.WaitIPReply
public typealias Caked_PurgeReply = Caked.Reply.VirtualMachineReply.PurgeReply
public typealias Caked_RenameReply = Caked.Reply.VirtualMachineReply.RenameReply
public typealias Caked_StoppedObject = Caked.Reply.VirtualMachineReply.StopReply.StoppedObject
public typealias Caked_SuspendedObject = Caked.Reply.VirtualMachineReply.SuspendReply.SuspendedObject
public typealias Caked_VirtualMachineInfoReply = Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply
public typealias Caked_VirtualMachineInfo = Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo

public typealias Caked_BuildRequest = Caked.VMRequest.BuildRequest
public typealias Caked_CloneRequest = Caked.VMRequest.CloneRequest
public typealias Caked_CommonBuildRequest = Caked.VMRequest.CommonBuildRequest
public typealias Caked_ScreenSize = Caked.VMRequest.CommonBuildRequest.ScreenSize
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
public typealias Caked_TemplateRequest = Caked.VMRequest.TemplateRequest
public typealias Caked_WaitIPRequest = Caked.VMRequest.WaitIPRequest

public struct VMInformations: Sendable, Codable {
	public var name: String
	public var version: String?
	public var uptime: UInt64?
	public var memory: InfoReply.MemoryInfo?
	public var cpuCount: Int32
	public var diskInfos: [DiskInfo]
	public var ipaddresses: [String]
	public var osname: String
	public var hostname: String?
	public var release: String?
	public var mounts: [String]?
	public var status: Status
	public var attachedNetworks: [AttachedNetwork]?
	public var tunnelInfos: [TunnelInfo]?
	public var socketInfos: [SocketInfo]?
	public var vncURL: String?
	
	public static func with(
		_ populator: (inout Self) throws -> Void
	) rethrows -> Self {
		var message = Self()
		try populator(&message)
		return message
	}
	
	public init() {
		self.name = ""
		self.version = nil
		self.uptime = 0
		self.memory = nil
		self.cpuCount = 0
		self.diskInfos = []
		self.ipaddresses = []
		self.osname = ""
		self.hostname = nil
		self.release = nil
		self.status = .stopped
		self.mounts = nil
		self.attachedNetworks = nil
		self.tunnelInfos = nil
		self.socketInfos = nil
	}
	
	public init(from: InfoReply) {
		self.name = from.name
		self.version = from.version
		self.uptime = from.uptime
		self.memory = from.memory
		self.cpuCount = from.cpuCount
		self.diskInfos = from.diskInfos
		self.ipaddresses = from.ipaddresses
		self.osname = from.osname
		self.hostname = from.hostname
		self.release = from.release
		self.mounts = from.mounts
		self.status = .running
		self.attachedNetworks = nil
		self.tunnelInfos = nil
		self.socketInfos = nil
	}
	
	public func toCaked_InfoReply() -> Caked_InfoReply {
		Caked_InfoReply.with { reply in
			reply.success = true
			reply.reason = "Success"
			reply.name = self.name
			reply.diskInfos = self.diskInfos.map { diskInfos in
				Caked_InfoReply.DiskInfo.with {
					$0.device = diskInfos.device
					$0.mount = diskInfos.mount
					$0.fsType = diskInfos.fsType
					$0.size = diskInfos.total
					$0.free = diskInfos.free
					$0.used = diskInfos.used
				}
			}

			if let version = self.version {
				reply.version = version
			}

			if let uptime = self.uptime {
				reply.uptime = uptime
			}

			if let memory = self.memory {
				reply.memory = Caked_InfoReply.MemoryInfo.with {
					if let total = memory.total {
						$0.total = total
					}

					if let free = memory.free {
						$0.free = free
					}

					if let used = memory.used {
						$0.used = used
					}
				}
			}

			reply.cpuCount = self.cpuCount
			reply.ipaddresses = self.ipaddresses
			reply.osname = self.osname

			if let release = self.release {
				reply.release = release
			}

			if let hostname = self.hostname {
				reply.hostname = hostname
			}

			if let mounts = self.mounts {
				reply.mounts = mounts
			}

			reply.status = self.status.rawValue

			if let attachedNetworks = self.attachedNetworks {
				reply.networks = attachedNetworks.map { Caked_InfoReply.AttachedNetwork(from: $0) }
			}

			if let tunnelInfos = self.tunnelInfos {
				reply.tunnels = tunnelInfos.compactMap { Caked_InfoReply.TunnelInfo(from: $0) }
			}

			if let sockets = self.socketInfos {
				reply.sockets = sockets.map { Caked_InfoReply.SocketInfo(from: $0) }
			}

			if let vncURL = self.vncURL {
				reply.vncURL = vncURL
			}
		}
	}
}
