import Foundation
import NIO
import vmnet
import Darwin
import Virtualization

let MAX_PACKET_COUNT_AT_ONCE: UInt64 = 32
extension Channel {
	public static func == (lhs: Channel, rhs: Channel) -> Bool {
		return lhs === rhs
	}
}

final class VZVMNet: @unchecked Sendable {
	private var childrenChannels: [Channel] = []
	private var serverChannel: Channel? = nil
	let eventLoop: EventLoop
	let socketPath: URL
	let socketGroup: gid_t
	let mode: VMNetMode
	let networkInterface: String?
	let gateway: String?
	let dhcpEnd: String?
	let subnetMask: String
	let interfaceID: String
	let nat66Prefix: String?
	var iface: interface_ref?
	var max_bytes: UInt64 = 2048
	let hostQueue: DispatchQueue
	let sigint: any DispatchSourceSignal
	let sighup: any DispatchSourceSignal
	let sigterm: any DispatchSourceSignal
	let logger = Logger("com.aldunelabs.caked.VZVMNet")

	final class VMNetHandler: ChannelInboundHandler {
		public typealias InboundIn = ByteBuffer
		public typealias OutboundOut = ByteBuffer

		private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
		private let vmnet: VZVMNet
		private let logger = Logger("com.aldunelabs.caked.VMNetHandler")

		init(vmnet: VZVMNet) {
			self.vmnet = vmnet
		}

		public func channelActive(context: ChannelHandlerContext) {
			self.vmnet.childrenChannels.append(context.channel)
		}

		public func channelInactive(context: ChannelHandlerContext) {
			self.vmnet.childrenChannels.removeAll { $0 === context.channel }
		}

		func channelRead(context: ChannelHandlerContext, data: NIOAny) {
			var buffer = self.unwrapInboundIn(data)

			var bufData = Data(buffer: buffer)
			let currentChannel = context.channel

			channelsSyncQueue.async {
				var written_count: Int32 = Int32(bufData.count)
				var buf: iovec = iovec(iov_base: bufData.withUnsafeMutableBytes { $0.baseAddress! }, iov_len: Int(written_count))
				var pd: vmpktdesc = vmpktdesc(vm_pkt_size: Int(written_count), vm_pkt_iov: withUnsafeMutablePointer(to: &buf, { $0 }), vm_pkt_iovcnt: 1, vm_flags: 0)

				guard vmnet_write(self.vmnet.iface!, &pd, &written_count) != .VMNET_SUCCESS else {
					self.logger.error("Failed to write to interface")
					return
				}

				if written_count != self.header {
					self.logger.error("Failed to write all bytes to interface")
				}

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

	init(on: EventLoop, socketPath: URL, socketGroup: gid_t, mode: VMNetMode, networkInterface: String? = nil, gateway: String? = nil, dhcpEnd: String?, subnetMask: String = "255.255.255.0", interfaceID: String = UUID().uuidString, nat66Prefix: String? = nil) {
		self.eventLoop = on
		self.socketPath = socketPath
		self.socketGroup = socketGroup
		self.mode = mode
		self.networkInterface = networkInterface
		self.gateway = gateway
		self.dhcpEnd = dhcpEnd
		self.subnetMask = subnetMask
		self.interfaceID = interfaceID
		self.nat66Prefix = nat66Prefix
		self.hostQueue = DispatchQueue(label: "com.aldunelabs.caker.vmnet.host", qos: .userInitiated)

		signal(SIGINT, SIG_IGN)
		signal(SIGHUP, SIG_IGN)
		signal(SIGTERM, SIG_IGN)

		self.sigint = DispatchSource.makeSignalSource(signal: SIGINT)
		self.sighup = DispatchSource.makeSignalSource(signal: SIGHUP)
		self.sigterm = DispatchSource.makeSignalSource(signal: SIGTERM)
	}

	private func print_vmnet_start_param(params: xpc_object_t?) {
		guard let params = params else {
			self.logger.info("params not defined")
			return
		}

		xpc_dictionary_apply(params) { key, value in
			let t = xpc_get_type(value)
			let key = String(cString: key)

			if t == XPC_TYPE_UINT64 {
				self.logger.info("\(key): \(xpc_dictionary_get_uint64(params, key))")
			} else if t == XPC_TYPE_INT64 {
				self.logger.info("\(key): \(xpc_dictionary_get_int64(params, key))")
			} else if t == XPC_TYPE_STRING {
				if let cstr = xpc_string_get_string_ptr(value) {
					let value = String(cString: cstr)

					self.logger.info("\(key): \(value)")
				}
			} else if t == XPC_TYPE_UUID {
				UnsafeMutablePointer<Int8>.allocate(capacity: 37).withMemoryRebound(to: UInt8.self, capacity: 37) { uuid in
					uuid_unparse(xpc_uuid_get_bytes(value), uuid)

					let value = String(cString: uuid)
					self.logger.info("\(key): \(value)")
				}
			} else {
				self.logger.info("\(key): \(t)")
			}

			return true
		}
	}

	func setupSignals() {
		let signalHandler = {
			self.stop()
		}

		sigint.setEventHandler(handler: signalHandler)
		sighup.setEventHandler(handler: signalHandler)
		sigterm.setEventHandler(handler: signalHandler)
		sigint.activate()
		sighup.activate()
		sigterm.activate()
	}

	func vmnetPacketAvailable(_ estim_count: UInt64) {
		let q = estim_count / MAX_PACKET_COUNT_AT_ONCE;
		let r = estim_count % MAX_PACKET_COUNT_AT_ONCE;

		let on_vmnet_packets_available = { (count: UInt64) in
			let max_bytes = Int(self.max_bytes)
			var received_count: Int32 = Int32(count)
			var pdv: [vmpktdesc] = []
			var io: [iovec] = []

			pdv.reserveCapacity(Int(count))
			io.reserveCapacity(Int(count))

			for i in 0..<Int(count) {
				io.append(iovec(iov_base: UnsafeMutablePointer<UInt8>.allocate(capacity: Int(self.max_bytes)), iov_len: max_bytes))
				pdv.append(vmpktdesc(vm_pkt_size: max_bytes, vm_pkt_iov: withUnsafeMutablePointer(to: &io[i], { $0 }), vm_pkt_iovcnt: 1, vm_flags: 0))
			}

			defer {
				io.forEach {
					$0.iov_base.deallocate()
				}
			}

			let status = vmnet_read(self.iface!, &pdv, &received_count)

			if status != .VMNET_SUCCESS {
				self.logger.error("Failed to read from interface \(status)")
				return
			}

			for i in 0..<Int(received_count) {
				let iop = io[i]
				let pd: vmpktdesc = pdv[i]

				if Logger.Level() >= LogLevel.debug {
					let numberOfItems = 2
					let macAddress = iop.iov_base.withMemoryRebound(to: ether_addr_t.self, capacity: numberOfItems)  { typedPtr in
						// Convert pointer to buffer pointer to access buffer via indices
						let bufferPointer = UnsafeBufferPointer(start: typedPtr, count: numberOfItems)

						// Construct array
						return [ether_addr_t](unsafeUninitializedCapacity: numberOfItems) { arrayBuffer, count in
							count = numberOfItems
							for i in 0..<numberOfItems {
								arrayBuffer[i] = bufferPointer[i]
							}
						}
					}

					self.logger.debug("Received packet[\(i)]: dest=\(VZMACAddress(ethernetAddress: macAddress[0]).string), src=\(VZMACAddress(ethernetAddress: macAddress[1]).string), size=\(pd.vm_pkt_size)")
				}

				let byteBuffer = ByteBuffer(data: Data(bytesNoCopy: pd.vm_pkt_iov.pointee.iov_base, count: pd.vm_pkt_iov.pointee.iov_len, deallocator: .none))

				self.childrenChannels.forEach { channel in
					channel.writeAndFlush(byteBuffer, promise: nil)
				}
			}
		}

		self.logger.debug("estim_count=\(estim_count), dividing by MAX_PACKET_COUNT_AT_ONCE=\(MAX_PACKET_COUNT_AT_ONCE); q=\(q), r=\(r)")

		for _ in 0..<q {
			on_vmnet_packets_available(MAX_PACKET_COUNT_AT_ONCE)
		}

		if r > 0 {
			on_vmnet_packets_available(r)
		}
	}

	func startInterface() throws {
		let dict: xpc_object_t = xpc_dictionary_create(nil, nil, 0)
		let semaphore = DispatchSemaphore(value: 0)
		var status: vmnet_return_t = vmnet_return_t.VMNET_SUCCESS

		xpc_dictionary_set_uint64(dict, vmnet_operation_mode_key, self.mode.rawValue)

		if let interface = self.networkInterface {
			xpc_dictionary_set_string(dict, vmnet_shared_interface_name_key, interface)
		}

		if let gateway = self.gateway, let dhcpEnd = self.dhcpEnd {
			xpc_dictionary_set_string(dict, vmnet_start_address_key, gateway);
			xpc_dictionary_set_string(dict, vmnet_end_address_key, dhcpEnd);
			xpc_dictionary_set_string(dict, vmnet_subnet_mask_key, self.subnetMask);
		}

		xpc_dictionary_set_uuid(dict, vmnet_interface_id_key, self.interfaceID);

		if let nat66Prefix = self.nat66Prefix {
			xpc_dictionary_set_string(dict, vmnet_nat66_prefix_key, nat66Prefix);
		}

		self.iface = vmnet_start_interface(dict, self.hostQueue) { (result: vmnet_return_t, params) in
			status = result

			if let params = params, result == .VMNET_SUCCESS {
				self.print_vmnet_start_param(params: params);
				self.max_bytes = xpc_dictionary_get_uint64(params, vmnet_max_packet_size_key);
			}

			semaphore.signal()
		}

		semaphore.wait()

		if self.iface == nil {
			throw ServiceError("Failed to start interface \(status)")
		}

		if status != vmnet_return_t.VMNET_SUCCESS {
			throw ServiceError("Failed to start interface \(status)")
		}

		vmnet_interface_set_event_callback(iface!, .VMNET_INTERFACE_PACKETS_AVAILABLE, hostQueue) { eventId, event in
			let estim_count = xpc_dictionary_get_uint64(event, vmnet_estimated_packets_available_key)
			self.vmnetPacketAvailable(estim_count)
		}
	}

	func start() async throws {
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
			.childChannelOption(ChannelOptions.socketOption(.so_rcvbuf), value: 1024 * 1024)
			.childChannelOption(ChannelOptions.socketOption(.so_sndbuf), value: 1024 * 1024)
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
				self.logger.info("Console listening on \(self.socketPath)")
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

		self.serverChannel = try await binder.get()

		try await self.serverChannel!.closeFuture.get()
	}

	func stop() {
		let promise = self.eventLoop.makePromise(of: Void.self)

		if let serverChannel = self.serverChannel {
			EventLoopFuture.andAllComplete(self.childrenChannels.map { child in
				let promise: EventLoopPromise<Void> = child.eventLoop.makePromise()
				child.close(promise: promise)

				return promise.futureResult
			}, on: self.eventLoop).whenComplete { _ in
				self.childrenChannels.removeAll()
				serverChannel.close(mode: .all, promise: promise)
			}
		}

		try? promise.futureResult.wait()
	}
}
