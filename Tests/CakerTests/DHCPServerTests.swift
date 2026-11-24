//
//  DHCPServerTests.swift
//  CakerTests
//

import Foundation
import NIOCore
import NIOPosix
import XCTest

@testable import CakedLib

final class DHCPServerTests: XCTestCase {
	private let gateway = DHCPAddress.parse("192.168.50.1")!
	private let netmask = DHCPAddress.parse("255.255.255.0")!

	private func ip(_ string: String) -> UInt32 { DHCPAddress.parse(string)! }

	private func makeResponder(end: String = "192.168.50.20", file: URL? = nil, now: @escaping @Sendable () -> Date = { Date() }) -> DHCPResponder {
		let store = DHCPLeaseStore(gateway: gateway, poolStart: ip("192.168.50.2"), poolEnd: ip(end), leaseDuration: 3600, fileURL: file, now: now)

		return DHCPResponder(configuration: .init(gateway: gateway, netmask: netmask, dnsServers: [gateway], domainName: "compose.internal"), store: store)
	}

	private func request(_ type: DHCPMessage.MessageType, mac: UInt8 = 1, requested: String? = nil, server: UInt32? = nil, ciaddr: UInt32 = 0, hostname: String? = nil, xid: UInt32 = 0xdead_beef) -> DHCPMessage {
		var message = DHCPMessage(xid: xid, ciaddr: ciaddr, clientHardwareAddress: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, mac], messageType: type)

		message.requestedAddress = requested.flatMap(DHCPAddress.parse)
		message.serverIdentifier = server
		message.hostname = hostname

		return message
	}

	// MARK: - Codec

	func testAddressRoundTrip() {
		XCTAssertEqual(DHCPAddress.string(ip("10.0.255.7")), "10.0.255.7")
		XCTAssertNil(DHCPAddress.parse("10.0.0"))
		XCTAssertNil(DHCPAddress.parse("10.0.0.256"))
	}

	func testMessageRoundTrip() throws {
		var message = request(.request, requested: "192.168.50.9", server: gateway, hostname: "alpine")

		message.clientIdentifier = [1, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 1]

		let decoded = try DHCPMessage.parse(message.encode())

		XCTAssertEqual(decoded.messageType, .request)
		XCTAssertEqual(decoded.xid, 0xdead_beef)
		XCTAssertEqual(decoded.requestedAddress, ip("192.168.50.9"))
		XCTAssertEqual(decoded.serverIdentifier, gateway)
		XCTAssertEqual(decoded.hostname, "alpine")
		XCTAssertEqual(decoded.clientHardwareAddress, [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 1])
		XCTAssertGreaterThanOrEqual(message.encode().count, 300)
	}

	func testParseRejectsGarbageWithoutTrapping() {
		XCTAssertThrowsError(try DHCPMessage.parse([]))
		XCTAssertThrowsError(try DHCPMessage.parse([UInt8](repeating: 0, count: 300)))

		var truncated = request(.discover).encode()

		// An option whose length runs past the end of the packet.
		truncated.removeLast(truncated.count - 241)
		truncated.append(contentsOf: [61, 200, 1])

		XCTAssertThrowsError(try DHCPMessage.parse(truncated))
	}

	func testDUIDClientIdentifierBecomesTheLeaseKey() {
		var message = request(.discover)

		XCTAssertEqual(message.hwAddressKey, "1,aa:bb:cc:dd:ee:01")

		message.clientIdentifier = [255, 0x00, 0x04, 0xab]

		XCTAssertEqual(message.hwAddressKey, "ff,00:04:ab")
	}

	// MARK: - Protocol

	func testDiscoverThenRequestGivesALease() throws {
		let responder = makeResponder()
		let offer = try XCTUnwrap(responder.respond(to: request(.discover)))

		XCTAssertEqual(offer.messageType, .offer)
		XCTAssertEqual(offer.yiaddr, ip("192.168.50.2"))
		XCTAssertEqual(offer.routers, [gateway])
		XCTAssertEqual(offer.dnsServers, [gateway])
		XCTAssertEqual(offer.subnetMask, netmask)
		XCTAssertEqual(offer.domainName, "compose.internal")
		XCTAssertEqual(offer.leaseTime, 3600)
		XCTAssertEqual(offer.xid, 0xdead_beef)

		let ack = try XCTUnwrap(responder.respond(to: request(.request, requested: "192.168.50.2", server: gateway, hostname: "vm1")))

		XCTAssertEqual(ack.messageType, .ack)
		XCTAssertEqual(ack.yiaddr, ip("192.168.50.2"))
		XCTAssertEqual(responder.store.lease(for: "1,aa:bb:cc:dd:ee:01")?.hostname, "vm1")
	}

	func testEachClientGetsItsOwnAddressAndKeepsIt() throws {
		let responder = makeResponder()
		let first = try XCTUnwrap(responder.respond(to: request(.discover, mac: 1)))
		let second = try XCTUnwrap(responder.respond(to: request(.discover, mac: 2)))

		XCTAssertNotEqual(first.yiaddr, second.yiaddr)

		_ = responder.respond(to: request(.request, mac: 1, requested: DHCPAddress.string(first.yiaddr), server: gateway))
		_ = responder.respond(to: request(.request, mac: 2, requested: DHCPAddress.string(second.yiaddr), server: gateway))

		// Same client again: same address.
		XCTAssertEqual(responder.respond(to: request(.discover, mac: 1))?.yiaddr, first.yiaddr)
	}

	func testRequestOfAnAddressHeldByAnotherClientIsNaked() throws {
		let responder = makeResponder()
		let first = try XCTUnwrap(responder.respond(to: request(.discover, mac: 1)))

		_ = responder.respond(to: request(.request, mac: 1, requested: DHCPAddress.string(first.yiaddr), server: gateway))

		let nak = try XCTUnwrap(responder.respond(to: request(.request, mac: 2, requested: DHCPAddress.string(first.yiaddr))))

		XCTAssertEqual(nak.messageType, .nak)
		XCTAssertEqual(nak.yiaddr, 0)
	}

	func testRequestOutsideThePoolOrOfTheGatewayIsNaked() throws {
		let responder = makeResponder()

		XCTAssertEqual(responder.respond(to: request(.request, requested: "10.9.9.9"))?.messageType, .nak)
		XCTAssertEqual(responder.respond(to: request(.request, requested: "192.168.50.1"))?.messageType, .nak)
	}

	func testRequestForAnotherServerIsIgnored() {
		let responder = makeResponder()

		XCTAssertNil(responder.respond(to: request(.request, requested: "192.168.50.2", server: ip("192.168.50.99"))))
	}

	func testRenewalUsesCiaddr() throws {
		let responder = makeResponder()
		let offer = try XCTUnwrap(responder.respond(to: request(.discover)))
		let renewal = try XCTUnwrap(responder.respond(to: request(.request, ciaddr: offer.yiaddr)))

		XCTAssertEqual(renewal.messageType, .ack)
		XCTAssertEqual(renewal.yiaddr, offer.yiaddr)
	}

	func testPoolExhaustionAnswersNothing() throws {
		let responder = makeResponder(end: "192.168.50.3")

		for mac in 1...2 as ClosedRange<UInt8> {
			let offer = try XCTUnwrap(responder.respond(to: request(.discover, mac: mac)))

			_ = responder.respond(to: request(.request, mac: mac, requested: DHCPAddress.string(offer.yiaddr), server: gateway))
		}

		XCTAssertNil(responder.respond(to: request(.discover, mac: 3)))
	}

	func testReleaseFreesTheAddressForAnotherClient() throws {
		let responder = makeResponder(end: "192.168.50.2")
		let offer = try XCTUnwrap(responder.respond(to: request(.discover, mac: 1)))

		_ = responder.respond(to: request(.request, mac: 1, requested: DHCPAddress.string(offer.yiaddr), server: gateway))

		XCTAssertNil(responder.respond(to: request(.discover, mac: 2)))

		_ = responder.respond(to: request(.release, mac: 1))

		XCTAssertEqual(responder.respond(to: request(.discover, mac: 2))?.yiaddr, offer.yiaddr)
	}

	func testDeclinedAddressIsNotOfferedAgain() throws {
		let responder = makeResponder()
		let offer = try XCTUnwrap(responder.respond(to: request(.discover)))

		_ = responder.respond(to: request(.decline, requested: DHCPAddress.string(offer.yiaddr)))

		XCTAssertNotEqual(responder.respond(to: request(.discover))?.yiaddr, offer.yiaddr)
	}

	func testExpiredLeaseAddressIsReusedByAnotherClient() throws {
		final class Clock: @unchecked Sendable {
			var date = Date(timeIntervalSince1970: 1_000_000)
		}

		let clock = Clock()
		let responder = makeResponder(end: "192.168.50.2", now: { clock.date })
		let offer = try XCTUnwrap(responder.respond(to: request(.discover, mac: 1)))

		_ = responder.respond(to: request(.request, mac: 1, requested: DHCPAddress.string(offer.yiaddr), server: gateway))
		clock.date.addTimeInterval(7200)

		XCTAssertEqual(responder.respond(to: request(.discover, mac: 2))?.yiaddr, offer.yiaddr)
	}

	func testSameMachineKeepsItsAddressWhenItsClientIdentifierChanges() throws {
		let responder = makeResponder()

		// The installer asks with its MAC, the installed system with a DUID: same chaddr.
		let installer = try XCTUnwrap(responder.respond(to: request(.discover, mac: 1)))

		_ = responder.respond(to: request(.request, mac: 1, requested: DHCPAddress.string(installer.yiaddr), server: gateway))

		var other = try XCTUnwrap(responder.respond(to: request(.discover, mac: 2)))

		_ = responder.respond(to: request(.request, mac: 2, requested: DHCPAddress.string(other.yiaddr), server: gateway))

		var discover = request(.discover, mac: 1)

		discover.clientIdentifier = [255, 0x00, 0x04, 0xab]
		other = try XCTUnwrap(responder.respond(to: discover))

		XCTAssertEqual(other.yiaddr, installer.yiaddr)

		var renew = request(.request, mac: 1, requested: DHCPAddress.string(installer.yiaddr), server: gateway, hostname: "debian")

		renew.clientIdentifier = [255, 0x00, 0x04, 0xab]

		XCTAssertEqual(responder.respond(to: renew)?.messageType, .ack)
		// One lease for the machine, under its new identifier, and it kept the address.
		XCTAssertNil(responder.store.lease(for: "1,aa:bb:cc:dd:ee:01"))
		XCTAssertEqual(responder.store.lease(for: "ff,00:04:ab")?.address, installer.yiaddr)
		XCTAssertEqual(responder.store.lease(for: "ff,00:04:ab")?.macAddress, "aa:bb:cc:dd:ee:01")
	}

	func testAddressesAreHandedOutInTurnAndWrapAround() throws {
		final class Clock: @unchecked Sendable {
			var date = Date(timeIntervalSince1970: 1_000_000)
		}

		let clock = Clock()
		let responder = makeResponder(end: "192.168.50.4", now: { clock.date })

		func lease(_ mac: UInt8) throws -> UInt32 {
			let offer = try XCTUnwrap(responder.respond(to: request(.discover, mac: mac)))

			_ = responder.respond(to: request(.request, mac: mac, requested: DHCPAddress.string(offer.yiaddr), server: gateway))

			return offer.yiaddr
		}

		// First client leaves for good: its address is free again, but others are handed out first.
		XCTAssertEqual(try lease(1), ip("192.168.50.2"))
		responder.store.release(hwAddress: "1,aa:bb:cc:dd:ee:01")
		XCTAssertEqual(try lease(2), ip("192.168.50.3"))
		XCTAssertEqual(try lease(3), ip("192.168.50.4"))
		// End of the pool reached: start again from the base, which only holds an ended lease.
		XCTAssertEqual(try lease(4), ip("192.168.50.2"))

		// The first client comes back after its address was reused: it gets another one only when one is free.
		clock.date.addTimeInterval(7200)
		XCTAssertNotNil(responder.respond(to: request(.discover, mac: 1)))
	}

	func testAddressOfAnExpiredLeaseIsKeptForItsClientWhileOthersAreFree() throws {
		final class Clock: @unchecked Sendable {
			var date = Date(timeIntervalSince1970: 1_000_000)
		}

		let clock = Clock()
		let responder = makeResponder(end: "192.168.50.5", now: { clock.date })

		for mac in [UInt8(1), 2] {
			let offer = try XCTUnwrap(responder.respond(to: request(.discover, mac: mac)))

			_ = responder.respond(to: request(.request, mac: mac, requested: DHCPAddress.string(offer.yiaddr), server: gateway))
		}

		clock.date.addTimeInterval(7200)

		// Both leases expired; a new client doesn't take their addresses while never-used ones remain.
		let newcomer = try XCTUnwrap(responder.respond(to: request(.discover, mac: 9)))

		XCTAssertGreaterThanOrEqual(newcomer.yiaddr, ip("192.168.50.4"))
		XCTAssertEqual(responder.respond(to: request(.discover, mac: 1))?.yiaddr, ip("192.168.50.2"))
	}

	func testAllocationCursorSurvivesARestart() throws {
		let file = FileManager.default.temporaryDirectory.appendingPathComponent("dhcp-cursor-\(UUID().uuidString)")

		defer { try? FileManager.default.removeItem(at: file) }

		let responder = makeResponder(file: file)

		for mac in [UInt8(1), 2] {
			let offer = try XCTUnwrap(responder.respond(to: request(.discover, mac: mac)))

			_ = responder.respond(to: request(.request, mac: mac, requested: DHCPAddress.string(offer.yiaddr), server: gateway))
		}

		let restarted = makeResponder(file: file)

		XCTAssertEqual(restarted.respond(to: request(.discover, mac: 3))?.yiaddr, ip("192.168.50.4"))
	}

	// MARK: - Per-network lease table

	func testLeasesArePersistedInAFileTheLeaseParserReads() throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let file = directory.appendingPathComponent(DHCPLeaseStore.leaseFilename)

		defer { try? FileManager.default.removeItem(at: directory) }

		let responder = makeResponder(file: file)
		let offer = try XCTUnwrap(responder.respond(to: request(.discover, mac: 7)))

		_ = responder.respond(to: request(.request, mac: 7, requested: DHCPAddress.string(offer.yiaddr), server: gateway, hostname: "web"))

		let parser = DHCPLeaseParser(content: try String(contentsOf: file, encoding: .utf8))

		XCTAssertEqual(parser["AA:BB:CC:DD:EE:07"], DHCPAddress.string(offer.yiaddr))
		XCTAssertEqual(parser.address(forHostname: "web", in: "192.168.50.0/24"), DHCPAddress.string(offer.yiaddr))
		XCTAssertNil(parser.address(forHostname: "web", in: "10.0.0.0/8"))

		// A restart reloads the table: same client, same address.
		let restarted = makeResponder(file: file)

		XCTAssertEqual(restarted.respond(to: request(.discover, mac: 7))?.yiaddr, offer.yiaddr)
	}

	func testTwoNetworksKeepIndependentTables() throws {
		let a = makeResponder()
		let b = makeResponder()

		let fromA = try XCTUnwrap(a.respond(to: request(.discover, mac: 1)))

		_ = a.respond(to: request(.request, mac: 1, requested: DHCPAddress.string(fromA.yiaddr), server: gateway))

		// The same address is free on the other network.
		XCTAssertEqual(b.respond(to: request(.discover, mac: 2))?.yiaddr, fromA.yiaddr)
	}

	// MARK: - DNS forwarding

	func testSystemResolversSkipLoopbackAndTheGateway() {
		let text = """
			# comment
			search lan
			nameserver 127.0.0.1
			nameserver 192.168.50.1
			nameserver 9.9.9.9
			nameserver 9.9.9.9
			nameserver fe80::1
			"""

		XCTAssertEqual(DNSForwarder.systemResolvers(excluding: ["192.168.50.1"], contents: text), ["9.9.9.9"])
	}

	func testForwarderRelaysTheUpstreamAnswerAndFallsThroughADeadUpstream() async throws {
		final class Echo: ChannelInboundHandler {
			typealias InboundIn = AddressedEnvelope<ByteBuffer>
			typealias OutboundOut = AddressedEnvelope<ByteBuffer>

			func channelRead(context: ChannelHandlerContext, data: NIOAny) {
				let envelope = unwrapInboundIn(data)
				var buffer = envelope.data
				var bytes = buffer.readBytes(length: buffer.readableBytes) ?? []

				bytes[2] |= 0x80  // QR
				context.writeAndFlush(wrapOutboundOut(AddressedEnvelope(remoteAddress: envelope.remoteAddress, data: ByteBuffer(bytes: bytes))), promise: nil)
			}
		}

		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer { try? group.syncShutdownGracefully() }

		let server = try await DatagramBootstrap(group: group).channelInitializer { $0.pipeline.addHandler(Echo()) }.bind(host: "127.0.0.1", port: 0).get()

		defer { server.close(promise: nil) }

		let port = try XCTUnwrap(server.localAddress?.port)
		var query = [UInt8](repeating: 0, count: 12)

		query[0] = 0x12
		query[1] = 0x34

		let forwarder = DNSForwarder(group: group, upstreams: ["127.0.0.1"], port: port)
		let answer = await forwarder.forward(query)

		XCTAssertEqual(answer?[0], 0x12)
		XCTAssertEqual(answer.map { $0[2] & 0x80 }, 0x80)

		// Nobody listens there: no answer, within the timeout.
		let silent = DNSForwarder(group: group, upstreams: ["127.0.0.1"], timeout: .milliseconds(200), port: 9)

		let none = await silent.forward(query)

		XCTAssertNil(none)
	}

	// MARK: - Review findings

	func testHostnameWithANewlineCannotForgeAnotherLease() throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let file = directory.appendingPathComponent(DHCPLeaseStore.leaseFilename)

		defer { try? FileManager.default.removeItem(at: directory) }

		let responder = makeResponder(file: file)
		let hostile = "x\n}\n{\nip_address=192.168.50.9\nhw_address=1,aa:bb:cc:dd:ee:99\nlease=0x7fffffff"
		let offer = try XCTUnwrap(responder.respond(to: request(.discover, mac: 1)))

		_ = responder.respond(to: request(.request, mac: 1, requested: DHCPAddress.string(offer.yiaddr), server: gateway, hostname: hostile))

		let table = try String(contentsOf: file, encoding: .utf8)

		XCTAssertFalse(table.contains("192.168.50.9"), table)
		XCTAssertFalse(table.contains("name=x"), table)
		XCTAssertEqual(DHCPLeaseParser(content: table)["AA:BB:CC:DD:EE:99"], nil)
		XCTAssertEqual(makeResponder(file: file).store.activeLeases.count, 1, "reloading finds the one real lease")

		XCTAssertTrue(DHCPLeaseStore.isValidHostname("web-1.local_x"))
		XCTAssertFalse(DHCPLeaseStore.isValidHostname(""))
		XCTAssertFalse(DHCPLeaseStore.isValidHostname("a b"))
		XCTAssertFalse(DHCPLeaseStore.isValidHostname(String(repeating: "a", count: 64)))
	}

	func testForwarderRefusesPastTheInFlightLimit() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer { Task { try? await group.shutdownGracefully() } }

		var query = [UInt8](repeating: 0, count: 12)

		query[1] = 1

		// Nobody answers on that port, so the first query stays in flight until its timeout.
		let forwarder = DNSForwarder(group: group, upstreams: ["127.0.0.1"], timeout: .milliseconds(800), port: 9, maxInFlight: 1)
		let first = Task { await forwarder.forward(query) }

		try await Task.sleep(nanoseconds: 200_000_000)

		let started = Date()
		let second = await forwarder.forward(query)

		XCTAssertNil(second)
		XCTAssertLessThan(Date().timeIntervalSince(started), 0.3, "answered at once, did not wait for a socket")

		_ = await first.value

		// The slot was released: the next query is admitted again (and times out on its own).
		let third = Date()

		_ = await forwarder.forward(query)

		XCTAssertGreaterThan(Date().timeIntervalSince(third), 0.3, "was admitted and waited for the upstream")
	}
}
