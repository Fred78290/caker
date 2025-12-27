import XCTest

@testable import CakedLib
@testable import GRPCLib
@testable import NIOPortForwarding
@testable import cakectl

final class NetworkConfigTests: XCTestCase {
	let interfaces = VZSharedNetwork.networkInterfaces()

	func testTunnelAttached() throws {
		var t = TunnelAttachement(argument: "tcp:/home/user/Downloads/test.sock:/var/run/test.sock")

		XCTAssertNotNil(t)

		XCTAssertEqual(t!.oneOf, .unixDomain(.init(proto: .tcp, host: "/home/user/Downloads/test.sock", guest: "/var/run/test.sock")))
		XCTAssertEqual(t!.unixDomain, .init(proto: .tcp, host: "/home/user/Downloads/test.sock", guest: "/var/run/test.sock"))
		XCTAssertEqual(t!.description, "tcp:/home/user/Downloads/test.sock:/var/run/test.sock")
		XCTAssertEqual(t!.unixDomain?.description, "tcp:/home/user/Downloads/test.sock:/var/run/test.sock")
		XCTAssertNil(t!.mappedPort)

		t = TunnelAttachement(argument: "tcp:~/Downloads/test.sock")
		XCTAssertNil(t)

		t = TunnelAttachement(argument: "tcp:~/Downloads/test.sock:/var/run/test.sock")
		XCTAssertNotNil(t)
		XCTAssertEqual(t!.oneOf, .unixDomain(.init(proto: .tcp, host: "~/Downloads/test.sock", guest: "/var/run/test.sock")))

		t = TunnelAttachement(argument: "2022:22/tcp")
		XCTAssertEqual(t!.oneOf, .forward(.init(proto: .tcp, host: 2022, guest: 22)))
		XCTAssertEqual(t!.mappedPort, MappedPort(host: 2022, guest: 22, proto: .tcp))
		XCTAssertEqual(t!.description, "2022:22/tcp")
		XCTAssertNil(t!.unixDomain)
	}

	func testValidNetwork() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "255.255.255.0", dhcpStart: "10.1.0.1", dhcpEnd: "10.1.0.254", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertNoThrow(try vz.validate(runMode: .user))
	}

	func testInvalidNetmask() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "ABC.255.255.0", dhcpStart: "10.0.0.1", dhcpEnd: "10.0.0.254", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertThrowsError(try vz.validate(runMode: .user)) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("Invalid netmask ABC.255.255.0"))
		}
	}

	func testInvalidGateway() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "255.255.255.0", dhcpStart: "10.0.0", dhcpEnd: "10.0.0.254", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertThrowsError(try vz.validate(runMode: .user)) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("Invalid gateway 10.0.0"))
		}
	}

	func testInvalidDhcpEnd() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "255.255.255.0", dhcpStart: "10.0.0.1", dhcpEnd: "192.168.2", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertThrowsError(try vz.validate(runMode: .user)) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("Invalid dhcp end 192.168.2"))
		}
	}

	func testDhcpEndNotInRangeNetwork() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "255.255.255.0", dhcpStart: "10.0.0.1", dhcpEnd: "192.168.2.254", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertThrowsError(try vz.validate(runMode: .user)) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("dhcp end 192.168.2.254 is not in the range of the network 10.0.0.0/24"))
		}
	}

	func testOverlappedNetwork() throws {
		guard let firstInf = interfaces.first?.value else {
			XCTFail("No network interfaces found")
			return
		}

		let gateway: String = withUnsafeBytes(of: firstInf.base.storage) {
			"\($0[0]).\($0[1]).\($0[2]).1"
		}

		let dhcpEnd: String = withUnsafeBytes(of: firstInf.base.storage) {
			"\($0[0]).\($0[1]).\($0[2]).254"
		}

		let vz = VZSharedNetwork(mode: .shared, netmask: "\(firstInf.bits)".cidrToNetmask(), dhcpStart: gateway, dhcpEnd: dhcpEnd, dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertThrowsError(try vz.validate(runMode: .user)) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("Gateway \(gateway) is already in use"))
		}
	}

}
