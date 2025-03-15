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

final class CakeAgentClientInterceptorFactory: Caked_ServiceClientInterceptorFactoryProtocol {
	internal let inputHandle: FileHandle
	internal let state: termios

	class CakeAgentClientInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
		let state: termios
		let inputHandle: FileHandle

		init(state: termios, inputHandle: FileHandle) {
			self.state = state
			self.inputHandle = FileHandle.standardInput
			super.init()
		}

		func restoreState() {
			var state = self.state

			inputHandle.restoreState(&state)
		}

		func printError(_ error: Error) {
			let description: String

			if let err: GRPCStatus = error as? GRPCStatus {
				if err.code == .unavailable || err.code == .cancelled{
					description = "closed connection"
				} else {
					description = err.description
				}
			} else {
				description = error.localizedDescription
			}

			FileHandle.standardError.write(Data("\(description)\n".utf8))
		}

		override func errorCaught(_ error: Error, context: ClientInterceptorContext<Request, Response>) {
			self.restoreState()

			printError(error)
			super.errorCaught(error, context: context)
			Foundation.exit(1)
		}

		override func cancel(promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Request, Response>) {
			self.restoreState()

			FileHandle.standardError.write(Data("canceled\n".utf8))
			super.cancel(promise: promise, context: context)
			Foundation.exit(1)
		}
	}

	internal init(inputHandle: FileHandle, state: termios) {
		self.inputHandle = inputHandle
		self.state = state
	}

	public init?(inputHandle: FileHandle) {
		guard inputHandle.isTTY() else {
			return nil
		}

		self.inputHandle = inputHandle
		self.state = inputHandle.getState()
	}

	public func restoreState() {
		var state = self.state

		inputHandle.restoreState(&state)
	}

	func makeBuildInterceptors() -> [ClientInterceptor<Caked_BuildRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_BuildRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeStartInterceptors() -> [ClientInterceptor<Caked_StartRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_StartRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeCakeCommandInterceptors() -> [ClientInterceptor<Caked_CakedCommandRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_CakedCommandRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeLaunchInterceptors() -> [ClientInterceptor<Caked_LaunchRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_LaunchRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeLoginInterceptors() -> [ClientInterceptor<Caked_LoginRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_LoginRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeLogoutInterceptors() -> [ClientInterceptor<Caked_LogoutRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_LogoutRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makePurgeInterceptors() -> [ClientInterceptor<Caked_PurgeRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_PurgeRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeConfigureInterceptors() -> [ClientInterceptor<Caked_ConfigureRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_ConfigureRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeWaitIPInterceptors() -> [ClientInterceptor<Caked_WaitIPRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_WaitIPRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeStopInterceptors() -> [ClientInterceptor<Caked_StopRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_StopRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeListInterceptors() -> [ClientInterceptor<Caked_ListRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_ListRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeDeleteInterceptors() -> [ClientInterceptor<Caked_DeleteRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_DeleteRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeImageInterceptors() -> [ClientInterceptor<Caked_ImageRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_ImageRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeRemoteInterceptors() -> [ClientInterceptor<Caked_RemoteRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_RemoteRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeNetworksInterceptors() -> [ClientInterceptor<Caked_NetworkRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_NetworkRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeTemplateInterceptors() -> [ClientInterceptor<Caked_TemplateRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_TemplateRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeRenameInterceptors() -> [ClientInterceptor<Caked_RenameRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_RenameRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeInfoInterceptors() -> [ClientInterceptor<Caked_InfoRequest, Caked_InfoReply>] {
		[CakeAgentClientInterceptor<Caked_InfoRequest, Caked_InfoReply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeRunInterceptors() -> [ClientInterceptor<Caked_RunCommand, Caked_RunReply>] {
		[CakeAgentClientInterceptor<Caked_RunCommand, Caked_RunReply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeExecuteInterceptors() -> [ClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>] {
		[CakeAgentClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeMountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_MountRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}

	func makeUmountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		[CakeAgentClientInterceptor<Caked_MountRequest, Caked_Reply>(state: self.state, inputHandle: self.inputHandle)]
	}
}
