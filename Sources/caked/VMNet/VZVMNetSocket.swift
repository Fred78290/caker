import Foundation
import NIO
import vmnet
import Darwin
import Virtualization

extension Channel {
	public static func == (lhs: Channel, rhs: Channel) -> Bool {
		return lhs === rhs
	}
}

final class VZVMNetSocket: VZVMNet, @unchecked Sendable {
	let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
	var childrenChannels: [Channel] = []
	let socketPath: URL
	let socketGroup: gid_t

	final class VMNetHandler: ChannelInboundHandler {
		public typealias InboundIn = ByteBuffer
		public typealias OutboundOut = ByteBuffer

		private let vmnet: VZVMNetSocket
		private let logger = Logger("com.aldunelabs.caked.VMNetHandler")

		init(vmnet: VZVMNetSocket) {
			self.vmnet = vmnet
		}

		public func channelActive(context: ChannelHandlerContext) {
			self.vmnet.childrenChannels.append(context.channel)
		}

		public func channelInactive(context: ChannelHandlerContext) {
			self.vmnet.childrenChannels.removeAll { $0 === context.channel }
		}

		func channelRead(context: ChannelHandlerContext, data: NIOAny) {
			let buffer = self.unwrapInboundIn(data)
			var bufData = Data(buffer: buffer)
			let currentChannel = context.channel
			var count: Int32 = 1
			var buf: iovec = iovec(iov_base: bufData.withUnsafeMutableBytes { $0.baseAddress! }, iov_len: Int(bufData.count))
			var pd: vmpktdesc = vmpktdesc(vm_pkt_size: Int(bufData.count), vm_pkt_iov: withUnsafeMutablePointer(to: &buf, { $0 }), vm_pkt_iovcnt: 1, vm_flags: 0)
			let status = vmnet_write(self.vmnet.iface!, &pd, &count)

			guard  status == .VMNET_SUCCESS else {
				self.logger.error("Failed to write to interface \(status.stringValue)")
				return
			}

			if Logger.Level() >= LogLevel.debug {
				if count != 1 {
					self.logger.error("Failed to write all bytes to interface = written_count: \(pd.vm_pkt_size), bufData.count: \(bufData.count)")
				} else {
					self.logger.info("Wrote \(pd.vm_pkt_size) bytes to interface")
				}
			}

			self.vmnet.channelsSyncQueue.async {
				self.vmnet.childrenChannels.forEach { channel in
					if channel !== currentChannel {
						channel.writeAndFlush(bufData, promise: nil)
					}
				}
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
	     socketPath: URL,
	     socketGroup: gid_t,
	     mode: VMNetMode,
	     networkInterface: String? = nil,
	     gateway: String? = nil,
	     dhcpEnd: String?,
	     subnetMask: String = "255.255.255.0",
	     interfaceID: String = UUID().uuidString,
	     nat66Prefix: String? = nil,
		 pidFile: URL) {

		self.socketPath = socketPath
		self.socketGroup = socketGroup

		super.init(on: on, mode: mode, networkInterface: networkInterface,
		           gateway: gateway, dhcpEnd: dhcpEnd, subnetMask: subnetMask,
		           interfaceID: interfaceID, nat66Prefix: nat66Prefix, pidFile: pidFile)
	}

	override func write(buffer: Data) {
		let byteBuffer = ByteBuffer(data: buffer)

		self.childrenChannels.forEach { channel in
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

		let binder: EventLoopFuture<Channel>
		let socketPath = socketPath.path

		// Create the server bootstrap
		let bootstrap: ServerBootstrap = ServerBootstrap(group: Root.group)
			.serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.childChannelOption(ChannelOptions.socketOption(.so_broadcast), value: 1)
			.childChannelOption(ChannelOptions.socketOption(.so_rcvbuf), value: 4 * 1024 * 1024)
			.childChannelOption(ChannelOptions.socketOption(.so_sndbuf), value: 1 * 1024 * 1024)
			.childChannelOption(.maxMessagesPerRead, value: 16)
			.childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
			.childChannelInitializer { inboundChannel in
				return inboundChannel.pipeline.addHandler(VMNetHandler(vmnet: self))
			}

		// Listen on the console socket
		binder = bootstrap.bind(unixDomainSocketPath: socketPath, cleanupExistingSocketFile: true)

		// When the bind is complete, set the channel
		binder.whenComplete { result in
			switch result {
			case .success:
				self.logger.info("VZVMNet listening on \(self.socketPath)")
				if (chown(socketPath, getegid(), self.socketGroup) < 0) {
					self.logger.error("Failed to set group \(self.socketGroup) on socket \(socketPath)")
				}

				if (chmod(socketPath, 0o0770) < 0) {
					self.logger.error("Failed to set mod 770 on socket \(socketPath)")
				}

			case let .failure(error):
				self.logger.info("Failed to bind console on \(socketPath), \(error)")
			}
		}

		self.serverChannel = try binder.wait()
		try self.pidFile.writePID()

		try self.serverChannel!.closeFuture.wait()
	}

	override func stop() {
		if let serverChannel = self.serverChannel {
			let promise = self.eventLoop.makePromise(of: Void.self)

			EventLoopFuture.andAllComplete(self.childrenChannels.map { child in
				let promise: EventLoopPromise<Void> = child.eventLoop.makePromise()
				child.close(promise: promise)

				return promise.futureResult
			}, on: self.eventLoop).whenComplete { _ in
				self.childrenChannels.removeAll()
				serverChannel.close(mode: .all, promise: promise)
			}

			try? promise.futureResult.wait()
		}
	}
}
