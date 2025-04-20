import XCTest

@testable import caked
@testable import cakectl
@testable import GRPCLib

final class NetworkConfigTests: XCTestCase {
	let interfaces = VZSharedNetwork.networkInterfaces()

	func testValidNetwork() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "255.255.255.0", dhcpStart: "10.1.0.1", dhcpEnd: "10.1.0.254", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertNoThrow(try vz.validate())
	}

	func testInvalidNetmask() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "ABC.255.255.0", dhcpStart: "10.0.0.1", dhcpEnd: "10.0.0.254", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertThrowsError(try vz.validate()) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("Invalid netmask ABC.255.255.0"))
		}
	}

	func testInvalidGateway() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "255.255.255.0", dhcpStart: "10.0.0", dhcpEnd: "10.0.0.254", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertThrowsError(try vz.validate()) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("Invalid gateway 10.0.0"))
		}
	}

	func testInvalidDhcpEnd() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "255.255.255.0", dhcpStart: "10.0.0.1", dhcpEnd: "192.168.2", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertThrowsError(try vz.validate()) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("Invalid dhcp end 192.168.2"))
		}
	}

	func testDhcpEndNotInRangeNetwork() throws {
		let vz = VZSharedNetwork(mode: .shared, netmask: "255.255.255.0", dhcpStart: "10.0.0.1", dhcpEnd: "192.168.2.254", dhcpLease: nil, interfaceID: UUID().uuidString, nat66Prefix: nil)

		XCTAssertThrowsError(try vz.validate()) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("dhcp end 192.168.2.254 is not in the range of the network 10.0.0.0/24"))
		}
	}

	func testOverlappedNetwork() throws {
		guard let firstInf = interfaces.first else {
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

		XCTAssertThrowsError(try vz.validate()) { error in
			XCTAssertEqual(error as? ServiceError, ServiceError("Gateway \(gateway) is already in use"))
		}
	}

}
