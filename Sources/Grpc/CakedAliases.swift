import Foundation
import GRPC

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
public typealias Caked_InfoReplyCpuInfo = Caked.Reply.VirtualMachineReply.StatusReply.InfoReply.CpuInfo
public typealias Caked_InfoReplyCpuCoreInfo = Caked.Reply.VirtualMachineReply.StatusReply.InfoReply.CpuCoreInfo
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
public typealias Caked_VirtualMachineStatusReply = Caked.Reply.VirtualMachineReply.StatusReply

public typealias Caked_BuildRequest = Caked.VMRequest.BuildRequest
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
