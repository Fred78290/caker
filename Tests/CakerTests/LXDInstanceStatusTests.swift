import GRPCLib
import XCTest

@testable import caked

/// Regression coverage for `LXDInstance.from(_:)`'s status mapping — the LXD REST `/1.0/instances`
/// list endpoint used to have no `"provisioning"` case at all (unlike the per-instance `/state`
/// endpoint's own `lxdStatusFrom(state:)`, which already handled it), so a provisioning VM showed
/// up as plain "Stopped" in the webui's instance list/dashboard.
final class LXDInstanceStatusTests: XCTestCase {
	private func makeInfo(state: String) -> VirtualMachineInfo {
		var info = Caked_VirtualMachineInfo()
		info.name = "test-vm"
		info.state = state
		return VirtualMachineInfo(info)
	}

	func testProvisioningStateMapsToProvisioningStatus() {
		let instance = LXDInstance.from(makeInfo(state: "provisioning"))

		XCTAssertEqual(instance.status, "Provisioning")
		XCTAssertEqual(instance.statusCode, 103)
	}

	func testRunningStateMapsToRunningStatus() {
		let instance = LXDInstance.from(makeInfo(state: "running"))

		XCTAssertEqual(instance.status, "Running")
		XCTAssertEqual(instance.statusCode, 103)
	}

	func testPausedStateMapsToFrozenStatus() {
		let instance = LXDInstance.from(makeInfo(state: "paused"))

		XCTAssertEqual(instance.status, "Frozen")
		XCTAssertEqual(instance.statusCode, 110)
	}

	func testStoppedStateMapsToStoppedStatus() {
		let instance = LXDInstance.from(makeInfo(state: "stopped"))

		XCTAssertEqual(instance.status, "Stopped")
		XCTAssertEqual(instance.statusCode, 102)
	}
}
