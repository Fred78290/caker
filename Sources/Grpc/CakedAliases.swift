import Foundation
import GRPC

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
public typealias Caked_Error = Caked.Reply.Error

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
public typealias Caked_StopReply = Caked.Reply.VirtualMachineReply.StopReply
public typealias Caked_StoppedObject = Caked.Reply.VirtualMachineReply.StopReply.StoppedObject
public typealias Caked_VirtualMachineInfoReply = Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply
public typealias Caked_VirtualMachineInfo = Caked.Reply.VirtualMachineReply.VirtualMachineInfoReply.VirtualMachineInfo

public typealias Caked_BuildRequest = Caked.VMRequest.BuildRequest
public typealias Caked_CloneRequest = Caked.VMRequest.CloneRequest
public typealias Caked_CommonBuildRequest = Caked.VMRequest.CommonBuildRequest
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
public typealias Caked_TemplateRequest = Caked.VMRequest.TemplateRequest
public typealias Caked_WaitIPRequest = Caked.VMRequest.WaitIPRequest
