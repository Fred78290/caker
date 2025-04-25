import GRPC
import NIO
import GRPCLib
import SwiftProtobuf
import CakeAgentLib

final class CakeAgentClientInterceptorFactory: CakeAgentInterceptor {
	let responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>
	let errorCaught: @Sendable () -> ()

	private class ExecuteCakeAgentClientInterceptor: ClientInterceptor<Cakeagent_ExecuteRequest, Cakeagent_ExecuteResponse>, @unchecked Sendable {
		let responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>
		let errorCaught: () -> ()

		init(responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, errorCaught: @Sendable @escaping () -> ()) {
			self.responseStream = responseStream
			self.errorCaught = errorCaught
		}

		func sendError(error: Error, context: ClientInterceptorContext<Cakeagent_ExecuteRequest, Cakeagent_ExecuteResponse>) {
			self.errorCaught()

			var error = error

			if let status = error as? GRPCStatusTransformable {
				error = status.makeGRPCStatus()
			}

			guard let err = error as? GRPCStatus else {
				_ = context.eventLoop.makeFutureWithTask {
					try? await self.responseStream.send(Caked_ExecuteResponse.with { 
						$0.failure = error.localizedDescription
					})
				}
				return
			}

			_ = context.eventLoop.makeFutureWithTask {
				try? await self.responseStream.send(Caked_ExecuteResponse.with { 
					$0.failure = err.code == .unavailable || err.code == .cancelled ? "Connection refused" : err.description
				})
			}
		}

		override func errorCaught(_ error: Error, context: ClientInterceptorContext<Cakeagent_ExecuteRequest, Cakeagent_ExecuteResponse>) {
			super.errorCaught(error, context: context)
			Logger(self).error(error)
			self.sendError(error: error, context: context)
		}

		override func cancel(promise: EventLoopPromise<Void>?, context: ClientInterceptorContext<Cakeagent_ExecuteRequest, Cakeagent_ExecuteResponse>) {
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

	init(responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, errorCaught: @Sendable @escaping () -> ()) {
		self.responseStream = responseStream
		self.errorCaught = errorCaught
	}

	func makeInfoInterceptors() -> [ClientInterceptor<Google_Protobuf_Empty, Cakeagent_InfoReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makeShutdownInterceptors() -> [ClientInterceptor<Google_Protobuf_Empty, Cakeagent_RunReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makeRunInterceptors() -> [ClientInterceptor<Cakeagent_RunCommand, Cakeagent_RunReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makeExecuteInterceptors() -> [ClientInterceptor<Cakeagent_ExecuteRequest, Cakeagent_ExecuteResponse>] {
		[ExecuteCakeAgentClientInterceptor(responseStream: self.responseStream, errorCaught: errorCaught)]
	}

	func makeMountInterceptors() -> [ClientInterceptor<Cakeagent_MountRequest, Cakeagent_MountReply>] {
		[CakeAgentClientInterceptor()]
	}

	func makeUmountInterceptors() -> [ClientInterceptor<Cakeagent_MountRequest, Cakeagent_MountReply>] {
		[CakeAgentClientInterceptor()]
	}

}

