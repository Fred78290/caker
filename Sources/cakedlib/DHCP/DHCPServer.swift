import CakeAgentLib
import Darwin
import Foundation
import NIOCore
import NIOPosix
import Synchronization

/// The protocol logic of the DHCP server of one network, with no socket in it: a request message in, the reply
/// message (if any) out. `DHCPServer` puts it on the wire.
public final class DHCPResponder: Sendable {
	public struct Configuration: Sendable {
		/// The gateway: server identifier, router and (for the compose resolver) DNS server.
		public let gateway: UInt32
		public let netmask: UInt32
		public let dnsServers: [UInt32]
		public let domainName: String?

		public init(gateway: UInt32, netmask: UInt32, dnsServers: [UInt32], domainName: String?) {
			self.gateway = gateway
			self.netmask = netmask
			self.dnsServers = dnsServers
			self.domainName = domainName
		}

		var broadcast: UInt32 {
			(gateway & netmask) | ~netmask
		}
	}

	public let configuration: Configuration
	public let store: DHCPLeaseStore
	private let logger = Logger("DHCPResponder")

	public init(configuration: Configuration, store: DHCPLeaseStore) {
		self.configuration = configuration
		self.store = store
	}

	public func respond(to request: DHCPMessage) -> DHCPMessage? {
		guard request.op == 1, request.hardwareType == 1, request.clientHardwareAddress.count == 6, let type = request.messageType else {
			return nil
		}

		let key = request.hwAddressKey

		switch type {
		case .discover:
			guard let address = self.store.offer(hwAddress: key, requested: request.requestedAddress) else {
				self.logger.warn("DHCP pool exhausted, no address for \(key)")
				return nil
			}

			self.logger.debug("DHCPOFFER \(DHCPAddress.string(address)) to \(key)")

			return self.reply(.offer, to: request, address: address)

		case .request:
			// The client picked another server's offer: forget ours.
			if let server = request.serverIdentifier, server != self.configuration.gateway {
				self.store.release(hwAddress: key)
				return nil
			}

			// SELECTING/INIT-REBOOT carry option 50, RENEWING/REBINDING carry ciaddr.
			guard let address = request.requestedAddress ?? (request.ciaddr != 0 ? request.ciaddr : nil) else {
				return nil
			}

			guard self.store.commit(hwAddress: key, address: address, hostname: request.hostname) else {
				self.logger.debug("DHCPNAK \(DHCPAddress.string(address)) to \(key)")
				return self.reply(.nak, to: request, address: 0, message: "requested address not available")
			}

			self.logger.debug("DHCPACK \(DHCPAddress.string(address)) to \(key)")

			return self.reply(.ack, to: request, address: address)

		case .release:
			self.store.release(hwAddress: key)
			return nil

		case .decline:
			if let address = request.requestedAddress {
				self.store.decline(hwAddress: key, address: address)
			}

			return nil

		default:
			return nil
		}
	}

	private func reply(_ type: DHCPMessage.MessageType, to request: DHCPMessage, address: UInt32, message: String? = nil) -> DHCPMessage {
		var reply = DHCPMessage(op: 2, hardwareType: request.hardwareType, xid: request.xid, flags: request.flags, ciaddr: type == .ack ? request.ciaddr : 0, yiaddr: address, siaddr: type == .nak ? 0 : self.configuration.gateway, giaddr: request.giaddr, clientHardwareAddress: request.clientHardwareAddress, messageType: type)

		reply.serverIdentifier = self.configuration.gateway
		reply.message = message

		if type != .nak {
			let lease = UInt32(min(self.store.leaseTime, Double(UInt32.max)))

			reply.leaseTime = lease
			reply.renewalTime = lease / 2
			reply.rebindingTime = UInt32(UInt64(lease) * 7 / 8)
			reply.subnetMask = self.configuration.netmask
			reply.broadcastAddress = self.configuration.broadcast
			reply.routers = [self.configuration.gateway]
			reply.dnsServers = self.configuration.dnsServers
			reply.domainName = self.configuration.domainName
		}

		return reply
	}
}

#if USE_DHCP_SERVER

public enum DHCPServerError: Error, CustomStringConvertible {
	case interfaceNotFound(String)
	case bpf(String)

	public var description: String {
		switch self {
		case .interfaceNotFound(let address):
			return "No network interface has the address \(address)"
		case .bpf(let reason):
			return "DHCP capture error: \(reason)"
		}
	}
}

/// Serves DHCP on the host interface (the bridge) of one network.
///
/// It does **not** bind UDP 67. macOS keeps a launchd-owned `*:67` socket (bootps) open, so a wildcard bind fails
/// with "Address already in use", and a socket bound to a specific address never receives what clients send before
/// they have an address (`255.255.255.255`). Instead the server reads the bridge through BPF (filter: IPv4/UDP to
/// port 67), which is what ISC dhcpd and dnsmasq do on BSD, and writes complete Ethernet frames back. Several
/// networks therefore run side by side, each only seeing its own bridge. Needs root for `/dev/bpf*`.
public final class DHCPServer: Sendable {
	private struct Running {
		let fd: Int32
		let source: DispatchSourceRead
	}

	private let responder: DHCPResponder
	private let running: Mutex<Running?> = Mutex(nil)
	private let logger = Logger("DHCPServer")

	/// The address (the network's gateway) assigned to the host interface the server is bound to.
	public let bindAddress: String

	/// `group` is unused, kept so callers don't depend on how the capture is scheduled.
	public init(group: EventLoopGroup, responder: DHCPResponder, bindAddress: String) {
		self.responder = responder
		self.bindAddress = bindAddress
	}

	/// The name of the host interface that carries `address`, `nil` while vmnet hasn't brought it up.
	public static func interfaceName(forIPv4 address: String) -> String? {
		var list: UnsafeMutablePointer<ifaddrs>?

		guard getifaddrs(&list) == 0, let first = list else {
			return nil
		}

		defer { freeifaddrs(list) }

		for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
			guard let sa = pointer.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }

			var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))

			if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0, String(cString: host) == address {
				return String(cString: pointer.pointee.ifa_name)
			}
		}

		return nil
	}

	/// The hardware address of the interface `name`.
	static func hardwareAddress(ofInterface name: String) -> [UInt8]? {
		var list: UnsafeMutablePointer<ifaddrs>?

		guard getifaddrs(&list) == 0, let first = list else {
			return nil
		}

		defer { freeifaddrs(list) }

		for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
			guard let sa = pointer.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_LINK), String(cString: pointer.pointee.ifa_name) == name else { continue }

			return sa.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { dl -> [UInt8]? in
				guard dl.pointee.sdl_alen == 6 else { return nil }

				return withUnsafePointer(to: &dl.pointee.sdl_data) { data in
					data.withMemoryRebound(to: UInt8.self, capacity: Int(dl.pointee.sdl_nlen) + 6) { bytes in
						Array(UnsafeBufferPointer(start: bytes + Int(dl.pointee.sdl_nlen), count: 6))
					}
				}
			}
		}

		return nil
	}

	// ioctl requests of <net/bpf.h>, which are function-like macros Swift can't import.
	private enum BPF {
		static let setBufferLength: UInt = 0xc004_4266  // BIOCSBLEN
		static let setFilter: UInt = 0x8010_4267  // BIOCSETF
		static let setInterface: UInt = 0x8020_426c  // BIOCSETIF
		static let immediate: UInt = 0x8004_4270  // BIOCIMMEDIATE
		static let headerComplete: UInt = 0x8004_4275  // BIOCSHDRCMPLT
		static let seeSent: UInt = 0x8004_4277  // BIOCSSEESENT
		static let getLinkType: UInt = 0x4004_426a  // BIOCGDLT
	}

	private struct Instruction {
		var code: UInt16
		var jt: UInt8
		var jf: UInt8
		var k: UInt32
	}

	/// Ethernet / IPv4 / not fragmented / UDP / destination port 67.
	private static let filter: [Instruction] = [
		Instruction(code: 0x28, jt: 0, jf: 0, k: 12),  // ldh [12]
		Instruction(code: 0x15, jt: 0, jf: 8, k: 0x0800),  // jeq #IPv4
		Instruction(code: 0x30, jt: 0, jf: 0, k: 23),  // ldb [23]
		Instruction(code: 0x15, jt: 0, jf: 6, k: 17),  // jeq #UDP
		Instruction(code: 0x28, jt: 0, jf: 0, k: 20),  // ldh [20]
		Instruction(code: 0x45, jt: 4, jf: 0, k: 0x1fff),  // jset #fragment
		Instruction(code: 0xb1, jt: 0, jf: 0, k: 14),  // ldxb 4*([14]&0xf)
		Instruction(code: 0x48, jt: 0, jf: 0, k: 16),  // ldh [x+16]
		Instruction(code: 0x15, jt: 0, jf: 1, k: 67),  // jeq #67
		Instruction(code: 0x06, jt: 0, jf: 0, k: 0x40000),  // accept
		Instruction(code: 0x06, jt: 0, jf: 0, k: 0),  // drop
	]

	private static func openBPF(interface name: String) throws -> (fd: Int32, bufferLength: Int) {
		var fd: Int32 = -1

		for index in 0..<256 {
			fd = open("/dev/bpf\(index)", O_RDWR)

			if fd >= 0 || errno != EBUSY {
				break
			}
		}

		guard fd >= 0 else {
			throw DHCPServerError.bpf("open /dev/bpf: \(String(cString: strerror(errno)))")
		}

		do {
			var length: UInt32 = 65536
			var request = ifreq()
			var one: UInt32 = 1
			var zero: UInt32 = 0
			var linkType: UInt32 = 0

			_ = ioctl(fd, BPF.setBufferLength, &length)

			withUnsafeMutableBytes(of: &request.ifr_name) { raw in
				name.utf8CString.withUnsafeBytes {
					raw.copyMemory(from: UnsafeRawBufferPointer(rebasing: $0.prefix(raw.count - 1)))
				}
			}

			guard ioctl(fd, BPF.setInterface, &request) == 0 else {
				throw DHCPServerError.bpf("BIOCSETIF \(name): \(String(cString: strerror(errno)))")
			}

			guard ioctl(fd, BPF.getLinkType, &linkType) == 0, linkType == 1 else {
				throw DHCPServerError.bpf("\(name) is not an Ethernet interface")
			}

			guard ioctl(fd, BPF.immediate, &one) == 0, ioctl(fd, BPF.headerComplete, &one) == 0, ioctl(fd, BPF.seeSent, &zero) == 0 else {
				throw DHCPServerError.bpf("ioctl: \(String(cString: strerror(errno)))")
			}

			var program = filter
			let installed = program.withUnsafeMutableBufferPointer { buffer -> Int32 in
				struct BpfProgram {
					var length: UInt32
					var instructions: UnsafeMutableRawPointer?
				}

				var value = BpfProgram(length: UInt32(buffer.count), instructions: UnsafeMutableRawPointer(buffer.baseAddress))

				return ioctl(fd, BPF.setFilter, &value)
			}

			guard installed == 0 else {
				throw DHCPServerError.bpf("BIOCSETF: \(String(cString: strerror(errno)))")
			}

			return (fd, Int(length))
		} catch {
			close(fd)
			throw error
		}
	}

	public func start() throws {
		guard let name = Self.interfaceName(forIPv4: self.bindAddress), let gateway = DHCPAddress.parse(self.bindAddress), let hardware = Self.hardwareAddress(ofInterface: name) else {
			throw DHCPServerError.interfaceNotFound(self.bindAddress)
		}

		let (fd, bufferLength) = try Self.openBPF(interface: name)
		let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: DispatchQueue(label: "com.aldunelabs.caker.dhcp.\(name)"))
		let responder = self.responder
		let logger = self.logger
		let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferLength, alignment: 8)

		source.setEventHandler {
			let count = read(fd, buffer, bufferLength)

			guard count > 0 else { return }

			var offset = 0

			// A read returns several `bpf_hdr`-prefixed frames, each aligned on 4 bytes.
			while offset + 18 <= count {
				let captured = Int(buffer.load(fromByteOffset: offset + 8, as: UInt32.self))
				let headerLength = Int(buffer.load(fromByteOffset: offset + 16, as: UInt16.self))

				guard headerLength >= 18, offset + headerLength + captured <= count else { break }

				let frame = Array(UnsafeRawBufferPointer(start: buffer + offset + headerLength, count: captured))

				if let answer = Self.answer(to: frame, responder: responder, serverMAC: hardware, gateway: gateway) {
					if write(fd, answer, answer.count) < 0 {
						logger.warn("DHCP write on \(name) failed: \(String(cString: strerror(errno)))")
					}
				}

				offset += (headerLength + captured + 3) & ~3
			}
		}

		source.setCancelHandler {
			buffer.deallocate()
			close(fd)
		}

		self.running.withLock { $0 = Running(fd: fd, source: source) }
		source.activate()
		self.logger.info("DHCP server for \(self.bindAddress) listening on \(name)")
	}

	/// The Ethernet frame to write back for a captured request frame, if the responder has an answer.
	static func answer(to frame: [UInt8], responder: DHCPResponder, serverMAC: [UInt8], gateway: UInt32) -> [UInt8]? {
		guard frame.count > 42, frame[12] == 0x08, frame[13] == 0x00 else { return nil }

		let headerLength = Int(frame[14] & 0x0f) * 4
		let payload = 14 + headerLength + 8

		guard headerLength >= 20, frame.count > payload, let request = try? DHCPMessage.parse(Array(frame[payload...])), let reply = responder.respond(to: request) else {
			return nil
		}

		// A client that has no address yet (or asks for it) gets a broadcast; a renewing one is answered directly.
		let direct = reply.messageType != .nak && request.ciaddr != 0 && request.wantsBroadcast == false
		let destinationMAC = direct ? request.clientHardwareAddress : [UInt8](repeating: 0xff, count: 6)
		let destinationIP: UInt32 = direct ? request.ciaddr : 0xffff_ffff

		return Self.frame(sourceMAC: serverMAC, destinationMAC: destinationMAC, sourceIP: gateway, destinationIP: destinationIP, payload: reply.encode())
	}

	/// Ethernet + IPv4 + UDP (`67` → `68`, checksum left to zero as UDP allows) around `payload`.
	static func frame(sourceMAC: [UInt8], destinationMAC: [UInt8], sourceIP: UInt32, destinationIP: UInt32, payload: [UInt8]) -> [UInt8] {
		func be16(_ value: Int) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xff)] }
		func be32(_ value: UInt32) -> [UInt8] { [UInt8(value >> 24), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)] }

		let udpLength = 8 + payload.count
		var ip: [UInt8] = [0x45, 0x10] + be16(20 + udpLength) + [0, 0, 0, 0, 64, 17, 0, 0] + be32(sourceIP) + be32(destinationIP)
		var sum: UInt32 = 0

		for index in stride(from: 0, to: ip.count, by: 2) {
			sum += UInt32(ip[index]) << 8 | UInt32(ip[index + 1])
		}

		while sum >> 16 != 0 { sum = (sum & 0xffff) + (sum >> 16) }

		ip[10] = UInt8(~sum >> 8 & 0xff)
		ip[11] = UInt8(~sum & 0xff)

		return destinationMAC + sourceMAC + [0x08, 0x00] + ip + be16(DHCPMessage.serverPort) + be16(DHCPMessage.clientPort) + be16(udpLength) + [0, 0] + payload
	}

	/// Retries until the gateway interface exists (vmnet brings it up lazily) or the task is cancelled.
	public func startWithRetry(retryDelayNanoseconds: UInt64 = 1_000_000_000) async throws {
		while true {
			try Task.checkCancellation()

			do {
				try self.start()
				return
			} catch DHCPServerError.interfaceNotFound {
				try await Task.sleep(nanoseconds: retryDelayNanoseconds)
			}
		}
	}

	public func shutdown() async {
		let running = self.running.withLock { value -> Running? in
			defer { value = nil }
			return value
		}

		running?.source.cancel()
	}
}

#endif
