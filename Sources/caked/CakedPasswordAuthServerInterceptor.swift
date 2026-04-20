//
//  CakedPasswordAuthServerInterceptor.swift
//  Caker
//
//  Created by Frederic BOLTZ on 19/04/2026.
//
import GRPC
import GRPCLib
import NIO
import NIOHPACK
import SwiftProtobuf

extension UserInfo {
	enum AuthorizationKey: UserInfo.Key {
		typealias Value = Bool
	}

	var authorization: AuthorizationKey.Value? {
		get {
			return self[AuthorizationKey.self]
		}
		set {
			self[AuthorizationKey.self] = newValue
		}
	}
}

struct CakedPasswordAuthServerInterceptor: Caked_ServiceServerInterceptorFactoryProtocol {
	let expectedPassword: String?

	class PasswordAuthServerInterceptor<Request: Message, Response: Message>: ServerInterceptor<Request, Response>, @unchecked Sendable {
		let expectedPassword: String?

		init(expectedPassword: String?) {
			self.expectedPassword = expectedPassword
		}

		override func receive(_ part: GRPCServerRequestPart<Request>, context: ServerInterceptorContext<Request, Response>) {
			switch part {
			case .metadata(let headers):
				if self.expectedPassword == nil || context.remoteAddress?.protocol == .unix {
					context.receive(part)
				} else {
					// Expect an Authorization header in the form: Bearer <password> or just the raw password
					let authValues = headers["authorization"]
					let isAuthorized: Bool = {
						guard let value = authValues.first else {
							return false
						}

						if value.lowercased().hasPrefix("bearer ") {
							let token = String(value.dropFirst("bearer ".count)).base64DecodedString()
							return token == expectedPassword
						}

						return false
					}()

					context.userInfo.authorization = isAuthorized

					if isAuthorized {
						context.receive(part)
					} else {
						// Not auth'd. Fail the RPC.
						context.send(.end(GRPCStatus(code: .unauthenticated, message: String(localized: "Unauthorized access")), HPACKHeaders([("www-authenticate", "Magic")])), promise: nil)
					}
				}
			case .message, .end:
				context.receive(part)
			}
		}
	}

	func interceptors<Request, Response>() -> [PasswordAuthServerInterceptor<Request, Response>] {
		return [PasswordAuthServerInterceptor(expectedPassword: expectedPassword)]
	}

	func makeBuildInterceptors() -> [ServerInterceptor<Caked_BuildRequest, Caked_BuildStreamReply>] {
		return self.interceptors()
	}

	func makeConfigureInterceptors() -> [ServerInterceptor<Caked_ConfigureRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeDeleteInterceptors() -> [ServerInterceptor<Caked_DeleteRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeDuplicateInterceptors() -> [ServerInterceptor<Caked_DuplicateRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeExecuteInterceptors() -> [ServerInterceptor<Caked_ExecuteRequest, Caked_Caked.VMRequest.ExecuteResponse>] {
		return self.interceptors()
	}

	func makeInfoInterceptors() -> [ServerInterceptor<Caked_InfoRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeVncInfosInterceptors() -> [ServerInterceptor<Caked_InfoRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeLaunchInterceptors() -> [ServerInterceptor<Caked_LaunchRequest, Caked_Reply.VirtualMachineReply.LaunchStreamReply>] {
		return self.interceptors()
	}

	func makeListInterceptors() -> [ServerInterceptor<Caked_ListRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeRenameInterceptors() -> [ServerInterceptor<Caked_RenameRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeRunInterceptors() -> [ServerInterceptor<Caked_RunCommand, Caked_Reply>] {
		return self.interceptors()
	}

	func makeStartInterceptors() -> [ServerInterceptor<Caked_StartRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeStopInterceptors() -> [ServerInterceptor<Caked_StopRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeSuspendInterceptors() -> [ServerInterceptor<Caked_SuspendRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeRestartInterceptors() -> [ServerInterceptor<Caked_RestartRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeTemplateInterceptors() -> [ServerInterceptor<Caked_TemplateRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeWaitIPInterceptors() -> [ServerInterceptor<Caked_WaitIPRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeImageInterceptors() -> [ServerInterceptor<Caked_ImageRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeLoginInterceptors() -> [ServerInterceptor<Caked_LoginRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeLogoutInterceptors() -> [ServerInterceptor<Caked_LogoutRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeCloneInterceptors() -> [ServerInterceptor<Caked_CloneRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makePushInterceptors() -> [ServerInterceptor<Caked_PushRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makePurgeInterceptors() -> [ServerInterceptor<Caked_PurgeRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeRemoteInterceptors() -> [ServerInterceptor<Caked_RemoteRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeNetworksInterceptors() -> [ServerInterceptor<Caked_NetworkRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeMountInterceptors() -> [ServerInterceptor<Caked_MountRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeUmountInterceptors() -> [ServerInterceptor<Caked_MountRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makePingInterceptors() -> [ServerInterceptor<Caked_PingRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeCurrentStatusInterceptors() -> [ServerInterceptor<Caked_CurrentStatusRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeGetScreenSizeInterceptors() -> [ServerInterceptor<Caked_GetScreenSizeRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeSetScreenSizeInterceptors() -> [ServerInterceptor<Caked_SetScreenSizeRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeInstallAgentInterceptors() -> [ServerInterceptor<Caked_InstallAgentRequest, Caked_Reply>] {
		return self.interceptors()
	}

	func makeGrandCentralDispatcherInterceptors() -> [ServerInterceptor<Caked_Empty, Caked_Reply>] {
		return self.interceptors()
	}

	func makeGrandCentralUpdateInterceptors() -> [ServerInterceptor<Caked_CurrentStatusReply.CurrentStatus, Caked_Empty>] {
		return self.interceptors()
	}
}
