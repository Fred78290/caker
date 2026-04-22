//
//  CakedPasswordAuthClientInterceptorFactory.swift
//  Caker
//
//  Created by Frederic BOLTZ on 20/04/2026.
//

import GRPC
import NIOCore
import NIOHPACK
import SwiftProtobuf

public final class CakedPasswordAuthClientInterceptorFactory: Caked_ServiceClientInterceptorFactoryProtocol {
	private let client: CakedServiceClient
	private let password: String
	private let chainedInterceptors: Caked_ServiceClientInterceptorFactoryProtocol?
	
	public class CakedPasswordAuthClientInterceptor<Request: Message, Response: Message>: ClientInterceptor<Request, Response>, @unchecked Sendable {
		private let password: String
		private let client: CakedServiceClient
		private let chainedInterceptors: [ClientInterceptor<Request, Response>]
		
		private enum State {
			// We're trying the call, these are the parts we've sent so far.
			case trying([GRPCClientRequestPart<Request>])
			// We're retrying using this call.
			case retrying(Call<Request, Response>)
		}
		
		private var state: State = .trying([])
		
		public init(password: String, client: CakedServiceClient, chainedInterceptors: [ClientInterceptor<Request, Response>] = []) {
			self.password = password
			self.client = client
			self.chainedInterceptors = chainedInterceptors
		}
		
		override public func cancel(promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Request, Response>) {
			switch self.state {
			case .trying:
				context.cancel(promise: promise)
				
			case .retrying(let call):
				call.cancel(promise: promise)
				context.cancel(promise: nil)
			}
		}
		
		override public func send(_ part: GRPCClientRequestPart<Request>, promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Request, Response>) {
			switch self.state {
			case .trying(var parts):
				// Record the part, incase we need to retry.
				parts.append(part)
				
				var part = part
				
				if case .metadata(var metadata) = part {
					metadata.replaceOrAdd(name: "authorization", value: "bearer \(self.password.base64EncodedString())")
					part = .metadata(metadata)
				}
				
				self.state = .trying(parts)
				// Forward the request part.
				context.send(part, promise: promise)
				
			case .retrying(let call):
				// We're retrying, send the part to the retry call.
				call.send(part, promise: promise)
			}
		}
		
		override public func receive(_ part: GRPCClientResponsePart<Response>, context: ClientInterceptorContext<Request, Response>) {
			switch self.state {
			case .trying(var parts):
				switch part {
					// If 'authentication' fails this is the only part we expect, we can forward everything else.
				case .end(let status, let trailers) where status.code == .unauthenticated:
					// We only know how to deal with magic.
					guard trailers.first(name: "www-authenticate") == "Magic" else {
						// We can't handle this, fail.
						context.receive(part)
						return
					}
					
					// We know how to handle this: make a new call.
					let call: Call<Request, Response> = self.client.channel.makeCall(
						path: context.path,
						type: context.type,
						callOptions: context.options,
						// We could grab interceptors from the client, but we don't need to.
						interceptors: self.chainedInterceptors
					)
					
					// We're retying the call now.
					self.state = .retrying(call)
					
					// Invoke the call and redirect responses here.
					call.invoke(onError: context.errorCaught(_:), onResponsePart: context.receive(_:))
					
					// Parts must contain the metadata as the first item if we got that first response.
					if case .some(.metadata(var metadata)) = parts.first {
						metadata.replaceOrAdd(name: "authorization", value: "bearer \(self.password.base64EncodedString())")
						parts[0] = .metadata(metadata)
					}
					
					// Now replay any requests on the retry call.
					for part in parts {
						call.send(part, promise: nil)
					}
					
				default:
					context.receive(part)
				}
				
			case .retrying:
				// Ignore anything we receive on the original call.
				()
			}
		}
	}
	
	public init(password: String, client: CakedServiceClient) {
		self.password = password
		self.client = client
		self.chainedInterceptors = client.interceptors
	}
	
	func interceptors<Request: Message, Response: Message>(_ chainedInterceptors: [ClientInterceptor<Request, Response>]?) -> [ClientInterceptor<Request, Response>] {
		var interceptors: [ClientInterceptor<Request, Response>] = [CakedPasswordAuthClientInterceptor<Request, Response>(password: self.password, client: self.client)]
		
		if let chainedInterceptors {
			interceptors.append(contentsOf: chainedInterceptors)
		}
		
		return interceptors
	}
	
	public func makeBuildInterceptors() -> [ClientInterceptor<Caked_BuildRequest, Caked_BuildStreamReply>] {
		self.interceptors(self.chainedInterceptors?.makeBuildInterceptors())
	}
	
	public func makeConfigureInterceptors() -> [ClientInterceptor<Caked_ConfigureRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeConfigureInterceptors())
	}
	
	public func makeDeleteInterceptors() -> [ClientInterceptor<Caked_DeleteRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeDeleteInterceptors())
	}
	
	public func makeDuplicateInterceptors() -> [ClientInterceptor<Caked_DuplicateRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeDuplicateInterceptors())
	}
	
	public func makeExecuteInterceptors() -> [ClientInterceptor<Caked_ExecuteRequest, Caked_ExecuteResponse>] {
		self.interceptors(self.chainedInterceptors?.makeExecuteInterceptors())
	}
	
	public func makeInfoInterceptors() -> [ClientInterceptor<Caked_InfoRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeInfoInterceptors())
	}
	
	public func makeVncInfosInterceptors() -> [ClientInterceptor<Caked_InfoRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeVncInfosInterceptors())
	}
	
	public func makeLaunchInterceptors() -> [ClientInterceptor<Caked_LaunchRequest, Caked_LaunchStreamReply>] {
		self.interceptors(self.chainedInterceptors?.makeLaunchInterceptors())
	}
	
	public func makeListInterceptors() -> [ClientInterceptor<Caked_ListRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeListInterceptors())
	}
	
	public func makeRenameInterceptors() -> [ClientInterceptor<Caked_RenameRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeRenameInterceptors())
	}
	
	public func makeRunInterceptors() -> [ClientInterceptor<Caked_RunCommand, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeRunInterceptors())
	}
	
	public func makeStartInterceptors() -> [ClientInterceptor<Caked_StartRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeStartInterceptors())
	}
	
	public func makeStopInterceptors() -> [ClientInterceptor<Caked_StopRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeStopInterceptors())
	}
	
	public func makeSuspendInterceptors() -> [ClientInterceptor<Caked_SuspendRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeSuspendInterceptors())
	}
	
	public func makeRestartInterceptors() -> [ClientInterceptor<Caked_RestartRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeRestartInterceptors())
	}
	
	public func makeTemplateInterceptors() -> [ClientInterceptor<Caked_TemplateRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeTemplateInterceptors())
	}
	
	public func makeWaitIPInterceptors() -> [ClientInterceptor<Caked_WaitIPRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeWaitIPInterceptors())
	}
	
	public func makeImageInterceptors() -> [ClientInterceptor<Caked_ImageRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeImageInterceptors())
	}
	
	public func makeLoginInterceptors() -> [ClientInterceptor<Caked_LoginRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeLoginInterceptors())
	}
	
	public func makeLogoutInterceptors() -> [ClientInterceptor<Caked_LogoutRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeLogoutInterceptors())
	}
	
	public func makeCloneInterceptors() -> [ClientInterceptor<Caked_CloneRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeCloneInterceptors())
	}
	
	public func makePushInterceptors() -> [ClientInterceptor<Caked_PushRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makePushInterceptors())
	}
	
	public func makePurgeInterceptors() -> [ClientInterceptor<Caked_PurgeRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makePurgeInterceptors())
	}
	
	public func makeRemoteInterceptors() -> [ClientInterceptor<Caked_RemoteRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeRemoteInterceptors())
	}
	
	public func makeNetworksInterceptors() -> [ClientInterceptor<Caked_NetworkRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeNetworksInterceptors())
	}
	
	public func makeMountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeMountInterceptors())
	}
	
	public func makeUmountInterceptors() -> [ClientInterceptor<Caked_MountRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeUmountInterceptors())
	}
	
	public func makePingInterceptors() -> [ClientInterceptor<Caked_PingRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makePingInterceptors())
	}
	
	public func makeCurrentStatusInterceptors() -> [ClientInterceptor<Caked_CurrentStatusRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeCurrentStatusInterceptors())
	}
	
	public func makeGetScreenSizeInterceptors() -> [ClientInterceptor<Caked_GetScreenSizeRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeGetScreenSizeInterceptors())
	}
	
	public func makeSetScreenSizeInterceptors() -> [ClientInterceptor<Caked_SetScreenSizeRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeSetScreenSizeInterceptors())
	}
	
	public func makeInstallAgentInterceptors() -> [ClientInterceptor<Caked_InstallAgentRequest, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeInstallAgentInterceptors())
	}
	
	public func makeGrandCentralDispatcherInterceptors() -> [ClientInterceptor<Caked_Empty, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeGrandCentralDispatcherInterceptors())
	}
	
	public func makeGrandCentralUpdateInterceptors() -> [ClientInterceptor<Caked_CurrentStatus, Caked_Empty>] {
		self.interceptors(self.chainedInterceptors?.makeGrandCentralUpdateInterceptors())
	}
	
	public func makeVncTunnelInterceptors() -> [ClientInterceptor<Caked_VncStream, Caked_VncStream>] {
		self.interceptors(self.chainedInterceptors?.makeVncTunnelInterceptors())
	}
	
	public func makeCheckReliabilityInterceptors() -> [ClientInterceptor<Caked_Empty, Caked_Reply>] {
		self.interceptors(self.chainedInterceptors?.makeCheckReliabilityInterceptors())
	}
}

