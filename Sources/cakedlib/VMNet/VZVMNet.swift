import CakeAgentLib
import Darwin
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore
import Virtualization
import vmnet

let MAX_PACKET_COUNT_AT_ONCE: UInt64 = 32

public protocol VZVMNet {
	func reconfigure(networkConfig: VZSharedNetwork) throws
	func start() throws
	func stop()
	func restart()
}

extension vmnet_return_t {
	public var description: String {
		switch self
		{
		case .VMNET_SUCCESS:
			return String(localized: "Success")
		case .VMNET_FAILURE:
			return String(localized: "Failure")
		case .VMNET_MEM_FAILURE:
			return String(localized: "Memory failure")
		case .VMNET_INVALID_ARGUMENT:
			return String(localized: "Invalid argument")
		case .VMNET_SETUP_INCOMPLETE:
			return String(localized: "Setup incomplete")
		case .VMNET_INVALID_ACCESS:
			return String(localized: "Invalid access")
		case .VMNET_PACKET_TOO_BIG:
			return String(localized: "Packet too big")
		case .VMNET_BUFFER_EXHAUSTED:
			return String(localized: "Buffer exhausted")
		case .VMNET_TOO_MANY_PACKETS:
			return String(localized: "To many packets")
		case .VMNET_SHARING_SERVICE_BUSY:
			return String(localized: "Service is busy")
		case .VMNET_NOT_AUTHORIZED:
			return String(localized: "Not authorized")
		default:
			return String(localized: "(unknown status \(self.rawValue))")
		}
	}

	public var stringValue: String {
		switch self
		{
		case .VMNET_SUCCESS:
			return "VMNET_SUCCESS"
		case .VMNET_FAILURE:
			return "VMNET_FAILURE"
		case .VMNET_MEM_FAILURE:
			return "VMNET_MEM_FAILURE"
		case .VMNET_INVALID_ARGUMENT:
			return "VMNET_INVALID_ARGUMENT"
		case .VMNET_SETUP_INCOMPLETE:
			return "VMNET_SETUP_INCOMPLETE"
		case .VMNET_INVALID_ACCESS:
			return "VMNET_INVALID_ACCESS"
		case .VMNET_PACKET_TOO_BIG:
			return "VMNET_PACKET_TOO_BIG"
		case .VMNET_BUFFER_EXHAUSTED:
			return "VMNET_BUFFER_EXHAUSTED"
		case .VMNET_TOO_MANY_PACKETS:
			return "VMNET_TOO_MANY_PACKETS"
		case .VMNET_SHARING_SERVICE_BUSY:
			return "VMNET_SHARING_SERVICE_BUSY"
		case .VMNET_NOT_AUTHORIZED:
			return "VMNET_NOT_AUTHORIZED"
		default:
			return "(unknown status \(self))"
		}
	}
}

public class VZVMNetCommon: NSObject, @unchecked Sendable, VZVMNet {
	private class GRPCVMNetService: Vmnet_VMNetServiceAsyncProvider, @unchecked Sendable {
		let owner: VZVMNetCommon

		init(owner: VZVMNetCommon) {
			self.owner = owner
		}

		func getSerialization(request: Vmnet_Empty, context: GRPCAsyncServerCallContext) async throws -> Vmnet_SerializationReply {
			owner.logger.debug("VMNet \(owner.networkName) replying to serialization request")

			let serialization = owner.serializationLock.withLock { owner.serialization }

			guard let serialization else {
				return Vmnet_SerializationReply.with {
					$0.success = false
					$0.reason = "VMNet serialization not available"
				}
			}

			do {
				let data = try encodeXPCObject(serialization)
				return Vmnet_SerializationReply.with {
					$0.data = data
					$0.success = true
				}
			} catch {
				return Vmnet_SerializationReply.with {
					$0.success = false
					$0.reason = error.localizedDescription
				}
			}
		}

		func stop(request: Vmnet_Empty, context: GRPC.GRPCAsyncServerCallContext) async throws -> Vmnet_Empty {
			self.owner.stop()
			return Vmnet_Empty()
		}

		func restart(request: Vmnet_Empty, context: GRPC.GRPCAsyncServerCallContext) async throws -> Vmnet_Empty {
			return Vmnet_Empty()
		}
	}

	private var grpcServer: Server? = nil
	private let semaphore = AsyncSemaphore(value: 0)
	private let sigcaught: [Int32: DispatchSourceSignal]

	internal let eventLoop: EventLoop
	internal let networkName: String
	internal var networkConfig: VZSharedNetwork
	internal let logger = Logger("VZVMNetImpl")
	internal let socketPath: URL
	internal let pidFile: URL
	internal let serializationLock = NSLock()
	internal var serialization: xpc_object_t? = nil
	internal let runMode: Utils.RunMode
	internal let trace: Bool
	internal let socketGroup: gid_t

	private func setupSignals() {
		sigcaught.forEach { sig in
			sig.value.setEventHandler {
				if sig.key == SIGUSR2 {
					self.logger.info("Signal caught restarting VMNet")
					self.restart()
				} else {
					self.logger.info("Signal caught [\(sig.key)], stopping VMNet")
					self.stop()
				}
			}
			sig.value.activate()
		}
	}

	public init(on: EventLoop, socketGroup: gid_t, networkName: String, networkConfig: VZSharedNetwork, socketPath: URL, pidFile: URL, runMode: Utils.RunMode) {
		self.eventLoop = on
		self.networkName = networkName
		self.networkConfig = networkConfig
		self.pidFile = pidFile
		self.socketPath = socketPath
		self.runMode = runMode
		self.trace = Logger.Level() >= Logger.LogLevel.trace
		self.socketGroup = socketGroup

		self.sigcaught = Dictionary(
			uniqueKeysWithValues: [SIGINT, SIGHUP, SIGQUIT, SIGTERM, SIGUSR2].map { sig in
				signal(sig, SIG_IGN)
				return (sig, DispatchSource.makeSignalSource(signal: sig))
			})
	}

	public func reconfigure(networkConfig: VZSharedNetwork) throws {
		self.networkConfig = networkConfig
	}

	public func start() throws {
		guard self.grpcServer == nil else {
			throw ServiceError(String(localized: "VMNet \(self.networkName) is already running"))
		}

		setupSignals()

		let serviceProvider = GRPCVMNetService(owner: self)
		let socketFile = socketPath.deletingLastPathComponent().appendingPathComponent("ctrl").path(percentEncoded: false)

		try? FileManager.default.removeItem(atPath: socketFile)

		let certLocation = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		var serverConfiguration = Server.Configuration.default(
			target: .unixDomainSocket(socketFile),
			eventLoopGroup: eventLoop,
			serviceProviders: [serviceProvider])

		serverConfiguration.tlsConfiguration = try GRPCTLSConfiguration.makeServerConfiguration(
			caCert: certLocation.caCertURL.path,
			tlsKey: certLocation.serverKeyURL.path,
			tlsCert: certLocation.serverCertURL.path)

		let server = try Server.start(configuration: serverConfiguration).wait()
		self.grpcServer = server

		if chown(socketFile, getegid(), self.socketGroup) < 0 {
			self.logger.error("Failed to set group \(self.socketGroup) on socket \(socketPath), reason: \(String(cString: strerror(errno)))")
		}

		let future = self.eventLoop.makeFutureWithTask {
			self.logger.info("VMNet \(self.networkName) started on \(socketFile)")
			try self.pidFile.writePID()

			do {
				try await self.semaphore.waitUnlessCancelled()
			} catch {
				Logger(self).error("Error: \(error)")
			}

			self.logger.info("VMNet \(self.networkName) stopped")
		}

		try future.wait()
	}

	public func stop() {
		guard let server = grpcServer else {
			self.logger.info(String(localized: "VMNet \(self.networkName) is not running"))
			return
		}

		self.logger.info(String(localized: "VMNet \(self.networkName) stop network"))

		self.grpcServer = nil
		serializationLock.withLock {
			self.serialization = nil
		}

		try? server.close().wait()
		self.semaphore.signal()

		try? pidFile.delete()
	}

	public func restart() {
		try? self.reconfigure(networkConfig: self.networkConfig)
	}
}

public class VZVMNetImpl: VZVMNetCommon, @unchecked Sendable {
	internal var serverChannel: Channel? = nil
	internal var iface: interface_ref?
	internal var max_bytes: UInt64 = 2048
	internal let hostQueue: DispatchQueue

	class VZVMNetHandler: ChannelInboundHandler {
		public typealias InboundIn = ByteBuffer
		public typealias OutboundOut = ByteBuffer

		internal let logger: Logger
		internal let trace: Bool = Logger.Level() >= Logger.LogLevel.trace
		internal let vzvmnet: VZVMNetImpl

		init(vzvmnet: VZVMNetImpl) {
			self.vzvmnet = vzvmnet
			self.logger = Logger(Self.self)
		}

		public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
			var buffer = self.unwrapInboundIn(data)
			let bufSize = buffer.readableBytes
			let iface = self.vzvmnet.iface!

			buffer.withUnsafeMutableReadableBytes {
				var count: Int32 = 1
				var buf: iovec = iovec(iov_base: $0.baseAddress!, iov_len: Int(bufSize))

				withUnsafeMutablePointer(
					to: &buf,
					{
						var pd: vmpktdesc = vmpktdesc(vm_pkt_size: $0.pointee.iov_len, vm_pkt_iov: $0, vm_pkt_iovcnt: 1, vm_flags: 0)
						let status = vmnet_write(iface, &pd, &count)

						guard status == .VMNET_SUCCESS else {
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

	public override init(on: EventLoop, socketGroup: gid_t, networkName: String, networkConfig: VZSharedNetwork, socketPath: URL, pidFile: URL, runMode: Utils.RunMode) {
		self.hostQueue = DispatchQueue(label: "com.aldunelabs.caker.vmnet.\(networkName)", qos: .userInitiated)

		super.init(on: on, socketGroup: socketGroup, networkName: networkName, networkConfig: networkConfig, socketPath: socketPath, pidFile: pidFile, runMode: runMode)
	}

	public override func reconfigure(networkConfig: VZSharedNetwork) throws {
		self.logger.debug("Reconfiguring VMNet with new parameters")

		try super.reconfigure(networkConfig: networkConfig)

		if self.iface != nil {
			self.stopInterface()
		}

		try self.setupInterface()
	}

	internal func print_vmnet_start_param(params: xpc_object_t?, info: String = "settings") {
		guard let params = params else {
			self.logger.debug("params not defined")
			return
		}

		xpc_dictionary_apply(params) { key, value in
			#if DEBUG
				let t = xpc_get_type(value)
				let key = String(cString: key)

				if t == XPC_TYPE_UINT64 {
					self.logger.debug("\(info) \(key): \(xpc_dictionary_get_uint64(params, key))")
				} else if t == XPC_TYPE_INT64 {
					self.logger.debug("\(info) \(key): \(xpc_dictionary_get_int64(params, key))")
				} else if t == XPC_TYPE_DOUBLE {
					self.logger.debug("\(info) \(key): \(xpc_dictionary_get_double(params, key))")
				} else if t == XPC_TYPE_DATE {
					self.logger.debug("\(info) \(key): \(xpc_dictionary_get_date(params, key))")
				} else if t == XPC_TYPE_BOOL {
					self.logger.debug("\(info) \(key): \(xpc_dictionary_get_bool(params, key))")
				} else if t == XPC_TYPE_STRING {
					if let cstr = xpc_string_get_string_ptr(value) {
						let value = String(cString: cstr)

						self.logger.debug("\(info) \(key): \(value)")
					}
				} else if t == XPC_TYPE_UUID {
					UnsafeMutablePointer<Int8>.allocate(capacity: 37).withMemoryRebound(to: UInt8.self, capacity: 37) { uuid in
						uuid_unparse(xpc_uuid_get_bytes(value), uuid)

						let value = String(cString: uuid)
						self.logger.debug("\(info) \(key): \(value)")
					}
				} else {
					self.logger.debug("\(info) \(key): \(t)")
				}
			#endif
			return true
		}
	}

	internal func traceMacAddress(_ i: Int, ptr: UnsafeMutableRawPointer, size: Int, direction: String = "received from host") {
		if self.trace {
			let numberOfItems = 2
			let macAddress = ptr.withMemoryRebound(to: ether_addr_t.self, capacity: numberOfItems) { typedPtr in
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

			#if DEBUG
				self.logger.debug("\(direction) packet[\(i)]: dest=\(VZMACAddress(ethernetAddress: macAddress[0]).string), src=\(VZMACAddress(ethernetAddress: macAddress[1]).string), size=\(size)")
			#endif
		}
	}

	internal func vmnetPacketAvailable(_ estim_count: UInt64) {
		let q = estim_count / MAX_PACKET_COUNT_AT_ONCE
		let r = estim_count % MAX_PACKET_COUNT_AT_ONCE

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

	public func setupInterface() throws {
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
			xpc_dictionary_set_uuid(dict, vmnet_interface_id_key, self.networkConfig.interfaceID)

			xpc_dictionary_set_string(dict, vmnet_start_address_key, self.networkConfig.dhcpStart)
			xpc_dictionary_set_string(dict, vmnet_end_address_key, self.networkConfig.dhcpEnd)
			xpc_dictionary_set_string(dict, vmnet_subnet_mask_key, self.networkConfig.netmask)

			if let nat66Prefix = self.networkConfig.nat66Prefix {
				xpc_dictionary_set_string(dict, vmnet_nat66_prefix_key, nat66Prefix)
			}
		} else {
			var dhcpStart = networkConfig.dhcpStart.toIPV4().address!

			dhcpStart.storage += 1

			xpc_dictionary_set_string(dict, vmnet_start_address_key, dhcpStart.description)
			xpc_dictionary_set_string(dict, vmnet_end_address_key, self.networkConfig.dhcpEnd)
			xpc_dictionary_set_string(dict, vmnet_subnet_mask_key, self.networkConfig.netmask)

			xpc_dictionary_set_bool(dict, vmnet_enable_isolation_key, true)

			xpc_dictionary_set_string(dict, vmnet_host_ip_address_key, self.networkConfig.dhcpStart)
			xpc_dictionary_set_string(dict, vmnet_host_subnet_mask_key, self.networkConfig.netmask)
			xpc_dictionary_set_string(dict, vmnet_network_identifier_key, self.networkConfig.interfaceID)
		}

		self.print_vmnet_start_param(params: dict, info: "setup")

		self.iface = vmnet_start_interface(dict, self.hostQueue) { (result: vmnet_return_t, params) in
			status = result

			if let params = params, result == .VMNET_SUCCESS {
				self.print_vmnet_start_param(params: params)
				self.max_bytes = xpc_dictionary_get_uint64(params, vmnet_max_packet_size_key)
			}

			semaphore.signal()
		}

		semaphore.wait()

		if self.iface == nil {
			throw ServiceError(String(localized: "Failed to start interface \(status.stringValue)"))
		}

		if status != vmnet_return_t.VMNET_SUCCESS {
			self.iface = nil
			throw ServiceError(String(localized: "Failed to start interface \(status.stringValue)"))
		}

		vmnet_interface_set_event_callback(iface!, .VMNET_INTERFACE_PACKETS_AVAILABLE, hostQueue) { eventId, event in
			let estim_count = xpc_dictionary_get_uint64(event, vmnet_estimated_packets_available_key)
			self.vmnetPacketAvailable(estim_count)
		}
	}

	public func stopInterface() {
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

	public func startInterface() throws {
		try setupInterface()
	}

	public func write(data: Data) {
	}
}
