//
//  DHCPVmnetIntegrationTests.swift
//  CakerTests
//
//  Opt-in: needs root and creates real vmnet networks (vmnet's own DHCP and DNS proxy disabled), with a vmnet
//  interface standing in for a guest.
//
//    swift build --build-tests
//    sudo env CAKER_DHCP_VMNET_TEST=1 swift test --skip-build --filter DHCPVmnetIntegrationTests
//

import Darwin
import Foundation
import NIOCore
import NIOPosix
import XCTest
import vmnet

@testable import CakedLib
@testable import caked

@available(macOS 26.0, *)
final class DHCPVmnetIntegrationTests: XCTestCase {
	private let queue = DispatchQueue(label: "dhcp.vmnet.test")

	private func inAddr(_ string: String) -> in_addr {
		var address = in_addr()

		inet_pton(AF_INET, string, &address)

		return address
	}

	private final class Guest {
		let network: vmnet_network_ref
		var iface: interface_ref?
		var mac: [UInt8] = []

		init(network: vmnet_network_ref) {
			self.network = network
		}

		func start(queue: DispatchQueue) throws {
			let description = xpc_dictionary_create(nil, nil, 0)
			let semaphore = DispatchSemaphore(value: 0)
			var status = vmnet_return_t.VMNET_SUCCESS

			xpc_dictionary_set_bool(description, vmnet_allocate_mac_address_key, true)

			self.iface = vmnet_interface_start_with_network(self.network, description, queue) { result, parameters in
				status = result

				if let parameters, result == .VMNET_SUCCESS, let text = xpc_dictionary_get_string(parameters, vmnet_mac_address_key) {
					self.mac = String(cString: text).split(separator: ":").compactMap { UInt8($0, radix: 16) }
				}

				semaphore.signal()
			}

			semaphore.wait()

			guard status == .VMNET_SUCCESS, self.iface != nil, self.mac.count == 6 else {
				throw NSError(domain: "vmnet", code: Int(status.rawValue), userInfo: [NSLocalizedDescriptionKey: "interface start failed: \(status.stringValue)"])
			}
		}

		func send(_ frame: [UInt8]) {
			var bytes = frame
			bytes.withUnsafeMutableBytes { raw in
				var iov = iovec(iov_base: raw.baseAddress, iov_len: raw.count)

				withUnsafeMutablePointer(to: &iov) { iovPointer in
					var packet = vmpktdesc(vm_pkt_size: raw.count, vm_pkt_iov: iovPointer, vm_pkt_iovcnt: 1, vm_flags: 0)
					var count: Int32 = 1

					_ = vmnet_write(self.iface!, &packet, &count)
				}
			}
		}

		/// Reads frames for up to `timeout` seconds until `match` accepts one.
		func receive(timeout: TimeInterval, match: ([UInt8]) -> Bool) -> [UInt8]? {
			let deadline = Date().addingTimeInterval(timeout)
			let size = 2048

			while Date() < deadline {
				let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
				var iov = iovec(iov_base: buffer, iov_len: size)

				defer { buffer.deallocate() }

				let found: [UInt8]? = withUnsafeMutablePointer(to: &iov) { iovPointer in
					var packet = vmpktdesc(vm_pkt_size: size, vm_pkt_iov: iovPointer, vm_pkt_iovcnt: 1, vm_flags: 0)
					var count: Int32 = 1

					guard vmnet_read(self.iface!, &packet, &count) == .VMNET_SUCCESS, count == 1 else {
						return nil
					}

					return Array(UnsafeBufferPointer(start: buffer, count: packet.vm_pkt_size))
				}

				if let found, match(found) {
					return found
				}

				if found == nil {
					Thread.sleep(forTimeInterval: 0.02)
				}
			}

			return nil
		}
	}

	/// A vmnet network (shared mode, vmnet's DHCP and DNS proxy off) with one interface standing in for a guest.
	private func makeGuest(gateway: String) throws -> Guest {
		var status = vmnet_return_t.VMNET_SUCCESS
		var subnet = inAddr(gateway)
		var mask = inAddr("255.255.255.0")
		let configuration = try XCTUnwrap(vmnet_network_configuration_create(.VMNET_SHARED_MODE, &status))

		XCTAssertEqual(vmnet_network_configuration_set_ipv4_subnet(configuration, &subnet, &mask), .VMNET_SUCCESS)
		vmnet_network_configuration_disable_dhcp(configuration)
		vmnet_network_configuration_disable_dns_proxy(configuration)

		let network = try XCTUnwrap(vmnet_network_create(configuration, &status), "vmnet_network_create: \(status.stringValue)")
		let guest = Guest(network: network)

		try guest.start(queue: self.queue)

		return guest
	}

	private func checksum(_ bytes: [UInt8]) -> UInt16 {
		var sum: UInt32 = 0
		var index = 0

		while index + 1 < bytes.count {
			sum += UInt32(bytes[index]) << 8 | UInt32(bytes[index + 1])
			index += 2
		}

		while sum >> 16 != 0 { sum = (sum & 0xffff) + (sum >> 16) }

		return ~UInt16(sum)
	}

	/// Ethernet + IPv4 + UDP around `payload`.
	private func udpFrame(sourceMAC: [UInt8], destinationMAC: [UInt8], sourceIP: UInt32, destinationIP: UInt32, sourcePort: Int, destinationPort: Int, payload: [UInt8]) -> [UInt8] {
		func be16(_ value: Int) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xff)] }
		func be32(_ value: UInt32) -> [UInt8] { [UInt8(value >> 24), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)] }

		let udpLength = 8 + payload.count
		var ip: [UInt8] = [0x45, 0] + be16(20 + udpLength) + [0, 0, 0, 0, 64, 17, 0, 0] + be32(sourceIP) + be32(destinationIP)
		let sum = checksum(ip)

		ip[10] = UInt8(sum >> 8)
		ip[11] = UInt8(sum & 0xff)

		return destinationMAC + sourceMAC + [0x08, 0x00] + ip + be16(sourcePort) + be16(destinationPort) + be16(udpLength) + [0, 0] + payload
	}

	/// The UDP payload of a frame addressed to `port`.
	private func udpPayload(_ frame: [UInt8], port: Int) -> [UInt8]? {
		guard frame.count > 42, frame[12] == 0x08, frame[13] == 0x00, frame[23] == 17 else { return nil }

		let ihl = Int(frame[14] & 0x0f) * 4
		let udp = 14 + ihl

		guard frame.count >= udp + 8, Int(frame[udp + 2]) << 8 | Int(frame[udp + 3]) == port else { return nil }

		return Array(frame[(udp + 8)...])
	}

	func testGuestGetsALeaseFromTheNetworkOwnDHCPServer() async throws {
		guard geteuid() == 0, ProcessInfo.processInfo.environment["CAKER_DHCP_VMNET_TEST"] == "1" else {
			throw XCTSkip("Needs root and CAKER_DHCP_VMNET_TEST=1")
		}

		let gateway = "10.78.1.1"
		let guest = try self.makeGuest(gateway: gateway)

		defer { _ = vmnet_stop_interface(guest.iface!, self.queue) { _ in } }

		// The bridge only exists now that an interface is attached.
		XCTAssertNotNil(DHCPServer.interfaceName(forIPv4: gateway), "the gateway address is on a host interface once a guest is attached")

		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

		defer { try? FileManager.default.removeItem(at: directory) }

		let store = DHCPLeaseStore(
			gateway: DHCPAddress.parse(gateway)!, poolStart: DHCPAddress.parse("10.78.1.2")!, poolEnd: DHCPAddress.parse("10.78.1.20")!, leaseDuration: 600,
			fileURL: directory.appendingPathComponent(DHCPLeaseStore.leaseFilename))
		let responder = DHCPResponder(configuration: .init(gateway: DHCPAddress.parse(gateway)!, netmask: DHCPAddress.parse("255.255.255.0")!, dnsServers: [DHCPAddress.parse(gateway)!], domainName: nil), store: store)
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
		let server = DHCPServer(group: group, responder: responder, bindAddress: gateway)

		try await server.startWithRetry()

		defer {
			Task { await server.shutdown() }
			try? group.syncShutdownGracefully()
		}

		let broadcast = [UInt8](repeating: 0xff, count: 6)
		var discover = DHCPMessage(xid: 0x1234_5678, flags: DHCPMessage.broadcastFlag, clientHardwareAddress: guest.mac, messageType: .discover)

		discover.hostname = "vmnet-test"

		guest.send(self.udpFrame(sourceMAC: guest.mac, destinationMAC: broadcast, sourceIP: 0, destinationIP: 0xffff_ffff, sourcePort: 68, destinationPort: 67, payload: discover.encode()))

		let offerFrame = guest.receive(timeout: 5) { frame in
			udpPayload(frame, port: 68).flatMap { try? DHCPMessage.parse($0) }?.messageType == .offer
		}
		let offer = try XCTUnwrap(offerFrame.flatMap { udpPayload($0, port: 68) }.flatMap { try? DHCPMessage.parse($0) }, "no DHCPOFFER came back through the bridge")

		XCTAssertTrue(store.isInPool(offer.yiaddr), "offered \(DHCPAddress.string(offer.yiaddr))")
		XCTAssertEqual(offer.routers, [DHCPAddress.parse(gateway)!])
		XCTAssertEqual(offer.xid, 0x1234_5678)

		var request = DHCPMessage(xid: 0x1234_5678, flags: DHCPMessage.broadcastFlag, clientHardwareAddress: guest.mac, messageType: .request)

		request.requestedAddress = offer.yiaddr
		request.serverIdentifier = DHCPAddress.parse(gateway)!
		request.hostname = "vmnet-test"

		guest.send(self.udpFrame(sourceMAC: guest.mac, destinationMAC: broadcast, sourceIP: 0, destinationIP: 0xffff_ffff, sourcePort: 68, destinationPort: 67, payload: request.encode()))

		let ackFrame = guest.receive(timeout: 5) { frame in
			udpPayload(frame, port: 68).flatMap { try? DHCPMessage.parse($0) }?.messageType == .ack
		}
		let ack = try XCTUnwrap(ackFrame.flatMap { udpPayload($0, port: 68) }.flatMap { try? DHCPMessage.parse($0) }, "no DHCPACK came back through the bridge")

		XCTAssertEqual(ack.yiaddr, offer.yiaddr)

		// The lease is in this network's own table.
		let table = try String(contentsOf: directory.appendingPathComponent(DHCPLeaseStore.leaseFilename), encoding: .utf8)

		XCTAssertTrue(table.contains("ip_address=\(DHCPAddress.string(ack.yiaddr))"), table)
		XCTAssertTrue(table.contains("name=vmnet-test"), table)
	}

	func testGuestResolvesThroughTheNetworkDNSOnPort53() async throws {
		guard geteuid() == 0, ProcessInfo.processInfo.environment["CAKER_DHCP_VMNET_TEST"] == "1" else {
			throw XCTSkip("Needs root and CAKER_DHCP_VMNET_TEST=1")
		}

		// A fake upstream resolver: answers any query by echoing it with QR set.
		final class Echo: ChannelInboundHandler {
			typealias InboundIn = AddressedEnvelope<ByteBuffer>
			typealias OutboundOut = AddressedEnvelope<ByteBuffer>

			func channelRead(context: ChannelHandlerContext, data: NIOAny) {
				let envelope = unwrapInboundIn(data)
				var buffer = envelope.data
				var bytes = buffer.readBytes(length: buffer.readableBytes) ?? []

				bytes[2] |= 0x80
				bytes[3] = 0x80 | 0x00
				context.writeAndFlush(wrapOutboundOut(AddressedEnvelope(remoteAddress: envelope.remoteAddress, data: ByteBuffer(bytes: bytes))), promise: nil)
			}
		}

		let gateway = "10.78.3.1"
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
		let upstream = try await DatagramBootstrap(group: group).channelInitializer { $0.pipeline.addHandler(Echo()) }.bind(host: "127.0.0.1", port: 0).get()
		let guest = try self.makeGuest(gateway: gateway)

		defer {
			_ = vmnet_stop_interface(guest.iface!, self.queue) { _ in }
			upstream.close(promise: nil)
		}

		let registry = ComposeDNSRegistry()

		registry.replaceAll(services: [], vms: [(name: "web", ip: "10.78.3.9")])

		let forwarder = DNSForwarder(group: group, upstreams: ["127.0.0.1"], port: try XCTUnwrap(upstream.localAddress?.port))
		let server = ComposeDNSServer(group: group, registry: registry, bindAddress: gateway, internalPort: ComposeDNS.internalBindPort, standardPort: 53, forwarder: forwarder)

		try await server.startWithRetry()

		defer { Task { await server.shutdown() } }

		// The guest has to ARP for the gateway first.
		let broadcast = [UInt8](repeating: 0xff, count: 6)
		let guestIP = DHCPAddress.parse("10.78.3.5")!
		let gatewayIP = DHCPAddress.parse(gateway)!

		func be32(_ value: UInt32) -> [UInt8] { [UInt8(value >> 24), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)] }

		let arp: [UInt8] = broadcast + guest.mac + [0x08, 0x06, 0, 1, 8, 0, 6, 4, 0, 1] + guest.mac + be32(guestIP) + [UInt8](repeating: 0, count: 6) + be32(gatewayIP)

		guest.send(arp)

		let reply = try XCTUnwrap(guest.receive(timeout: 5) { $0.count >= 42 && $0[12] == 0x08 && $0[13] == 0x06 && $0[21] == 2 }, "the gateway did not answer ARP")
		let gatewayMAC = Array(reply[22..<28])

		func query(_ name: String, id: UInt16) -> [UInt8] {
			var message: [UInt8] = [UInt8(id >> 8), UInt8(id & 0xff), 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0]

			for label in name.split(separator: ".") {
				message.append(UInt8(label.utf8.count))
				message.append(contentsOf: Array(label.utf8))
			}

			return message + [0, 0, 1, 0, 1]
		}

		func ask(_ name: String, id: UInt16) -> [UInt8]? {
			guest.send(self.udpFrame(sourceMAC: guest.mac, destinationMAC: gatewayMAC, sourceIP: guestIP, destinationIP: gatewayIP, sourcePort: 40000, destinationPort: 53, payload: query(name, id: id)))

			return guest.receive(timeout: 5) { frame in
				udpPayload(frame, port: 40000).map { $0.count >= 12 && Int($0[0]) << 8 | Int($0[1]) == Int(id) } ?? false
			}.flatMap { udpPayload($0, port: 40000) }
		}

		// A VM of the network: answered locally.
		let local = try XCTUnwrap(ask("web." + ComposeDNS.domainSuffix, id: 0x0101), "no answer for a local name")

		XCTAssertEqual(local[3] & 0x0f, 0, "rcode")
		XCTAssertEqual(local[7], 1, "one answer")
		XCTAssertEqual(Array(local.suffix(4)), [10, 78, 3, 9])

		// Anything else: forwarded to the next resolver (the echo sets QR, so it comes back verbatim).
		let forwarded = try XCTUnwrap(ask("www.example.org", id: 0x0202), "no answer for a forwarded name")

		XCTAssertEqual(forwarded[0], 0x02)
		XCTAssertEqual(forwarded[7], 0, "the echo has no answer section")
		XCTAssertEqual(forwarded[2] & 0x80, 0x80)

		// A name of the compose domain nobody registered is answered locally (NXDOMAIN), never forwarded.
		let unknown = try XCTUnwrap(ask("nobody." + ComposeDNS.domainSuffix, id: 0x0303))

		XCTAssertEqual(unknown[3] & 0x0f, 3, "NXDOMAIN")

		try? group.syncShutdownGracefully()
	}
}
