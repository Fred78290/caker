import Foundation
import NIO
import vmnet
import Darwin
import Virtualization

final class VZVMNetFileHandle: VZVMNet, @unchecked Sendable {
	private var channel: Channel? = nil
	private let fileDescriptor: CInt
	private let macAddress: String

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
			var buf = self.unwrapInboundIn(data)
			let bufLen = buf.readableBytes

			buf.withUnsafeMutableReadableBytes {
				var count: Int32 = 1
				var io: iovec = iovec(iov_base: $0.baseAddress!, iov_len: Int(bufLen))

				withUnsafeMutablePointer(to: &io) {
					var pd: vmpktdesc = vmpktdesc(vm_pkt_size: Int(bufLen), vm_pkt_iov: $0, vm_pkt_iovcnt: 1, vm_flags: 0)
					let status = vmnet_write(self.vmnet.iface!, &pd, &count)

					self.vmnet.traceMacAddress(0, ptr: $0, size: pd.vm_pkt_size, direction: "received from guest")

					guard status == .VMNET_SUCCESS else {
						self.logger.error("Failed to write to interface \(status.stringValue)")
						return
					}

					if self.vmnet.trace {
						if count != 1 {
							self.logger.error("Failed to write all bytes to interface = written_count: \(pd.vm_pkt_size), bufData.count: \(bufLen)")
						} else {
							self.logger.trace("Wrote \(pd.vm_pkt_size) bytes to interface")
						}
					}
				}
			}

/*			var bufData = Data(buffer: buffer)
			var count: Int32 = 1
			var buf: iovec = iovec(iov_base: bufData.withUnsafeMutableBytes { $0.baseAddress! }, iov_len: Int(bufData.count))
			var pd: vmpktdesc = vmpktdesc(vm_pkt_size: Int(bufData.count), vm_pkt_iov: withUnsafeMutablePointer(to: &buf, { $0 }), vm_pkt_iovcnt: 1, vm_flags: 0)
			let status = vmnet_write(self.vmnet.iface!, &pd, &count)

			guard status == .VMNET_SUCCESS else {
				self.logger.error("Failed to write to interface \(status.stringValue)")
				return
			}

			if Logger.Level() >= LogLevel.debug {
				if count != 1 {
					self.logger.error("Failed to write all bytes to interface = written_count: \(pd.vm_pkt_size), bufData.count: \(bufData.count)")
				} else {
					self.logger.info("Wrote \(pd.vm_pkt_size) bytes to interface")
				}
			}*/
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
		 macAddress: String,
	     gateway: String? = nil,
	     dhcpEnd: String?,
	     subnetMask: String = "255.255.255.0",
	     interfaceID: String = UUID().uuidString,
	     nat66Prefix: String? = nil,
	     pidFile: URL) {

		self.fileDescriptor = inputOutput
		self.macAddress = macAddress
		super.init(on: on, mode: mode, networkInterface: networkInterface,
		           gateway: gateway, dhcpEnd: dhcpEnd, subnetMask: subnetMask,
		           interfaceID: interfaceID, nat66Prefix: nat66Prefix, pidFile: pidFile)
	}

	override func write(data: Data) {
		if let channel = self.channel {
			let byteBuffer = ByteBuffer(data: data)

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
					self.logger.error("Failed to stop interface \(status.stringValue)")
				}
			}
		}

		self.logger.info("Will start pipe channel with fd=\(self.fileDescriptor)")

		let promise = self.eventLoop.makePromise(of: Void.self)
		let pipe = NIOPipeBootstrap(group: self.eventLoop)
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
		try self.pidFile.writePID()

		promise.futureResult.whenComplete { _ in
			self.logger.info("Pipe channel released")
		}

		try promise.futureResult.wait()
	}

	override func stop() {
		if let serverChannel = self.serverChannel {
			let promise = self.eventLoop.makePromise(of: Void.self)

			serverChannel.close(mode: .all, promise: promise)

			try? promise.futureResult.wait()
		}

		super.stop()
	}
}
