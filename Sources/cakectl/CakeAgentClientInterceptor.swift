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

extension termios: @retroactive @unchecked Sendable {
}
class CakeAgentClientInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
	let state: termios?
	let inputHandle: FileHandle?

	init(state: termios?, inputHandle: FileHandle?) {
		self.state = state
		self.inputHandle = FileHandle.standardInput
		super.init()
	}

	func restoreState() {
		guard var state = self.state else {
			return
		}

		if let inputHandle = self.inputHandle {
			inputHandle.restoreState(&state)
		}
	}

	override func receive(_ part: GRPCClientResponsePart<Response>, context: ClientInterceptorContext<Request, Response>) {
		super.receive(part, context: context)
	}

	override func errorCaught(_ error: Error, context: ClientInterceptorContext<Request, Response>) {
		self.restoreState()

		FileHandle.standardError.write(Data("errorCaught: \(error)\n".utf8))
		super.errorCaught(error, context: context)
		Foundation.exit(1)
	}

	override func send(_ part: GRPCClientRequestPart<Request>, promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Request, Response>) {
		super.send(part, promise: promise, context: context)
	}

	override func cancel(promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Request, Response>) {
		self.restoreState()

		FileHandle.standardError.write(Data("canceled\n".utf8))
		super.cancel(promise: promise, context: context)
		Foundation.exit(1)
	}
}
final class CakeAgentClientInterceptorFactory: Caked_ServiceClientInterceptorFactoryProtocol {
	internal static var inputHandle: FileHandle? = nil
	internal static var state: termios? = nil

	public static func captureState(inputHandle: FileHandle, state: termios?) {
		CakeAgentClientInterceptorFactory.state = state
		CakeAgentClientInterceptorFactory.inputHandle = inputHandle
	}

	public static func clearState() {
		CakeAgentClientInterceptorFactory.state = nil
		CakeAgentClientInterceptorFactory.inputHandle = nil
	}

	func makeBuildInterceptors() -> [ClientInterceptor<Caked_BuildRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_BuildRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeStartInterceptors() -> [ClientInterceptor<Caked_StartRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_StartRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeCakeCommandInterceptors() -> [ClientInterceptor<Caked_CakedCommandRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_CakedCommandRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeLaunchInterceptors() -> [ClientInterceptor<Caked_LaunchRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_LaunchRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeLoginInterceptors() -> [ClientInterceptor<Caked_LoginRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_LoginRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeLogoutInterceptors() -> [ClientInterceptor<Caked_LogoutRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_LogoutRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makePurgeInterceptors() -> [ClientInterceptor<Caked_PurgeRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_PurgeRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeConfigureInterceptors() -> [ClientInterceptor<Caked_ConfigureRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_ConfigureRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeWaitIPInterceptors() -> [ClientInterceptor<Caked_WaitIPRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_WaitIPRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeStopInterceptors() -> [ClientInterceptor<Caked_StopRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_StopRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeListInterceptors() -> [ClientInterceptor<Caked_ListRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_ListRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeDeleteInterceptors() -> [ClientInterceptor<Caked_DeleteRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_DeleteRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeImageInterceptors() -> [ClientInterceptor<Caked_ImageRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_ImageRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeRemoteInterceptors() -> [ClientInterceptor<Caked_RemoteRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_RemoteRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeNetworksInterceptors() -> [ClientInterceptor<Caked_NetworkRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_NetworkRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeTemplateInterceptors() -> [ClientInterceptor<Caked_TemplateRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_TemplateRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeRenameInterceptors() -> [ClientInterceptor<Caked_RenameRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_RenameRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeInfoInterceptors() -> [ClientInterceptor<Caked_InfoRequest, Caked_InfoReply>] {
		[CakeAgentClientInterceptor<Caked_InfoRequest, Caked_InfoReply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeRunInterceptors() -> [ClientInterceptor<Caked_RunCommand, Caked_RunReply>] {
		[CakeAgentClientInterceptor<Caked_RunCommand, Caked_RunReply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeExecuteInterceptors() -> [ClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>] {
		[CakeAgentClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeMountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_MountRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}

	func makeUmountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_MountRequest, Caked_Reply>(state: Self.state, inputHandle: Self.inputHandle)]
	}
}
