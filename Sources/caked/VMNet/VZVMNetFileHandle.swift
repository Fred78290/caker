import Foundation
import NIO
import vmnet
import Darwin
import Virtualization

final class VZVMNetFileHandle: VZVMNet, @unchecked Sendable {
	private var channel: Channel? = nil
	private let fileDescriptor: CInt

	final class VMNetHandler: ChannelInboundHandler {
		public typealias InboundIn = ByteBuffer
		public typealias OutboundOut = ByteBuffer

		private let vmnet: VZVMNet
		private let logger = Logger("com.aldunelabs.caked.VMNetHandler")

		init(vmnet: VZVMNet) {
			self.vmnet = vmnet
		}

		public func channelActive(context: ChannelHandlerContext) {
			self.vmnet.serverChannel = context.channel
		}

		public func channelInactive(context: ChannelHandlerContext) {
			self.vmnet.serverChannel = nil
		}

		func channelRead(context: ChannelHandlerContext, data: NIOAny) {
			let buffer = self.unwrapInboundIn(data)
			var bufData = Data(buffer: buffer)
			var written_count: Int32 = Int32(bufData.count)
			var buf: iovec = iovec(iov_base: bufData.withUnsafeMutableBytes { $0.baseAddress! }, iov_len: Int(written_count))
			var pd: vmpktdesc = vmpktdesc(vm_pkt_size: Int(written_count), vm_pkt_iov: withUnsafeMutablePointer(to: &buf, { $0 }), vm_pkt_iovcnt: 1, vm_flags: 0)

			guard vmnet_write(self.vmnet.iface!, &pd, &written_count) != .VMNET_SUCCESS else {
				self.logger.error("Failed to write to interface")
				return
			}

			if written_count != bufData.count {
				self.logger.error("Failed to write all bytes to interface = written_count: \(written_count), bufData.count: \(bufData.count)")
			}
		}

		func channelReadComplete(context: ChannelHandlerContext) {
			context.flush()
		}

		func errorCaught(context: ChannelHandlerContext, error: Error) {
			self.logger.error("Error: \(error)")
		}
	}

	init(on: EventLoop,
	     inputOutput: CInt,
	     mode: VMNetMode,
	     networkInterface: String? = nil,
	     gateway: String? = nil,
	     dhcpEnd: String?,
	     subnetMask: String = "255.255.255.0",
	     interfaceID: String = UUID().uuidString,
	     nat66Prefix: String? = nil) {

		self.fileDescriptor = inputOutput
		super.init(on: on, mode: mode, networkInterface: networkInterface,
		           gateway: gateway, dhcpEnd: dhcpEnd, subnetMask: subnetMask,
		           interfaceID: interfaceID, nat66Prefix: nat66Prefix)
	}

	override func write(buffer: Data) {
		if let channel = self.channel {
			let byteBuffer = ByteBuffer(data: buffer)

			channel.writeAndFlush(byteBuffer, promise: nil)
		}
	}

	override func start() throws {
		try startInterface()

		self.setupSignals()

		defer {
			if let iface = self.iface {
				let semaphore = DispatchSemaphore(value: 0)
				let status = vmnet_stop_interface(iface, hostQueue) { status in
					semaphore.signal()
				}

				if status != .VMNET_SUCCESS {
					self.logger.error("Failed to stop interface \(status)")
				}
			}
		}

		let promise = self.eventLoop.makePromise(of: Void.self)
		let pipe = NIOPipeBootstrap(group: self.eventLoop)
			.channelOption(ChannelOptions.socketOption(.so_rcvbuf), value: 4 * 1024 * 1024)
			.channelOption(ChannelOptions.socketOption(.so_sndbuf), value: 1 * 1024 * 1024)
			.channelOption(.maxMessagesPerRead, value: 16)
			.takingOwnershipOfDescriptor(inputOutput: self.fileDescriptor)
			.flatMap { channel in

				channel.closeFuture.whenComplete { _ in
					self.logger.info("Pipe channel closed")
					promise.succeed(())
				}

				return channel.pipeline.addHandler(VMNetHandler(vmnet: self))
			}

		try pipe.wait()

		promise.futureResult.whenComplete { _ in
			self.logger.info("Pipe channel released")
		}

		self.logger.info("Will wait for pipe channel")
		try promise.futureResult.wait()
		self.logger.info("Pipe channel exited")
	}

	override func stop() {
		if let serverChannel = self.serverChannel {
			let promise = self.eventLoop.makePromise(of: Void.self)

			serverChannel.close(mode: .all, promise: promise)

			try? promise.futureResult.wait()
		}
	}
}
