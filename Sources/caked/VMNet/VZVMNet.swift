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
	let datagram: Bool
	let socketPath: String
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

	final class VMNetHandler: ChannelInboundHandler {
		typealias InboundIn = ByteBuffer
		typealias OutboundOut = ByteBuffer

		enum State {
			case idle
			case readingHeader
			case readingBody
		}

		private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
		private let vmnet: VZVMNet
		private var state: State = .idle
		private var header: Int32 = 0
		private var totalRead: Int32 = 0
		private var body: ByteBuffer = ByteBuffer()

		init(vmnet: VZVMNet) {
			self.vmnet = vmnet
		}

		public func channelActive(context: ChannelHandlerContext) {
			self.vmnet.childrenChannels.append(context.channel)
			self.state = .readingHeader
		}

		public func channelInactive(context: ChannelHandlerContext) {
			self.vmnet.childrenChannels.removeAll { $0 === context.channel }
			self.state = .idle
		}

		func channelRead(context: ChannelHandlerContext, data: NIOAny) {
			var buffer = self.unwrapInboundIn(data)

			if self.vmnet.datagram {
				var bufData = Data(buffer: buffer)

				channelsSyncQueue.async {
					var written_count: Int32 = bufData.count
					var pd: vmpktdesc = vmpktdesc(vm_pkt_size: Int(written_count), vm_pkt_iov: bufData.withUnsafeMutableBytes { $0.baseAddress! }, vm_pkt_iovcnt: 1, vm_flags: 0)

					guard vmnet_write(self.vmnet.iface!, &pd, &written_count) != .VMNET_SUCCESS else {
						Logger(self).error("Failed to write to interface")
						return
					}

					if written_count != header {
						Logger(self).error("Failed to write all bytes to interface")
					}

					self.vmnet.childrenChannels.forEach { channel in
						if channel !== currentChannel {
							channel.writeAndFlush(bufData, promise: nil)
						}
					}
				}

			} else if self.state == .readingHeader {
				if buffer.readableBytes >= 4 {
					self.header = buffer.readInteger(endianness: .big, as: Int32.self)!
					self.totalRead = 0
					self.body = context.channel.allocator.buffer(capacity: Int(self.header) + MemoryLayout<Int32>.size)
					self.state = .readingBody
					self.body.writeInteger(self.header, endianness: .big, as: Int32.self)
				}
			} else if self.state == .readingBody {
				if buffer.readableBytes > 0 {
					self.totalRead += Int32(self.body.writeBuffer(&buffer))

					if self.totalRead == self.header {
						self.body.moveReaderIndex(to: 0)

						var bufData = Data(buffer: self.body)
						let header = self.header
						let currentChannel = context.channel
						self.state = .readingHeader

						channelsSyncQueue.async {
							var written_count: Int32 = header
							var buf: iovec = iovec(iov_base: bufData.withUnsafeMutableBytes { $0.baseAddress! + MemoryLayout<Int32>.size}, iov_len: Int(written_count))
							var pd: vmpktdesc = vmpktdesc(vm_pkt_size: Int(self.header), vm_pkt_iov: withUnsafeMutablePointer(to: &buf, { $0 }), vm_pkt_iovcnt: 1, vm_flags: 0)

							guard vmnet_write(self.vmnet.iface!, &pd, &written_count) != .VMNET_SUCCESS else {
								Logger(self).error("Failed to write to interface")
								return
							}

							if written_count != header {
								Logger(self).error("Failed to write all bytes to interface")
							}

							self.vmnet.childrenChannels.forEach { channel in
								if channel !== currentChannel {
									channel.writeAndFlush(bufData, promise: nil)
								}
							}
						}
					}
				}
			}
		}

		func channelReadComplete(context: ChannelHandlerContext) {
			context.flush()
		}

		func errorCaught(context: ChannelHandlerContext, error: Error) {
			Logger(self).error("Error: \(error)")
		}
	}

	init(on: EventLoop, datagram: Bool, socketPath: String, socketGroup: gid_t, mode: VMNetMode, networkInterface: String? = nil, gateway: String? = nil, dhcpEnd: String?, subnetMask: String = "255.255.255.0", interfaceID: String = UUID().uuidString, nat66Prefix: String? = nil) {
		self.eventLoop = on
		self.datagram = datagram
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
			Logger(self).info("params not defined")
			return
		}

		xpc_dictionary_apply(params) { key, value in
			let t = xpc_get_type(value)
			let key = String(cString: key)

			if t == XPC_TYPE_UINT64 {
				Logger(self).info("\(key): \(xpc_dictionary_get_uint64(params, key))")
			} else if t == XPC_TYPE_INT64 {
				Logger(self).info("\(key): \(xpc_dictionary_get_int64(params, key))")
			} else if t == XPC_TYPE_STRING {
				if let cstr = xpc_string_get_string_ptr(value) {
					let value = String(cString: cstr)

					Logger(self).info("\(key): \(value)")
				}
			} else if t == XPC_TYPE_UUID {
				UnsafeMutablePointer<Int8>.allocate(capacity: 37).withMemoryRebound(to: UInt8.self, capacity: 37) { uuid in
					uuid_unparse(xpc_uuid_get_bytes(value), uuid)

					let value = String(cString: uuid)
					Logger(self).info("\(key): \(value)")
				}
			} else {
				Logger(self).info("\(key): \(t)")
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

	func vmnetPacketAvailableDatagram(_ estim_count: UInt64) {
		let q = estim_count / MAX_PACKET_COUNT_AT_ONCE;
		let r = estim_count % MAX_PACKET_COUNT_AT_ONCE;
		let on_vmnet_packets_available = { (count: UInt64) in
			let max_bytes = Int(self.max_bytes)
			var received_count: Int32 = Int32(count)
			var pdv: [vmpktdesc] = []

			pdv.reserveCapacity(Int(count))
			io.reserveCapacity(Int(count))

			for i in 0..<Int(count) {
				pdv.append(vmpktdesc(vm_pkt_size: max_bytes, vm_pkt_iov: UnsafeMutablePointer<UInt8>.allocate(capacity: Int(self.max_bytes)), vm_pkt_iovcnt: 1, vm_flags: 0))
			}

			defer {
				pdv.forEach {
					$0.vm_pkt_iov.deallocate()
				}
			}

			let status = vmnet_read(self.iface!, &pdv, &received_count)

			if status != .VMNET_SUCCESS {
				Logger(self).error("Failed to read from interface \(status)")
				return
			}

			for i in 0..<Int(received_count) {
				let pd: vmpktdesc = pdv[i]
				let macAddress = UnsafeRawPointer(pd.vm_pkt_iov).bindMemory(to: [ether_addr_t].self, capacity: 2).pointee

				Logger(self).debug("Received packet[\(i)]: dest=\(VZMACAddress(ethernetAddress: macAddress[0]).string), src=\(VZMACAddress(ethernetAddress: macAddress[1]).string), size=\(pd.vm_pkt_size)")

				let iovec1: iovec = iovec(iov_base: pd.vm_pkt_iov, iov_len: pd.vm_pkt_iov.pointee.iov_len)

				self.childrenChannels.forEach { channel in
					channel.writeAndFlush(iovec1, promise: nil)
				}
			}
		}

		Logger(self).debug("estim_count=\(estim_count), dividing by MAX_PACKET_COUNT_AT_ONCE=\(MAX_PACKET_COUNT_AT_ONCE); q=\(q), r=\(r)")

		for _ in 0..<q {
			on_vmnet_packets_available(MAX_PACKET_COUNT_AT_ONCE)
		}

		if r > 0 {
			on_vmnet_packets_available(r)
		}
	}

	func vmnetPacketAvailableStream(_ estim_count: UInt64) {
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
				io.append(iovec(iov_base: UnsafeMutablePointer<UInt8>.allocate(capacity: Int(self.max_bytes) + MemoryLayout<Int32>.size), iov_len: max_bytes))
				pdv.append(vmpktdesc(vm_pkt_size: max_bytes, vm_pkt_iov: withUnsafeMutablePointer(to: &io[i], { $0 + MemoryLayout<Int32>.size}), vm_pkt_iovcnt: 1, vm_flags: 0))
			}

			defer {
				io.forEach {
					$0.iov_base.deallocate()
				}
			}

			let status = vmnet_read(self.iface!, &pdv, &received_count)

			if status != .VMNET_SUCCESS {
				Logger(self).error("Failed to read from interface \(status)")
				return
			}

			for i in 0..<Int(received_count) {
				let iop = io[i]
				let pd: vmpktdesc = pdv[i]
				let macAddress = UnsafeRawPointer(iop.iov_base).bindMemory(to: [ether_addr_t].self, capacity: 2).pointee

				Logger(self).debug("Received packet[\(i)]: dest=\(VZMACAddress(ethernetAddress: macAddress[0]).string), src=\(VZMACAddress(ethernetAddress: macAddress[1]).string), size=\(pd.vm_pkt_size)")

				iop.iov_base.assumingMemoryBound(to: Int32.self).pointee = Int32(pdv[i].vm_pkt_size.bigEndian)

				let iovec1: iovec = iovec(iov_base: iop.iov_base, iov_len: pd.vm_pkt_iov.pointee.iov_len + MemoryLayout<Int32>.size)

				self.childrenChannels.forEach { channel in
					channel.writeAndFlush(iovec1, promise: nil)
				}
			}
		}

		Logger(self).debug("estim_count=\(estim_count), dividing by MAX_PACKET_COUNT_AT_ONCE=\(MAX_PACKET_COUNT_AT_ONCE); q=\(q), r=\(r)")

		for _ in 0..<q {
			on_vmnet_packets_available(MAX_PACKET_COUNT_AT_ONCE)
		}

		if r > 0 {
			on_vmnet_packets_available(r)
		}
	}

	func vmnetPacketAvailable(_ estim_count: UInt64) {
		if self.datagram {
			vmnetPacketAvailableDatagram(estim_count)
		} else {
			vmnetPacketAvailableStream(estim_count)
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

			Logger(self).info("Event: \(event), estim_count=\(estim_count)")

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
					Logger(self).error("Failed to stop interface \(status)")
				}
			}
		}

		let binder: EventLoopFuture<Channel>

		// Create the server bootstrap
		if self.datagram {
			let bootstrap: DatagramBootstrap = DatagramBootstrap(group: Root.group)
				.channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
				.channelOption(ChannelOptions.socketOption(.so_broadcast), value: 1)
				.channelOption(ChannelOptions.socketOption(.so_rcvbuf), value: 1024 * 1024)
				.channelOption(ChannelOptions.socketOption(.so_sndbuf), value: 1024 * 1024)
				.channelOption(.maxMessagesPerRead, value: 16)
				.channelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
				.channelInitializer { channel in
					return channel.pipeline.addHandler(VMNetHandler(vmnet: self))
				}

			// Listen on the console socket
			binder = bootstrap.bind(unixDomainSocketPath: socketPath, cleanupExistingSocketFile: true)
		} else {
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
		}

		if (chown(socketPath, getegid(), self.socketGroup) < 0) {
			throw ServiceError("Failed to set group \(self.socketGroup) on socket \(self.socketPath)")
		}

		if (chmod(socketPath, 0o0770) < 0) {
			throw ServiceError("Failed to set mod 770 on socket \(self.socketPath)")
		}

		// When the bind is complete, set the channel
		binder.whenComplete { result in
			switch result {
			case .success:
				Logger(self).info("Console listening on \(self.socketPath)")
			case let .failure(error):
				Logger(self).info("Failed to bind console on \(self.socketPath), \(error)")
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