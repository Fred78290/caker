import Foundation
import GRPCLib
import NIO
import System
import Virtualization
import CakeAgentLib

// This is a simple ChannelDuplexHandler that glues two channels together.
// It is used to create a forwarder that forwards all data from one channel to another.
public final class VZVMNetHandlerClient: ChannelDuplexHandler {
	public typealias InboundIn = ByteBuffer
	public typealias OutboundIn = NIOAny
	public typealias OutboundOut = NIOAny

	public protocol CloseDelegate {
		func closed(side: VZVMNetHandlerClient.HandlerSide)
	}

	public enum HandlerSide: Int {
		case host = 0
		case guest = 1
	}

	private var partner: VZVMNetHandlerClient?
	private var currentContext: ChannelHandlerContext?
	private var pendingRead: Bool = false
	private let side: HandlerSide
	private let delegate: CloseDelegate?
	private var notified: Bool = false
	private let trace: Bool

	private init(side: HandlerSide, delegate: CloseDelegate?) {
		self.side = side
		self.delegate = delegate
		self.trace = Logger.Level() >= Logger.LogLevel.trace
	}

	static func matchedPair(delegate: CloseDelegate?) -> (VZVMNetHandlerClient, VZVMNetHandlerClient) {
		let guestHandler = VZVMNetHandlerClient(side: .guest, delegate: delegate)
		let hostHandler = VZVMNetHandlerClient(side: .host, delegate: delegate)

		guestHandler.partner = hostHandler
		hostHandler.partner = guestHandler

		return (guestHandler, hostHandler)
	}

	private func partnerWrite(_ data: NIOAny) {
		currentContext?.writeAndFlush(data, promise: nil)
	}

	private func partnerFlush() {
		currentContext?.flush()
	}

	private func partnerWriteEOF() {
		currentContext?.flush()
		currentContext?.close(mode: .output, promise: nil)
	}

	private func partnerCloseFull() {
		currentContext?.close(promise: nil)
	}

	private func partnerBecameWritable() {
		if pendingRead {
			pendingRead = false
			currentContext?.read()
		}
	}

	private var partnerWritable: Bool {
		currentContext?.channel.isWritable ?? false
	}

	public func handlerAdded(context: ChannelHandlerContext) {
		self.currentContext = context
	}

	public func handlerRemoved(context _: ChannelHandlerContext) {
		currentContext = nil
		partner = nil
	}

	public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		partner?.partnerWrite(data)
	}

	public func channelReadComplete(context _: ChannelHandlerContext) {
		partner?.partnerFlush()
	}

	public func channelInactive(context: ChannelHandlerContext) {
		context.flush()

		if let delegate, notified == false, partner?.notified == false {
			notified = true
			partner?.notified = true

			delegate.closed(side: side)
		}

		partner?.partnerCloseFull()
	}

	public func userInboundEventTriggered(context _: ChannelHandlerContext, event: Any) {
		if let event = event as? ChannelEvent, case .inputClosed = event {
			// We have read EOF.
			partner?.partnerWriteEOF()
		}
	}

	public func errorCaught(context _: ChannelHandlerContext, error: Error) {
		Logger(self).error(error)
		partner?.partnerCloseFull()
	}

	public func channelWritabilityChanged(context: ChannelHandlerContext) {
		if context.channel.isWritable {
			partner?.partnerBecameWritable()
		}
	}

	public func read(context: ChannelHandlerContext) {
		if let partner = partner, partner.partnerWritable {
			context.read()
		} else {
			pendingRead = true
		}
	}
}
