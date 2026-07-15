import Darwin
import Foundation
import NIO
import Virtualization
import vmnet
import GRPCLib

public final class VZVMNetSocket: VZVMNetImpl, @unchecked Sendable {
	internal let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
	internal var childrenChannels: [Channel] = []

	final class VZVMNetSocketHandler: VZVMNetImpl.VZVMNetHandler {
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

	public override init(on: EventLoop, socketGroup: gid_t, networkName: String, networkConfig: VZSharedNetwork, socketPath: URL, pidFile: URL, runMode: Utils.RunMode) {
		super.init(on: on, socketGroup: socketGroup, networkName: networkName, networkConfig: networkConfig, socketPath: socketPath, pidFile: pidFile, runMode: runMode)
	}

	public override func write(data: Data) {
		let byteBuffer = ByteBuffer(data: data)

		self.childrenChannels.forEach { channel in
			channel.writeAndFlush(byteBuffer, promise: nil)
		}
	}

	public override func start() throws {
		try startInterface()

		defer {
			self.stopInterface()
		}

		let binder: EventLoopFuture<Channel>
		let socketPath = socketPath.path

		// Create the server bootstrap
		let bootstrap: ServerBootstrap = ServerBootstrap(group: Utilities.group)
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
				if chown(socketPath, getegid(), self.socketGroup) < 0 {
					self.logger.error("Failed to set group \(self.socketGroup) on socket \(socketPath), reason: \(String(cString: strerror(errno)))")
				}

				if chmod(socketPath, 0o0770) < 0 {
					self.logger.error("Failed to set mod 770 on socket \(socketPath), reason: \(String(cString: strerror(errno)))")
				}

			case .failure(let error):
				self.logger.info("Failed to bind console on \(socketPath), \(error)")
			}
		}

		let serverChannel = try binder.wait()
		self.serverChannel = serverChannel
		
		try super.start()

		try serverChannel.closeFuture.wait()
	}

	public override func stop() {
		if let serverChannel {
			let promise = self.eventLoop.makePromise(of: Void.self)

			self.logger.info("Will stop VZVMNet on \(self.socketPath)")

			EventLoopFuture.andAllComplete(
				self.childrenChannels.map { child in
					let promise: EventLoopPromise<Void> = child.eventLoop.makePromise()
					child.close(promise: promise)

					return promise.futureResult
				}, on: self.eventLoop
			).whenComplete { _ in
				self.childrenChannels.removeAll()
				serverChannel.close(mode: .all, promise: promise)
			}

			try? promise.futureResult.wait()
		}

		super.stop()
	}
}
