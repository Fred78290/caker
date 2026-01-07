import Darwin
import Foundation
import NIO
import Virtualization
import vmnet
import CakeAgentLib

public final class VZVMNetFileHandle: VZVMNet, @unchecked Sendable {
	private let fileDescriptor: CInt

	final class VZVMNetFileHandleHandler: VZVMNet.VZVMNetHandler {
		public typealias InboundIn = ByteBuffer
		public typealias OutboundOut = ByteBuffer
		private let vmnet: VZVMNetFileHandle

		init(vmnet: VZVMNetFileHandle) {
			self.vmnet = vmnet

			super.init(vzvmnet: vmnet)
		}
	}

	public init(on: EventLoop, inputOutput: CInt, networkName: String, networkConfig: VZSharedNetwork, pidFile: URL) {
		self.fileDescriptor = inputOutput
		super.init(on: on, networkName: networkName, networkConfig: networkConfig, pidFile: pidFile)
	}

	public override func write(data: Data) {
		if let channel = self.serverChannel {
			let byteBuffer = ByteBuffer(data: data)

			channel.writeAndFlush(byteBuffer, promise: nil)
		}
	}

	public override func start() throws {
		try startInterface()

		defer {
			self.stopInterface()
		}

		#if DEBUG
			self.logger.debug("Will start pipe channel with fd=\(self.fileDescriptor)")
		#endif

		let promise = self.eventLoop.makePromise(of: Void.self)
		let pipe = NIOPipeBootstrap(group: self.eventLoop)
			.channelOption(.maxMessagesPerRead, value: 16)
			.takingOwnershipOfDescriptor(inputOutput: self.fileDescriptor)
			.flatMap { channel in
				#if DEBUG
					self.logger.debug("Started pipe channel with fd=\(self.fileDescriptor)")
				#endif

				self.serverChannel = channel

				channel.closeFuture.whenComplete { _ in
					promise.succeed(())
				}

				return channel.pipeline.addHandler(VZVMNetFileHandleHandler(vmnet: self))
			}

		try pipe.wait()
		try self.pidFile.writePID()

		promise.futureResult.whenComplete { _ in
			#if DEBUG
				self.logger.debug("Pipe channel closed on fd=\(self.fileDescriptor)")
			#endif
		}

		try promise.futureResult.wait()
	}

	public override func stop() {
		if let serverChannel = self.serverChannel {
			let promise = self.eventLoop.makePromise(of: Void.self)

			#if DEBUG
				self.logger.debug("Will stop pipe channel with fd=\(self.fileDescriptor)")
			#endif

			promise.futureResult.whenComplete { _ in
				#if DEBUG
					self.logger.debug("Pipe channel with fd=\(self.fileDescriptor) released on stop")
				#endif
			}

			serverChannel.close(mode: .all, promise: promise)

			try? promise.futureResult.wait()
		}

		super.stop()
	}
}
