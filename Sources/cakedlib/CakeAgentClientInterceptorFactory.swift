import Atomics
import CakeAgentLib
import GRPC
import GRPCLib
import NIO
import SwiftProtobuf

final class CakeAgentClientInterceptorFactory: CakeAgentServiceClientInterceptorFactoryProtocol {
	let responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>
	let errorCaught: ManagedAtomicLazyReference<AtomicError>

	final class AtomicError: Sendable {
		let error: Error

		init(error: Error) {
			self.error = error
		}
	}

	private class ExecuteCakeAgentClientInterceptor: ClientInterceptor<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>, @unchecked Sendable {
		let responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>
		let errorCaught: ManagedAtomicLazyReference<AtomicError>

		init(responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, errorCaught: ManagedAtomicLazyReference<AtomicError>) {
			self.responseStream = responseStream
			self.errorCaught = errorCaught
		}

		func sendError(error: Error, context: ClientInterceptorContext<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>) {
			var error = error

			if let status = error as? GRPCStatusTransformable {
				error = status.makeGRPCStatus()
			}

			_ = self.errorCaught.storeIfNilThenLoad(.init(error: error))

			guard let err = error as? GRPCStatus else {
				_ = context.eventLoop.makeFutureWithTask {
					try? await self.responseStream.send(
						Caked_ExecuteResponse.with {
							$0.failure = error.localizedDescription
						})
				}
				return
			}

			_ = context.eventLoop.makeFutureWithTask {
				try? await self.responseStream.send(
					Caked_ExecuteResponse.with {
						$0.failure = err.code == .unavailable || err.code == .cancelled ? "Connection refused" : err.description
					})
			}
		}

		override func errorCaught(_ error: Error, context: ClientInterceptorContext<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>) {
			super.errorCaught(error, context: context)
			Logger(self).error(error)
			self.sendError(error: error, context: context)
		}

		override func cancel(promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>) {
			super.cancel(promise: promise, context: context)
			self.sendError(error: GRPCStatus(code: .cancelled), context: context)
		}
	}

	private class CakeAgentClientInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
		override func errorCaught(_ error: Error, context: ClientInterceptorContext<Request, Response>) {
			super.errorCaught(error, context: context)
		}

		override func cancel(promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Request, Response>) {
			super.cancel(promise: promise, context: context)
		}
	}

	init(responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>) {
		self.responseStream = responseStream
		self.errorCaught = .init()
	}

	func makeResizeDiskInterceptors() -> [ClientInterceptor<CakeAgent.Empty, CakeAgent.ResizeReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makeInfoInterceptors() -> [ClientInterceptor<CakeAgent.Empty, CakeAgent.InfoReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makePingInterceptors() -> [ClientInterceptor<CakeAgent.PingRequest, CakeAgent.PingReply>] {
		[CakeAgentClientInterceptor()]
	}
	
	func makeShutdownInterceptors() -> [ClientInterceptor<CakeAgent.Empty, CakeAgent.RunReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makeRunInterceptors() -> [ClientInterceptor<CakeAgent.RunCommand, CakeAgent.RunReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makeExecuteInterceptors() -> [ClientInterceptor<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>] {
		[ExecuteCakeAgentClientInterceptor(responseStream: self.responseStream, errorCaught: errorCaught)]
	}

	func makeMountInterceptors() -> [ClientInterceptor<CakeAgent.MountRequest, CakeAgent.MountReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makeUmountInterceptors() -> [ClientInterceptor<CakeAgent.MountRequest, CakeAgent.MountReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makeTunnelInterceptors() -> [ClientInterceptor<CakeAgent.TunnelMessage, CakeAgent.TunnelMessage>] {
		[CakeAgentClientInterceptor()]
	}

	func makeEventsInterceptors() -> [GRPC.ClientInterceptor<CakeAgentLib.Cakeagent_CakeAgent.Empty, CakeAgentLib.Cakeagent_CakeAgent.TunnelPortForwardEvent>] {
		[CakeAgentClientInterceptor()]
	}

}
