//
//  CakeAgentClientInterceptor.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/03/2025.
//
import Foundation
import GRPCLib
import GRPC
import NIO

class CakeAgentClientInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
	override func receive(_ part: GRPCClientResponsePart<Response>, context: ClientInterceptorContext<Request, Response>) {
		super.receive(part, context: context)
	}

	override func errorCaught(_ error: Error, context: ClientInterceptorContext<Request, Response>) {
		FileHandle.standardError.write(Data("errorCaught: \(error)\n".utf8))
		super.errorCaught(error, context: context)
		Foundation.exit(1)
	}

	override func send(_ part: GRPCClientRequestPart<Request>, promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Request, Response>) {
		super.send(part, promise: promise, context: context)
	}

	override func cancel(promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Request, Response>) {
		FileHandle.standardError.write(Data("canceled\n".utf8))
		super.cancel(promise: promise, context: context)
		Foundation.exit(1)
	}
}
struct CakeAgentClientInterceptorFactory: Caked_ServiceClientInterceptorFactoryProtocol {
	func makeBuildInterceptors() -> [ClientInterceptor<Caked_BuildRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_BuildRequest, Caked_Reply>()]
	}

	func makeStartInterceptors() -> [ClientInterceptor<Caked_StartRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_StartRequest, Caked_Reply>()]
	}

	func makeCakeCommandInterceptors() -> [ClientInterceptor<Caked_CakedCommandRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_CakedCommandRequest, Caked_Reply>()]
	}

	func makeLaunchInterceptors() -> [ClientInterceptor<Caked_LaunchRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_LaunchRequest, Caked_Reply>()]
	}

	func makeLoginInterceptors() -> [ClientInterceptor<Caked_LoginRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_LoginRequest, Caked_Reply>()]
	}

	func makeLogoutInterceptors() -> [ClientInterceptor<Caked_LogoutRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_LogoutRequest, Caked_Reply>()]
	}

	func makePurgeInterceptors() -> [ClientInterceptor<Caked_PurgeRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_PurgeRequest, Caked_Reply>()]
	}

	func makeConfigureInterceptors() -> [ClientInterceptor<Caked_ConfigureRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_ConfigureRequest, Caked_Reply>()]
	}

	func makeWaitIPInterceptors() -> [ClientInterceptor<Caked_WaitIPRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_WaitIPRequest, Caked_Reply>()]
	}

	func makeStopInterceptors() -> [ClientInterceptor<Caked_StopRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_StopRequest, Caked_Reply>()]
	}

	func makeListInterceptors() -> [ClientInterceptor<Caked_ListRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_ListRequest, Caked_Reply>()]
	}

	func makeDeleteInterceptors() -> [ClientInterceptor<Caked_DeleteRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_DeleteRequest, Caked_Reply>()]
	}

	func makeImageInterceptors() -> [ClientInterceptor<Caked_ImageRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_ImageRequest, Caked_Reply>()]
	}

	func makeRemoteInterceptors() -> [ClientInterceptor<Caked_RemoteRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_RemoteRequest, Caked_Reply>()]
	}

	func makeNetworksInterceptors() -> [ClientInterceptor<Caked_NetworkRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_NetworkRequest, Caked_Reply>()]
	}

	func makeTemplateInterceptors() -> [ClientInterceptor<Caked_TemplateRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_TemplateRequest, Caked_Reply>()]
	}

	func makeRenameInterceptors() -> [ClientInterceptor<Caked_RenameRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_RenameRequest, Caked_Reply>()]
	}

	func makeInfoInterceptors() -> [ClientInterceptor<Caked_InfoRequest, Caked_InfoReply>] {
		[CakeAgentClientInterceptor<Caked_InfoRequest, Caked_InfoReply>()]
	}

	func makeRunInterceptors() -> [ClientInterceptor<Caked_RunCommand, Caked_RunReply>] {
		[CakeAgentClientInterceptor<Caked_RunCommand, Caked_RunReply>()]
	}

	func makeExecuteInterceptors() -> [ClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>] {
		[CakeAgentClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>()]
	}

	func makeMountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_MountRequest, Caked_Reply>()]
	}

	func makeUmountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_MountRequest, Caked_Reply>()]
	}
}
