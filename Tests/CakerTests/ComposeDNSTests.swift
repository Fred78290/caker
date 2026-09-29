//
//  ComposeDNSTests.swift
//  CakerTests
//

import Foundation
import XCTest
import Yams

@testable import CakedLib
@testable import caked

final class ComposeDNSTests: XCTestCase {

	// MARK: - Naming

	func testParseServiceNameRoundTripsWithFullyQualifiedName() {
		let fqdn = ComposeDNS.fullyQualifiedName(service: "mariadb", project: "myapp")

		XCTAssertEqual(fqdn, "mariadb.myapp.compose.internal")
		XCTAssertEqual(ComposeDNS.parseServiceName(fqdn), ComposeDNS.ServiceName(service: "mariadb", project: "myapp"))
	}

	func testParseServiceNameIsCaseInsensitiveAndAcceptsTrailingDot() {
		XCTAssertEqual(ComposeDNS.parseServiceName("MariaDB.MyApp.Compose.Internal."), ComposeDNS.ServiceName(service: "mariadb", project: "myapp"))
	}

	func testParseServiceNameRejectsWrongDomain() {
		XCTAssertNil(ComposeDNS.parseServiceName("mariadb.myapp.example.com"))
		XCTAssertNil(ComposeDNS.parseServiceName("mariadb.myapp.compose.internal.evil.com"))
	}

	func testParseServiceNameRejectsWrongLabelCount() {
		XCTAssertNil(ComposeDNS.parseServiceName("compose.internal"))
		XCTAssertNil(ComposeDNS.parseServiceName("mariadb.compose.internal"))
		XCTAssertNil(ComposeDNS.parseServiceName("a.b.mariadb.myapp.compose.internal"))
		XCTAssertNil(ComposeDNS.parseServiceName("..compose.internal"))
	}

	// MARK: - DNS wire codec

	private func encodeQuery(id: UInt16 = 0x1234, name: String, type: UInt16 = DNSMessage.typeA, qclass: UInt16 = DNSMessage.classIN, recursionDesired: Bool = true) -> [UInt8] {
		var bytes: [UInt8] = []

		bytes.append(UInt8(id >> 8))
		bytes.append(UInt8(id & 0xFF))
		bytes.append(recursionDesired ? 0x01 : 0x00)  // RD only
		bytes.append(0x00)
		bytes.append(contentsOf: [0x00, 0x01])  // QDCOUNT = 1
		bytes.append(contentsOf: [0x00, 0x00])  // ANCOUNT
		bytes.append(contentsOf: [0x00, 0x00])  // NSCOUNT
		bytes.append(contentsOf: [0x00, 0x00])  // ARCOUNT

		for label in name.split(separator: ".") {
			let labelBytes = Array(label.utf8)

			bytes.append(UInt8(labelBytes.count))
			bytes.append(contentsOf: labelBytes)
		}

		bytes.append(0x00)
		bytes.append(contentsOf: [UInt8(type >> 8), UInt8(type & 0xFF)])
		bytes.append(contentsOf: [UInt8(qclass >> 8), UInt8(qclass & 0xFF)])

		return bytes
	}

	func testParseQueryRoundTripsNameTypeAndID() throws {
		let raw = self.encodeQuery(id: 0xBEEF, name: "mariadb.myapp.compose.internal")
		let query = try DNSMessage.parseQuery(raw)

		XCTAssertEqual(query.id, 0xBEEF)
		XCTAssertEqual(query.name, "mariadb.myapp.compose.internal")
		XCTAssertEqual(query.type, DNSMessage.typeA)
		XCTAssertEqual(query.qclass, DNSMessage.classIN)
		XCTAssertTrue(query.recursionDesired)
	}

	func testParseQueryThrowsOnTruncatedHeader() {
		XCTAssertThrowsError(try DNSMessage.parseQuery([0x00, 0x01])) { error in
			XCTAssertEqual(error as? DNSMessage.DNSError, .truncated)
		}
	}

	func testParseQueryThrowsOnMultipleQuestions() {
		var raw = self.encodeQuery(name: "a.b.compose.internal")

		raw[5] = 0x02  // QDCOUNT = 2

		XCTAssertThrowsError(try DNSMessage.parseQuery(raw)) { error in
			XCTAssertEqual(error as? DNSMessage.DNSError, .unsupportedQuestionCount(2))
		}
	}

	func testParseQueryThrowsOnTruncatedLabel() {
		// A length byte claiming more bytes than actually follow.
		var raw = self.encodeQuery(name: "a.compose.internal")
		let firstLabelLength = Int(raw[12])

		raw = Array(raw[0..<(12 + 1 + firstLabelLength - 1)])  // cut the label short

		XCTAssertThrowsError(try DNSMessage.parseQuery(raw)) { error in
			XCTAssertEqual(error as? DNSMessage.DNSError, .truncated)
		}
	}

	func testEncodeResponseWithOneAddress() throws {
		let query = try DNSMessage.parseQuery(self.encodeQuery(name: "mariadb.myapp.compose.internal"))
		let response = DNSMessage.encodeResponse(to: query, addresses: ["192.168.64.5"], ttlSeconds: 5)
		let echoed = try DNSMessage.parseQuery(Array(response))

		// The response's own question section must still parse back to the same query.
		XCTAssertEqual(echoed.name, "mariadb.myapp.compose.internal")

		// QR bit set, RCODE 0 (NOERROR), ANCOUNT 1.
		XCTAssertEqual(response[2] & 0x80, 0x80)
		XCTAssertEqual(response[3] & 0x0F, 0)
		XCTAssertEqual(UInt16(response[7]), 1)

		// The trailing 4 bytes of a single-answer, single-A-record response are the address.
		XCTAssertEqual(Array(response.suffix(4)), [192, 168, 64, 5])
	}

	func testEncodeResponseWithNoAddressesHasZeroAnswers() throws {
		let query = try DNSMessage.parseQuery(self.encodeQuery(name: "mariadb.myapp.compose.internal"))
		let response = DNSMessage.encodeResponse(to: query, addresses: [])

		XCTAssertEqual(UInt16(response[7]), 0)
	}

	func testEncodeErrorSetsRCodeAndEchoesQuestion() throws {
		let query = try DNSMessage.parseQuery(self.encodeQuery(name: "unknown.compose.internal"))
		let response = DNSMessage.encodeError(to: query, rcode: .refused)
		let echoed = try DNSMessage.parseQuery(Array(response))

		XCTAssertEqual(echoed.name, "unknown.compose.internal")
		XCTAssertEqual(response[3] & 0x0F, DNSMessage.ResponseCode.refused.rawValue)
		XCTAssertEqual(UInt16(response[7]), 0)
	}

	private func UInt16(_ byte: UInt8) -> Swift.UInt16 { Swift.UInt16(byte) }

	// MARK: - Registry

	func testRegistryReturnsRegisteredAddress() {
		let registry = ComposeDNSRegistry()

		registry.register(project: "myapp", service: "mariadb", ip: "192.168.64.5")

		XCTAssertEqual(registry.address(for: .init(service: "mariadb", project: "myapp")), "192.168.64.5")
		XCTAssertNil(registry.address(for: .init(service: "phpmyadmin", project: "myapp")))
	}

	func testRegistryScopesByProject() {
		let registry = ComposeDNSRegistry()

		registry.register(project: "myapp", service: "mariadb", ip: "192.168.64.5")
		registry.register(project: "otherapp", service: "mariadb", ip: "192.168.64.9")

		XCTAssertEqual(registry.address(for: .init(service: "mariadb", project: "myapp")), "192.168.64.5")
		XCTAssertEqual(registry.address(for: .init(service: "mariadb", project: "otherapp")), "192.168.64.9")
	}

	func testRegistryUnregisterRemovesOnlyThatEntry() {
		let registry = ComposeDNSRegistry()

		registry.register(project: "myapp", service: "mariadb", ip: "192.168.64.5")
		registry.register(project: "myapp", service: "phpmyadmin", ip: "192.168.64.6")

		XCTAssertTrue(registry.unregister(project: "myapp", service: "mariadb"))
		XCTAssertNil(registry.address(for: .init(service: "mariadb", project: "myapp")))
		XCTAssertEqual(registry.address(for: .init(service: "phpmyadmin", project: "myapp")), "192.168.64.6")
		XCTAssertFalse(registry.isEmpty)

		XCTAssertTrue(registry.unregister(project: "myapp", service: "phpmyadmin"))
		XCTAssertTrue(registry.isEmpty)
	}

	// MARK: - Cloud-init injection (ComposeFile.toBuildOptions)

	func testToBuildOptionsWithNoGatewayInjectsNoSplitDNSSetup() throws {
		let yaml = """
			name: myapp
			services:
			  mariadb:
			    image: ubuntu:24.04
			    post_commands:
			      - echo hi
			"""
		let file = try YAMLDecoder().decode(ComposeFile.self, from: yaml)
		let svc = try XCTUnwrap(file.services["mariadb"])
		let built = try svc.toBuildOptions(name: "compose-myapp-mariadb", composeNetworks: nil)
		let path = try XCTUnwrap(built.options.userData)
		let userData = try String(contentsOfFile: path, encoding: .utf8)

		XCTAssertFalse(userData.contains("resolvectl"))
	}

	func testToBuildOptionsWithGatewayPrependsSplitDNSBeforePostCommands() throws {
		let yaml = """
			name: myapp
			services:
			  mariadb:
			    image: ubuntu:24.04
			    post_commands:
			      - echo hi
			"""
		let file = try YAMLDecoder().decode(ComposeFile.self, from: yaml)
		let svc = try XCTUnwrap(file.services["mariadb"])
		let built = try svc.toBuildOptions(name: "compose-myapp-mariadb", composeNetworks: nil, composeDNSGateway: "192.168.64.1")
		let path = try XCTUnwrap(built.options.userData)
		let userData = try String(contentsOfFile: path, encoding: .utf8)

		XCTAssertTrue(userData.contains("resolvectl dns"))
		XCTAssertTrue(userData.contains("~compose.internal"))
		XCTAssertTrue(userData.contains("192.168.64.1"))

		let dnsLineRange = try XCTUnwrap(userData.range(of: "resolvectl dns"))
		let postCommandRange = try XCTUnwrap(userData.range(of: "echo hi"))

		XCTAssertLessThan(dnsLineRange.lowerBound, postCommandRange.lowerBound, "split-DNS setup must run before the user's own post_commands")
	}
}
