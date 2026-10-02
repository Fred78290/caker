//
//  ComposeDNSTests.swift
//  CakerTests
//

import Foundation
import GRPCLib
import NIOPosix
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
		// One label resolves as a plain VM name now (see testParseQueryNameResolvesOneLabelAsVM
		// below) rather than being outside the synthetic domain — but it's still not a *service*
		// name, so parseServiceName specifically must still reject it.
		XCTAssertNil(ComposeDNS.parseServiceName("mariadb.compose.internal"))
		XCTAssertNil(ComposeDNS.parseServiceName("a.b.mariadb.myapp.compose.internal"))
		XCTAssertNil(ComposeDNS.parseServiceName("..compose.internal"))
	}

	func testParseQueryNameResolvesTwoLabelsAsService() {
		XCTAssertEqual(ComposeDNS.parseQueryName("mariadb.myapp.compose.internal"), .service(.init(service: "mariadb", project: "myapp")))
	}

	func testParseQueryNameResolvesOneLabelAsVM() {
		XCTAssertEqual(ComposeDNS.parseQueryName("myvm.compose.internal"), .vm("myvm"))
		XCTAssertEqual(ComposeDNS.parseQueryName("MyVM.Compose.Internal."), .vm("myvm"), "case-insensitive and trailing-dot-tolerant, same as the service form")
	}

	func testParseQueryNameRejectsWrongDomainOrLabelCount() {
		XCTAssertNil(ComposeDNS.parseQueryName("compose.internal"))
		XCTAssertNil(ComposeDNS.parseQueryName("myvm.example.com"))
		XCTAssertNil(ComposeDNS.parseQueryName("a.b.mariadb.myapp.compose.internal"))
		XCTAssertNil(ComposeDNS.parseQueryName("..compose.internal"))
	}

	func testFullyQualifiedNameForVMRoundTripsThroughParseQueryName() {
		let fqdn = ComposeDNS.fullyQualifiedName(vmName: "MyVM")

		XCTAssertEqual(fqdn, "myvm.compose.internal")
		XCTAssertEqual(ComposeDNS.parseQueryName(fqdn), .vm("myvm"))
	}

	// MARK: - Configurable domain

	func testNormalizeDomainSuffixTrimsLowercasesAndStripsSurroundingDots() {
		XCTAssertEqual(ComposeDNS.normalizeDomainSuffix("  MyDomain.Test.  "), "mydomain.test")
		XCTAssertEqual(ComposeDNS.normalizeDomainSuffix(".internal."), "internal")
	}

	func testNormalizeDomainSuffixRejectsInvalidCandidates() {
		XCTAssertNil(ComposeDNS.normalizeDomainSuffix(""))
		XCTAssertNil(ComposeDNS.normalizeDomainSuffix("   "))
		XCTAssertNil(ComposeDNS.normalizeDomainSuffix("."))
		XCTAssertNil(ComposeDNS.normalizeDomainSuffix("-leading-hyphen.test"))
		XCTAssertNil(ComposeDNS.normalizeDomainSuffix("trailing-hyphen-.test"))
		XCTAssertNil(ComposeDNS.normalizeDomainSuffix("has a space.test"))
		XCTAssertNil(ComposeDNS.normalizeDomainSuffix("under_score.test"), "underscore is not a valid DNS label character")
		XCTAssertNil(ComposeDNS.normalizeDomainSuffix("..double-dot.test"))
	}

	func testDomainSuffixFallsBackToDefaultWhenUnsetOrInvalid() {
		let original: String? = CakedKeyConfig.composeDnsDomain.string()

		defer {
			if let original {
				CakedKeyConfig.composeDnsDomain.set(original)
			} else {
				CakedKeyConfig.composeDnsDomain.removeObject()
			}
		}

		CakedKeyConfig.composeDnsDomain.removeObject()
		XCTAssertEqual(ComposeDNS.domainSuffix, ComposeDNS.defaultDomainSuffix)

		CakedKeyConfig.composeDnsDomain.set("not a valid domain")
		XCTAssertEqual(ComposeDNS.domainSuffix, ComposeDNS.defaultDomainSuffix, "an invalid stored value must never take the resolver down — it falls back instead")

		CakedKeyConfig.composeDnsDomain.set("Custom.Example")
		XCTAssertEqual(ComposeDNS.domainSuffix, "custom.example")
		XCTAssertEqual(ComposeDNS.parseQueryName("myvm.custom.example"), .vm("myvm"))
		XCTAssertNil(ComposeDNS.parseQueryName("myvm.compose.internal"), "once a custom domain is configured, the old default no longer resolves")
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

	func testEncodeResponseANCOUNTMatchesActualRecordsWhenAnAddressIsUnparseable() throws {
		let query = try DNSMessage.parseQuery(self.encodeQuery(name: "mariadb.myapp.compose.internal"))
		// Nothing in the registry produces a malformed address, but the codec itself must never
		// let ANCOUNT overstate what it actually appended, so this covers it directly.
		let response = DNSMessage.encodeResponse(to: query, addresses: ["not-an-ip", "192.168.64.5"], ttlSeconds: 5)
		let echoed = try DNSMessage.parseQuery(Array(response))

		XCTAssertEqual(echoed.name, "mariadb.myapp.compose.internal")
		XCTAssertEqual(UInt16(response[7]), 1, "ANCOUNT must equal the one address that actually encoded, not the two passed in")
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

	// MARK: - Server (gateway-not-present fast path)

	func testStartWithRetryFailsFastWhenGatewayAddressIsNotAssignedToAnInterface() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		// RFC 5737 TEST-NET-3 — reserved for documentation, guaranteed not to be assigned to
		// any real interface on the host running this test.
		let server = ComposeDNSServer(group: group, registry: ComposeDNSRegistry(), bindAddress: "203.0.113.1")
		let start = Date()

		do {
			try await server.startWithRetry()
			XCTFail("startWithRetry should throw when the bind address isn't assigned to any interface")
		} catch let error as ComposeDNSServerError {
			XCTAssertEqual(error, .gatewayNotPresent("203.0.113.1"))
		}

		// The whole point of the fast path is that this does NOT consume startWithRetry's usual
		// ~10s retry budget (maxAttempts * retryDelayNanoseconds) — it must fail on the very
		// first check instead of retrying a condition retrying can't fix.
		XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
	}

	// MARK: - Registry

	func testRegistryReturnsRegisteredAddress() {
		let registry = ComposeDNSRegistry()

		registry.register(project: "myapp", service: "mariadb", ip: "192.168.64.5")

		XCTAssertEqual(registry.address(for: .service(.init(service: "mariadb", project: "myapp"))), "192.168.64.5")
		XCTAssertNil(registry.address(for: .service(.init(service: "phpmyadmin", project: "myapp"))))
	}

	func testRegistryScopesByProject() {
		let registry = ComposeDNSRegistry()

		registry.register(project: "myapp", service: "mariadb", ip: "192.168.64.5")
		registry.register(project: "otherapp", service: "mariadb", ip: "192.168.64.9")

		XCTAssertEqual(registry.address(for: .service(.init(service: "mariadb", project: "myapp"))), "192.168.64.5")
		XCTAssertEqual(registry.address(for: .service(.init(service: "mariadb", project: "otherapp"))), "192.168.64.9")
	}

	func testRegistryUnregisterRemovesOnlyThatEntry() {
		let registry = ComposeDNSRegistry()

		registry.register(project: "myapp", service: "mariadb", ip: "192.168.64.5")
		registry.register(project: "myapp", service: "phpmyadmin", ip: "192.168.64.6")

		XCTAssertTrue(registry.unregister(project: "myapp", service: "mariadb"))
		XCTAssertNil(registry.address(for: .service(.init(service: "mariadb", project: "myapp"))))
		XCTAssertEqual(registry.address(for: .service(.init(service: "phpmyadmin", project: "myapp"))), "192.168.64.6")
		XCTAssertFalse(registry.isEmpty)

		XCTAssertTrue(registry.unregister(project: "myapp", service: "phpmyadmin"))
		XCTAssertTrue(registry.isEmpty)
	}

	func testRegistryReplaceAllPopulatesBothServiceAndVMMaps() {
		let registry = ComposeDNSRegistry()

		registry.replaceAll(
			services: [(project: "myapp", service: "mariadb", ip: "192.168.64.5")],
			vms: [(name: "compose-myapp-mariadb", ip: "192.168.64.5"), (name: "standalone-vm", ip: "192.168.64.9")]
		)

		// The compose-tagged VM resolves both ways — by its compose identity and by its plain
		// VM name — while a VM with no compose tags only resolves by name.
		XCTAssertEqual(registry.address(for: .service(.init(service: "mariadb", project: "myapp"))), "192.168.64.5")
		XCTAssertEqual(registry.address(for: .vm("compose-myapp-mariadb")), "192.168.64.5")
		XCTAssertEqual(registry.address(for: .vm("standalone-vm")), "192.168.64.9")
		XCTAssertNil(registry.address(for: .service(.init(service: "standalone-vm", project: "myapp"))))
	}

	func testRegistryReplaceAllLooksUpVMNamesCaseInsensitively() {
		let registry = ComposeDNSRegistry()

		registry.replaceAll(services: [], vms: [(name: "MyVM", ip: "192.168.64.9")])

		XCTAssertEqual(registry.address(for: .vm("myvm")), "192.168.64.9")
		XCTAssertEqual(registry.address(for: .vm("MYVM")), "192.168.64.9")
	}

	func testRegistryReplaceAllFullyReplacesThePreviousSnapshot() {
		let registry = ComposeDNSRegistry()

		registry.replaceAll(services: [], vms: [(name: "stale-vm", ip: "192.168.64.1")])
		registry.replaceAll(services: [], vms: [(name: "fresh-vm", ip: "192.168.64.2")])

		XCTAssertNil(registry.address(for: .vm("stale-vm")), "a full replace must drop entries not present in the new snapshot")
		XCTAssertEqual(registry.address(for: .vm("fresh-vm")), "192.168.64.2")
	}

	// MARK: - Start/stop (Service menu)

	private func makeTemporaryPIDFile(_ contents: String?) throws -> URL {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ComposeDNSTests-\(UUID().uuidString)", isDirectory: true)

		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

		let pidFile = directory.appendingPathComponent("composedns.pid", isDirectory: false)

		if let contents {
			try contents.write(to: pidFile, atomically: true, encoding: .ascii)
		}

		return pidFile
	}

	func testResolverIsNotRunningWithoutAPIDFile() throws {
		let pidFile = try self.makeTemporaryPIDFile(nil)

		XCTAssertFalse(ComposeDNS.isResolverRunning(pidFile: pidFile))
		XCTAssertThrowsError(try ComposeDNS.stopResolver(pidFile: pidFile))
	}

	func testStopResolverNeverSignalsAProcessThatIsNotCaked() throws {
		// A stale composedns.pid whose PID was reused by an unrelated process — here, this very
		// test process, which is certainly alive and certainly not named `caked`. It must read as
		// "not running" and must not be sent SIGINT (which would end the test run).
		let pidFile = try self.makeTemporaryPIDFile("\(getpid())")

		XCTAssertFalse(ComposeDNS.isResolverRunning(pidFile: pidFile))
		XCTAssertThrowsError(try ComposeDNS.stopResolver(pidFile: pidFile))
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
