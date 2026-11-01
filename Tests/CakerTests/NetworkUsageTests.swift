import XCTest

@testable import CakedLib
@testable import GRPCLib

/// The *used* (referenced) versus *active* (running) instance counts of a network, and the per-network
/// `dns` flag, travel through the gRPC model, the `networks list` output and the shared-network config.
/// Counting the instances themselves needs real VM storage, so only the conversions are covered here.
final class NetworkUsageTests: XCTestCase {
	private func makeNetwork(used: Int, active: Int, dns: Bool) -> BridgedNetwork {
		BridgedNetwork(
			name: "shared-dev",
			mode: .shared,
			description: "dev network",
			gateway: "192.168.105.1/24",
			dhcpEnd: "192.168.105.254",
			dhcpLease: "300",
			interfaceID: "en0",
			endpoint: "",
			running: true,
			managed: true,
			dns: dns,
			usedBy: BridgedNetwork.NetworkUsage(used: used, active: active)
		)
	}

	func testUsedAndActiveSurviveTheGrpcRoundTrip() {
		let wire = self.makeNetwork(used: 3, active: 1, dns: true).caked

		XCTAssertEqual(wire.used, 3)
		XCTAssertEqual(wire.active, 1)
		XCTAssertTrue(wire.dns)

		let back = BridgedNetwork(wire)

		XCTAssertEqual(back.usedBy, BridgedNetwork.NetworkUsage(used: 3, active: 1))
		XCTAssertTrue(back.dns)
		XCTAssertTrue(back.running)
	}

	func testActiveDefaultsToZeroForACakedThatDoesNotSendIt() {
		// An older caked only sends `used`; proto3 gives `active` its default, 0.
		var wire = Caked_NetworkInfo()

		wire.name = "legacy"
		wire.used = 2

		let network = BridgedNetwork(wire)

		XCTAssertEqual(network.usedBy.used, 2)
		XCTAssertEqual(network.usedBy.active, 0)
		XCTAssertFalse(network.dns)
	}

	func testListOutputKeepsUsedAndActiveSeparate() {
		let flat = FlatBridgedNetwork(self.makeNetwork(used: 3, active: 1, dns: false))

		XCTAssertEqual(flat.usedBy, 3)
		XCTAssertEqual(flat.active, 1)
		XCTAssertEqual(flat.name, "shared-dev")
	}

	func testSharedNetworkEqualityTreatsAMissingDnsAsDisabled() {
		var withoutFlag = VZSharedNetwork(netmask: "255.255.255.0", dhcpStart: "192.168.105.1", dhcpEnd: "192.168.105.254")
		let disabled = VZSharedNetwork(netmask: "255.255.255.0", dhcpStart: "192.168.105.1", dhcpEnd: "192.168.105.254", dns: false)
		let enabled = VZSharedNetwork(netmask: "255.255.255.0", dhcpStart: "192.168.105.1", dhcpEnd: "192.168.105.254", dns: true)

		// A config written before the flag existed decodes with `dns == nil`.
		withoutFlag.dns = nil

		XCTAssertEqual(withoutFlag, disabled)
		XCTAssertNotEqual(withoutFlag, enabled)
	}

	func testSharedNetworkDoesNotEnableDnsByDefault() {
		let network = VZSharedNetwork(netmask: "255.255.255.0", dhcpStart: "192.168.105.1", dhcpEnd: "192.168.105.254")

		XCTAssertEqual(network.dns, false)
	}
}
