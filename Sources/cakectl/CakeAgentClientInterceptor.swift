//
//  CakeAgentClientInterceptor.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/03/2025.
//
import Foundation
import GRPC
import GRPCLib
import NIO

final class CakeServiceClientInterceptorFactory: Caked_ServiceClientInterceptorFactoryProtocol {
	internal let inputHandle: FileHandle
	internal let state: termios
	
	class CakeServiceClientInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
		let state: termios
		let inputHandle: FileHandle
		
		init(state: termios, inputHandle: FileHandle) {
			self.state = state
			self.inputHandle = inputHandle
			super.init()
		}
		
		func restoreState() throws {
			var state = self.state
			
			try inputHandle.restoreState(&state)
		}
		
		func printError(_ error: Error) {
			var error = error
			let description: String
			
			if let status: any GRPCStatusTransformable = error as? GRPCStatusTransformable {
				error = status.makeGRPCStatus()
			}
			
			if let err: GRPCStatus = error as? GRPCStatus {
				if err.code == .unavailable || err.code == .cancelled {
					description = "Connection refused"
				} else {
					description = err.description
				}
			} else {
				description = error.localizedDescription
			}
			
			FileHandle.standardError.write(Data("\(description)\n".utf8))
		}
		
		override func errorCaught(_ error: Error, context: ClientInterceptorContext<Request, Response>) {
			try? self.restoreState()
			
			printError(error)
			super.errorCaught(error, context: context)
			Foundation.exit(1)
		}
		
		override func cancel(promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Request, Response>) {
			try? self.restoreState()
			
			FileHandle.standardError.write(Data("canceled\n".utf8))
			super.cancel(promise: promise, context: context)
			Foundation.exit(1)
		}
	}
	
	internal init(inputHandle: FileHandle, state: termios) {
		self.inputHandle = inputHandle
		self.state = state
	}
	
	public init?(inputHandle: FileHandle) throws {
		guard inputHandle.isTTY() else {
			return nil
		}
		
		self.inputHandle = inputHandle
		self.state = try inputHandle.getState()
	}
	
	public func restoreState() throws {
		var state = self.state
		
		try inputHandle.restoreState(&state)
	}
	
	func makeBuildInterceptors() -> [ClientInterceptor<Caked_BuildRequest, Caked_BuildStreamReply>] {
		[CakeServiceClientInterceptor<Caked_BuildRequest, Caked_BuildStreamReply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeStartInterceptors() -> [ClientInterceptor<Caked_StartRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_StartRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeDuplicateInterceptors() -> [ClientInterceptor<Caked_DuplicateRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_DuplicateRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeLaunchInterceptors() -> [ClientInterceptor<Caked_LaunchRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_LaunchRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeLoginInterceptors() -> [ClientInterceptor<Caked_LoginRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_LoginRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeLogoutInterceptors() -> [ClientInterceptor<Caked_LogoutRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_LogoutRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeCloneInterceptors() -> [ClientInterceptor<Caked_CloneRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_CloneRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makePushInterceptors() -> [ClientInterceptor<Caked_PushRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_PushRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makePurgeInterceptors() -> [ClientInterceptor<Caked_PurgeRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_PurgeRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeConfigureInterceptors() -> [ClientInterceptor<Caked_ConfigureRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_ConfigureRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeWaitIPInterceptors() -> [ClientInterceptor<Caked_WaitIPRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_WaitIPRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeSuspendInterceptors() -> [ClientInterceptor<Caked_SuspendRequest, Caked_Caked.Reply>] {
		[CakeServiceClientInterceptor<Caked_SuspendRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeRestartInterceptors() -> [ClientInterceptor<Caked_RestartRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_RestartRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeStopInterceptors() -> [ClientInterceptor<Caked_StopRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_StopRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeListInterceptors() -> [ClientInterceptor<Caked_ListRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_ListRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeDeleteInterceptors() -> [ClientInterceptor<Caked_DeleteRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_DeleteRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeImageInterceptors() -> [ClientInterceptor<Caked_ImageRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_ImageRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeRemoteInterceptors() -> [ClientInterceptor<Caked_RemoteRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_RemoteRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeNetworksInterceptors() -> [ClientInterceptor<Caked_NetworkRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_NetworkRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeTemplateInterceptors() -> [ClientInterceptor<Caked_TemplateRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_TemplateRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeRenameInterceptors() -> [ClientInterceptor<Caked_RenameRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_RenameRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeInfoInterceptors() -> [ClientInterceptor<Caked_InfoRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_InfoRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeRunInterceptors() -> [ClientInterceptor<Caked_RunCommand, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_RunCommand, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeExecuteInterceptors() -> [ClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>] {
		[CakeServiceClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeMountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_MountRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeUmountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_MountRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makePingInterceptors() -> [ClientInterceptor<Caked_PingRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_PingRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeCurrentStatusInterceptors() -> [ClientInterceptor<Caked_CurrentStatusRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_CurrentStatusRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeVncURLInterceptors() -> [ClientInterceptor<Caked_InfoRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_InfoRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeGetScreenSizeInterceptors() -> [ClientInterceptor<Caked_GetScreenSizeRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_Caked.GetScreenSizeRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
	
	func makeSetScreenSizeInterceptors() -> [ClientInterceptor<Caked_SetScreenSizeRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_Caked.SetScreenSizeRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeInstallAgentInterceptors() -> [ClientInterceptor<Caked_InstallAgentRequest, Caked_Reply>] {
		[CakeServiceClientInterceptor<Caked_InstallAgentRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
}
