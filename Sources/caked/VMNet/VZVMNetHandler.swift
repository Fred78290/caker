import Foundation
import System
import Virtualization
import GRPCLib
import NIO

// This is a simple ChannelDuplexHandler that glues two channels together.
// It is used to create a forwarder that forwards all data from one channel to another.
final class VZVMNetHandler: ChannelDuplexHandler {
	typealias InboundIn = ByteBuffer
	typealias OutboundIn = NIOAny
	typealias OutboundOut = NIOAny

	public protocol CloseDelegate {
		func closed(side: VZVMNetHandler.HandlerSide)
	}

	public enum HandlerSide: Int {
		case host = 0
		case guest = 1
	}

	private var partner: VZVMNetHandler?
	private var currentContext: ChannelHandlerContext?
	private var pendingRead: Bool = false
	private let useLimaVMNet: Bool
	private let side: HandlerSide
	private let delegate: CloseDelegate?
	private var notified: Bool = false

	private init(useLimaVMNet: Bool, side: HandlerSide, delegate: CloseDelegate?) {
		self.useLimaVMNet = useLimaVMNet
		self.side = side
		self.delegate = delegate
	}

	static func matchedPair(useLimaVMNet: Bool, delegate: CloseDelegate?) -> (VZVMNetHandler, VZVMNetHandler) {
		let guestHandler = VZVMNetHandler(useLimaVMNet: useLimaVMNet, side: .guest, delegate: delegate)
		let hostHandler = VZVMNetHandler(useLimaVMNet: useLimaVMNet, side: .host, delegate: delegate)

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

	func handlerAdded(context: ChannelHandlerContext) {
		self.currentContext = context
	}

	func handlerRemoved(context _: ChannelHandlerContext) {
		currentContext = nil
		partner = nil
	}

	func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		if useLimaVMNet {
			var byteBuffer = unwrapInboundIn(data)
			var readableBytes = byteBuffer.readableBytes

			if side == .host {
				//Logger(self).info("available \(readableBytes) bytes")

				while readableBytes > 0 {
					guard let packetLen = byteBuffer.readInteger(endianness: .big, as: UInt32.self) else {
						//Logger(self).error("Failed to read packet length")
						break
					}

					if let bufData = byteBuffer.readData(length: Int(packetLen)) {
						//Logger(self).info("Readed \(packetLen) bytes")
						partner?.partnerWrite(NIOAny(ByteBuffer(data: bufData)))
					} else {
						Logger(self).error("Failed to read \(packetLen) bytes")
					}
					/*
					let readerIndex = byteBuffer.readerIndex

					byteBuffer.withUnsafeMutableReadableBytes {
						let unsafeData = Data(bytesNoCopy: $0.baseAddress! + readerIndex, count: Int(packetLen), deallocator: .none)
						partner?.partnerWrite(NIOAny(ByteBuffer(data: unsafeData)))
					}*/

					readableBytes -= Int(packetLen) + MemoryLayout<UInt32>.size
					//Logger(self).info("Remains \(readableBytes) bytes")
				}

				//Logger(self).info("Done reading")

/*				byteBuffer.withUnsafeMutableReadableBytes {
					var baseAddress = $0.baseAddress!

					while readableBytes > 0 {
						let packetLen = baseAddress.assumingMemoryBound(to: UInt32.self).pointee.bigEndian
						let unsafeData = Data(bytesNoCopy: baseAddress + MemoryLayout<UInt32>.size, count: Int(packetLen), deallocator: .none)

						partner?.partnerWrite(NIOAny(ByteBuffer(data: unsafeData)))
	
						readableBytes -= Int(packetLen) + MemoryLayout<UInt32>.size
						baseAddress += Int(packetLen) + MemoryLayout<UInt32>.size
					}
				}

				byteBuffer.moveReaderIndex(forwardBy: byteBuffer.readableBytes)
*/
			} else {
				var buffer = context.channel.allocator.buffer(capacity: MemoryLayout<UInt32>.size + readableBytes)

				buffer.writeInteger(UInt32(readableBytes), endianness: .big, as: UInt32.self)
				buffer.writeBuffer(&byteBuffer)

				partner?.partnerWrite(NIOAny(buffer))
			}
		} else {
			partner?.partnerWrite(data)
		}
	}

	func channelReadComplete(context _: ChannelHandlerContext) {
		partner?.partnerFlush()
	}

	func channelInactive(context: ChannelHandlerContext) {
		context.flush()

		if let delegate , notified == false, partner?.notified == false {
			notified = true
			partner?.notified = true

			delegate.closed(side: side)
		}

		partner?.partnerCloseFull()
	}

	func userInboundEventTriggered(context _: ChannelHandlerContext, event: Any) {
		if let event = event as? ChannelEvent, case .inputClosed = event {
			// We have read EOF.
			partner?.partnerWriteEOF()
		}
	}

	func errorCaught(context _: ChannelHandlerContext, error : Error) {
		Logger(self).error(error)
		partner?.partnerCloseFull()
	}

	func channelWritabilityChanged(context: ChannelHandlerContext) {
		if context.channel.isWritable {
			partner?.partnerBecameWritable()
		}
	}

	func read(context: ChannelHandlerContext) {
		if let partner = partner, partner.partnerWritable {
			context.read()
		} else {
			pendingRead = true
		}
	}
}
