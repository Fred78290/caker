import Foundation
import NIO
import vmnet
import Darwin
import Virtualization

let MAX_PACKET_COUNT_AT_ONCE: UInt64 = 32

extension vmnet_return_t {
	var stringValue: String {
		switch (self)
		{
		case .VMNET_SUCCESS:
			return "VMNET_SUCCESS";
		case .VMNET_FAILURE:
			return "VMNET_FAILURE";
		case .VMNET_MEM_FAILURE:
			return "VMNET_MEM_FAILURE";
		case .VMNET_INVALID_ARGUMENT:
			return "VMNET_INVALID_ARGUMENT";
		case .VMNET_SETUP_INCOMPLETE:
			return "VMNET_SETUP_INCOMPLETE";
		case .VMNET_INVALID_ACCESS:
			return "VMNET_INVALID_ACCESS";
		case .VMNET_PACKET_TOO_BIG:
			return "VMNET_PACKET_TOO_BIG";
		case .VMNET_BUFFER_EXHAUSTED:
			return "VMNET_BUFFER_EXHAUSTED";
		case .VMNET_TOO_MANY_PACKETS:
			return "VMNET_TOO_MANY_PACKETS";
		default:
			return "(unknown status)";
		}
	}
}

class VZVMNet: @unchecked Sendable {
	internal var serverChannel: Channel? = nil
	internal let eventLoop: EventLoop
	internal let networkName: String
	internal var networkConfig: VZSharedNetwork
	internal var iface: interface_ref?
	internal var max_bytes: UInt64 = 2048
	internal let hostQueue: DispatchQueue
	internal let pidFile: URL
	internal let sigcaught: [DispatchSourceSignal]
	internal let logger = Logger("VZVMNet")
	internal let trace: Bool

	class VZVMNetHandler: ChannelInboundHandler {
		public typealias InboundIn = ByteBuffer
		public typealias OutboundOut = ByteBuffer

		internal let logger: Logger
		internal let trace: Bool = Logger.Level() >= LogLevel.trace
		internal let vzvmnet: VZVMNet

		init(vzvmnet: VZVMNet) {
			self.vzvmnet = vzvmnet
			self.logger = Logger(Self.self)
		}

		public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
			var buffer = self.unwrapInboundIn(data)
			let bufSize = buffer.readableBytes
			let iface = self.vzvmnet.iface!

			buffer.withUnsafeMutableReadableBytes { 
				var count: Int32 = 1
				var buf: iovec = iovec(iov_base:  $0.baseAddress!, iov_len: Int(bufSize))

				withUnsafeMutablePointer(to: &buf, {
					var pd: vmpktdesc = vmpktdesc(vm_pkt_size: $0.pointee.iov_len, vm_pkt_iov: $0, vm_pkt_iovcnt: 1, vm_flags: 0)
					let status = vmnet_write(iface, &pd, &count)

					guard  status == .VMNET_SUCCESS else {
						self.logger.error("Failed to write to interface \(status.stringValue)")
						return
					}

					if self.trace {
						self.vzvmnet.traceMacAddress(0, ptr: $0, size: pd.vm_pkt_size, direction: "received from guest")

						if count != 1 {
							self.logger.error("Failed to write all bytes to interface = written_count: \(pd.vm_pkt_size), bufData.count: \(bufSize)")
						} else {
							self.logger.trace("Wrote \(pd.vm_pkt_size) bytes to interface")
						}
					}
				})
			}

			self.forwardBuffer(buffer: buffer, context: context)
		}

		func channelReadComplete(context: ChannelHandlerContext) {
			context.flush()
		}

		func errorCaught(context: ChannelHandlerContext, error: Error) {
			self.logger.error("Error: \(error)")
		}

		func forwardBuffer(buffer: ByteBuffer, context: ChannelHandlerContext) {

		}
	}

	init(on: EventLoop, networkName: String, networkConfig: VZSharedNetwork, pidFile: URL) {
		self.eventLoop = on
		self.networkName = networkName
		self.networkConfig = networkConfig
		self.hostQueue = DispatchQueue(label: "com.aldunelabs.caker.vmnet.host", qos: .userInitiated)
		self.pidFile = pidFile
		self.trace = Logger.Level() >= LogLevel.trace
		self.sigcaught = [ SIGINT, SIGHUP, SIGQUIT, SIGTERM ].map {
			signal($0, SIG_IGN)

			return DispatchSource.makeSignalSource(signal: $0)
		}
	}

	func reconfigure(networkConfig: VZSharedNetwork) throws {
		self.logger.info("Reconfiguring VMNet with new parameters")

		self.networkConfig = networkConfig

		if self.iface != nil {
			self.stopInterface()
		}

		try self.setupInterface()
	}

	internal func print_vmnet_start_param(params: xpc_object_t?, info: String = "settings") {
		guard let params = params else {
			self.logger.info("params not defined")
			return
		}

		xpc_dictionary_apply(params) { key, value in
			let t = xpc_get_type(value)
			let key = String(cString: key)

			if t == XPC_TYPE_UINT64 {
				self.logger.info("\(info) \(key): \(xpc_dictionary_get_uint64(params, key))")
			} else if t == XPC_TYPE_INT64 {
				self.logger.info("\(info) \(key): \(xpc_dictionary_get_int64(params, key))")
			} else if t == XPC_TYPE_DOUBLE {
				self.logger.info("\(info) \(key): \(xpc_dictionary_get_double(params, key))")
			} else if t == XPC_TYPE_DATE {
				self.logger.info("\(info) \(key): \(xpc_dictionary_get_date(params, key))")
			} else if t == XPC_TYPE_BOOL {
				self.logger.info("\(info) \(key): \(xpc_dictionary_get_bool(params, key))")
			} else if t == XPC_TYPE_STRING {
				if let cstr = xpc_string_get_string_ptr(value) {
					let value = String(cString: cstr)

					self.logger.info("\(info) \(key): \(value)")
				}
			} else if t == XPC_TYPE_UUID {
				UnsafeMutablePointer<Int8>.allocate(capacity: 37).withMemoryRebound(to: UInt8.self, capacity: 37) { uuid in
					uuid_unparse(xpc_uuid_get_bytes(value), uuid)

					let value = String(cString: uuid)
					self.logger.info("\(info) \(key): \(value)")
				}
			} else {
				self.logger.info("\(info) \(key): \(t)")
			}

			return true
		}
	}

	private func setupSignals() {
		sigcaught.forEach { sig in
			sig.setEventHandler {
				self.logger.info("Signal caught, stopping VMNet")
				self.stop()
			}

			sig.activate()
		}
	}

	internal func traceMacAddress(_ i: Int, ptr: UnsafeMutableRawPointer, size: Int, direction: String = "received from host") {
		if self.trace {
			let numberOfItems = 2
			let macAddress = ptr.withMemoryRebound(to: ether_addr_t.self, capacity: numberOfItems)  { typedPtr in
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

			self.logger.debug("\(direction) packet[\(i)]: dest=\(VZMACAddress(ethernetAddress: macAddress[0]).string), src=\(VZMACAddress(ethernetAddress: macAddress[1]).string), size=\(size)")
		}
	}

	internal func vmnetPacketAvailable(_ estim_count: UInt64) {
		let q = estim_count / MAX_PACKET_COUNT_AT_ONCE;
		let r = estim_count % MAX_PACKET_COUNT_AT_ONCE;

		let on_vmnet_packets_available = { (count: UInt64) in
			let max_bytes = Int(self.max_bytes)
			var received_count: Int32 = Int32(count)
			var pdv: [vmpktdesc] = []

			pdv.reserveCapacity(Int(count))

			for _ in 0..<Int(count) {
				let p = UnsafeMutablePointer<UInt8>.allocate(capacity: max_bytes)
				let iov = UnsafeMutablePointer<iovec>.allocate(capacity: 1)

				iov.pointee.iov_base = UnsafeMutableRawPointer(p)
				iov.pointee.iov_len = max_bytes

				pdv.append(vmpktdesc(vm_pkt_size: max_bytes, vm_pkt_iov: iov, vm_pkt_iovcnt: 1, vm_flags: 0))
			}

			defer {
				pdv.forEach {
					$0.vm_pkt_iov.pointee.iov_base.deallocate()
					$0.vm_pkt_iov.deallocate()
				}
			}

			let status = vmnet_read(self.iface!, &pdv, &received_count)

			if status != .VMNET_SUCCESS {
				self.logger.error("Failed to read from interface \(status.stringValue)")
				return
			}

			for i in 0..<Int(received_count) {
				let pd: vmpktdesc = pdv[i]
				let iov = pd.vm_pkt_iov.pointee

				self.traceMacAddress(i, ptr: iov.iov_base, size: pd.vm_pkt_size)
				self.write(data: Data(bytesNoCopy: iov.iov_base, count: pd.vm_pkt_size, deallocator: .none))
			}
		}

		if self.trace {
			self.logger.trace("estim_count=\(estim_count), dividing by MAX_PACKET_COUNT_AT_ONCE=\(MAX_PACKET_COUNT_AT_ONCE); q=\(q), r=\(r)")
		}

		for _ in 0..<q {
			on_vmnet_packets_available(MAX_PACKET_COUNT_AT_ONCE)
		}

		if r > 0 {
			on_vmnet_packets_available(r)
		}
	}

	func setupInterface() throws {
		let dict: xpc_object_t = xpc_dictionary_create(nil, nil, 0)
		let semaphore = DispatchSemaphore(value: 0)
		var status: vmnet_return_t = vmnet_return_t.VMNET_SUCCESS

		xpc_dictionary_set_uint64(dict, vmnet_operation_mode_key, self.networkConfig.mode.integerValue)
		xpc_dictionary_set_bool(dict, vmnet_enable_tso_key, false)
		xpc_dictionary_set_bool(dict, vmnet_enable_checksum_offload_key, false)
		xpc_dictionary_set_bool(dict, vmnet_enable_isolation_key, false)

		xpc_dictionary_set_bool(dict, vmnet_allocate_mac_address_key, false)
		//xpc_dictionary_set_string(dict, vmnet_mac_address_key, self.networkConfig.macAddress)

		if self.networkConfig.mode == .bridged {
			xpc_dictionary_set_string(dict, vmnet_shared_interface_name_key, self.networkName)
		} else if self.networkConfig.mode == .shared {
			xpc_dictionary_set_uuid(dict, vmnet_interface_id_key, self.networkConfig.interfaceID);

			xpc_dictionary_set_string(dict, vmnet_start_address_key, self.networkConfig.dhcpStart);
			xpc_dictionary_set_string(dict, vmnet_end_address_key, self.networkConfig.dhcpEnd);
			xpc_dictionary_set_string(dict, vmnet_subnet_mask_key, self.networkConfig.netmask);

			if let nat66Prefix = self.networkConfig.nat66Prefix {
				xpc_dictionary_set_string(dict, vmnet_nat66_prefix_key, nat66Prefix);
			}
		} else {
			xpc_dictionary_set_string(dict, vmnet_start_address_key, self.networkConfig.dhcpStart);
			xpc_dictionary_set_string(dict, vmnet_end_address_key, self.networkConfig.dhcpEnd);
			xpc_dictionary_set_string(dict, vmnet_subnet_mask_key, self.networkConfig.netmask);

			xpc_dictionary_set_bool(dict, vmnet_enable_isolation_key, true)

			xpc_dictionary_set_string(dict, vmnet_host_ip_address_key, self.networkConfig.dhcpStart);
			xpc_dictionary_set_string(dict, vmnet_host_subnet_mask_key, self.networkConfig.netmask);
			xpc_dictionary_set_string(dict, vmnet_network_identifier_key, self.networkConfig.interfaceID);
		}

		self.print_vmnet_start_param(params: dict, info: "setup");

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
			throw ServiceError("Failed to start interface \(status.stringValue)")
		}

		if status != vmnet_return_t.VMNET_SUCCESS {
			self.iface = nil
			throw ServiceError("Failed to start interface \(status.stringValue)")
		}

		vmnet_interface_set_event_callback(iface!, .VMNET_INTERFACE_PACKETS_AVAILABLE, hostQueue) { eventId, event in
			let estim_count = xpc_dictionary_get_uint64(event, vmnet_estimated_packets_available_key)
			self.vmnetPacketAvailable(estim_count)
		}
	}

	func stopInterface() {
		if let iface = self.iface {
			let semaphore = DispatchSemaphore(value: 0)
			let status = vmnet_stop_interface(iface, hostQueue) { status in
				semaphore.signal()
			}

			semaphore.wait()

			if status != .VMNET_SUCCESS {
				self.logger.error("Failed to stop interface \(status.stringValue)")
			}

			self.iface = nil
		}
	}

	func startInterface() throws {
		try setupInterface()
		setupSignals()
	}

	func write(data: Data) {
	}

	func stop() {
		try? pidFile.delete()
	}

	func start() throws {
		try self.pidFile.writePID()
	}
}
