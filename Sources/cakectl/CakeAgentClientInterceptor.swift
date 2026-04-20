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
					description = String(localized: "Connection refused")
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
	
	func interceptors<Request, Response>() -> [ClientInterceptor<Request, Response>] {
		[CakeServiceClientInterceptor<Request, Response>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeBuildInterceptors() -> [ClientInterceptor<Caked_BuildRequest, Caked_BuildStreamReply>] {
		self.interceptors()
	}
	
	func makeStartInterceptors() -> [ClientInterceptor<Caked_StartRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeDuplicateInterceptors() -> [ClientInterceptor<Caked_DuplicateRequest, Caked_Reply>] {
		self.interceptors()
	}

	func makeLaunchInterceptors() -> [ClientInterceptor<Caked_LaunchRequest, Caked_LaunchStreamReply>] {
		self.interceptors()
	}
	
	func makeLoginInterceptors() -> [ClientInterceptor<Caked_LoginRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeLogoutInterceptors() -> [ClientInterceptor<Caked_LogoutRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeCloneInterceptors() -> [ClientInterceptor<Caked_CloneRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makePushInterceptors() -> [ClientInterceptor<Caked_PushRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makePurgeInterceptors() -> [ClientInterceptor<Caked_PurgeRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeConfigureInterceptors() -> [ClientInterceptor<Caked_ConfigureRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeWaitIPInterceptors() -> [ClientInterceptor<Caked_WaitIPRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeSuspendInterceptors() -> [ClientInterceptor<Caked_SuspendRequest, Caked_Caked.Reply>] {
		self.interceptors()
	}
	
	func makeRestartInterceptors() -> [ClientInterceptor<Caked_RestartRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeStopInterceptors() -> [ClientInterceptor<Caked_StopRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeListInterceptors() -> [ClientInterceptor<Caked_ListRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeDeleteInterceptors() -> [ClientInterceptor<Caked_DeleteRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeImageInterceptors() -> [ClientInterceptor<Caked_ImageRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeRemoteInterceptors() -> [ClientInterceptor<Caked_RemoteRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeNetworksInterceptors() -> [ClientInterceptor<Caked_NetworkRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeTemplateInterceptors() -> [ClientInterceptor<Caked_TemplateRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeRenameInterceptors() -> [ClientInterceptor<Caked_RenameRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeInfoInterceptors() -> [ClientInterceptor<Caked_InfoRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeRunInterceptors() -> [ClientInterceptor<Caked_RunCommand, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeExecuteInterceptors() -> [ClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>] {
		self.interceptors()
	}
	
	func makeMountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeUmountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makePingInterceptors() -> [ClientInterceptor<Caked_PingRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeCurrentStatusInterceptors() -> [ClientInterceptor<Caked_CurrentStatusRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeVncInfosInterceptors() -> [ClientInterceptor<Caked_InfoRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeGetScreenSizeInterceptors() -> [ClientInterceptor<Caked_GetScreenSizeRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeSetScreenSizeInterceptors() -> [ClientInterceptor<Caked_SetScreenSizeRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeInstallAgentInterceptors() -> [ClientInterceptor<Caked_InstallAgentRequest, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeGrandCentralDispatcherInterceptors() -> [ClientInterceptor<Caked_Empty, Caked_Reply>] {
		self.interceptors()
	}
	
	func makeGrandCentralUpdateInterceptors() -> [ClientInterceptor<Caked_CurrentStatus, Caked_Empty>] {
		self.interceptors()
	}
}
