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
	var serverChannel: Channel? = nil
	let eventLoop: EventLoop
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
	let pidFile: URL
	let sigint: any DispatchSourceSignal
	let sighup: any DispatchSourceSignal
	let sigterm: any DispatchSourceSignal
	let logger = Logger("com.aldunelabs.caked.VZVMNet")

	init(on: EventLoop, mode: VMNetMode, networkInterface: String? = nil, gateway: String? = nil, dhcpEnd: String?, subnetMask: String = "255.255.255.0", interfaceID: String = UUID().uuidString, nat66Prefix: String? = nil, pidFile: URL) {
		self.eventLoop = on
		self.mode = mode
		self.networkInterface = networkInterface
		self.gateway = gateway
		self.dhcpEnd = dhcpEnd
		self.subnetMask = subnetMask
		self.interfaceID = interfaceID
		self.nat66Prefix = nat66Prefix
		self.hostQueue = DispatchQueue(label: "com.aldunelabs.caker.vmnet.host", qos: .userInitiated)
		self.pidFile = pidFile

		signal(SIGINT, SIG_IGN)
		signal(SIGHUP, SIG_IGN)
		signal(SIGTERM, SIG_IGN)

		self.sigint = DispatchSource.makeSignalSource(signal: SIGINT)
		self.sighup = DispatchSource.makeSignalSource(signal: SIGHUP)
		self.sigterm = DispatchSource.makeSignalSource(signal: SIGTERM)
	}

	internal func print_vmnet_start_param(params: xpc_object_t?) {
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

				if Logger.Level() >= LogLevel.debug {
					let numberOfItems = 2
					let macAddress = iov.iov_base.withMemoryRebound(to: ether_addr_t.self, capacity: numberOfItems)  { typedPtr in
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

				self.write(data: Data(bytesNoCopy: iov.iov_base, count: pd.vm_pkt_size, deallocator: .none))
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
		xpc_dictionary_set_bool(dict, vmnet_enable_tso_key, false)
		xpc_dictionary_set_bool(dict, vmnet_enable_checksum_offload_key, false)
		xpc_dictionary_set_bool(dict, vmnet_enable_isolation_key, false)

		xpc_dictionary_set_uuid(dict, vmnet_interface_id_key, self.interfaceID);

		if self.mode == .bridged {
			if let interface = self.networkInterface {
				xpc_dictionary_set_string(dict, vmnet_shared_interface_name_key, interface)
			}
		} else if self.mode == .shared {
			if let gateway = self.gateway, let dhcpEnd = self.dhcpEnd {
				xpc_dictionary_set_string(dict, vmnet_start_address_key, gateway);
				xpc_dictionary_set_string(dict, vmnet_end_address_key, dhcpEnd);
				xpc_dictionary_set_string(dict, vmnet_subnet_mask_key, self.subnetMask);
			}

			if let nat66Prefix = self.nat66Prefix {
				xpc_dictionary_set_string(dict, vmnet_nat66_prefix_key, nat66Prefix);
			}
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
			throw ServiceError("Failed to start interface \(status.stringValue)")
		}

		if status != vmnet_return_t.VMNET_SUCCESS {
			throw ServiceError("Failed to start interface \(status.stringValue)")
		}

		vmnet_interface_set_event_callback(iface!, .VMNET_INTERFACE_PACKETS_AVAILABLE, hostQueue) { eventId, event in
			let estim_count = xpc_dictionary_get_uint64(event, vmnet_estimated_packets_available_key)
			self.vmnetPacketAvailable(estim_count)
		}
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
