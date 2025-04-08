import Foundation
import NIO
import vmnet
import Darwin
import Virtualization

final class VZVMNetSocket: VZVMNet, @unchecked Sendable {
	internal let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
	internal var childrenChannels: [Channel] = []
	internal let socketPath: URL
	internal let socketGroup: gid_t

	final class VZVMNetSocketHandler: VZVMNet.VZVMNetHandler {
		public typealias InboundIn = ByteBuffer
		public typealias OutboundOut = ByteBuffer
		private let vmnet: VZVMNetSocket

		init(vmnet: VZVMNetSocket) {
			self.vmnet = vmnet
			super.init(vzvmnet: vmnet)
		}

		override func forwardBuffer(buffer: ByteBuffer, context: ChannelHandlerContext) {
			var buffer = buffer
			let bufSize = buffer.readableBytes

			if self.vmnet.childrenChannels.count > 1 {
				if let copyData = buffer.readData(length: buffer.readableBytes) {
					let currentChannel = context.channel
					let buffer = ByteBuffer(data: copyData)

					self.vmnet.channelsSyncQueue.async {
						self.vmnet.childrenChannels.forEach { channel in
							if channel !== currentChannel {
								channel.writeAndFlush(buffer, promise: nil)
							}
						}
					}
				} else {
					self.logger.error("Failed to read \(bufSize) bytes")
				}
			}
		}
	}

	init(on: EventLoop, socketPath: URL, socketGroup: gid_t, networkName: String, networkConfig: VZSharedNetwork, pidFile: URL) {
		self.socketPath = socketPath
		self.socketGroup = socketGroup

		super.init(on: on, networkName: networkName, networkConfig: networkConfig, pidFile: pidFile)
	}

	override func write(data: Data) {
		let byteBuffer = ByteBuffer(data: data)

		self.childrenChannels.forEach { channel in
			channel.writeAndFlush(byteBuffer, promise: nil)
		}
	}

	override func start() throws {
		try startInterface()

		defer {
			self.stopInterface()
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
				self.childrenChannels.append(inboundChannel)

				inboundChannel.closeFuture.whenComplete { _ in
					self.childrenChannels.removeAll { $0 === inboundChannel }
				}

				return inboundChannel.pipeline.addHandler(VZVMNetSocketHandler(vmnet: self))
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
		try super.start()

		try self.serverChannel!.closeFuture.wait()
	}

	override func stop() {
		if let serverChannel = self.serverChannel {
			let promise = self.eventLoop.makePromise(of: Void.self)

			self.logger.info("Will stop VZVMNet on \(self.socketPath)")

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

		super.stop()
	}
}
