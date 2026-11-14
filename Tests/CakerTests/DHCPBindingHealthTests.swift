//
//  DHCPBindingHealthTests.swift
//  CakerTests
//
//  The DHCP server captures on a network's bridge, which vmnet destroys when the last guest detaches and creates again
//  for the next one. These cover the decision to re-open the capture (the BPF part needs root and a real bridge).
//

import XCTest

@testable import CakedLib

final class DHCPBindingHealthTests: XCTestCase {
	private let bridge = DHCPBinding(interface: "bridge100", hardwareAddress: [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc])

	private func needsRebind(current: DHCPBinding?, descriptorAttached: Bool = true, readFailed: Bool = false) -> Bool {
		DHCPBindingHealth.needsRebind(bound: self.bridge, current: current, descriptorAttached: descriptorAttached, readFailed: readFailed)
	}

	func testAnUnchangedBridgeKeepsItsCapture() {
		XCTAssertFalse(self.needsRebind(current: self.bridge))
	}

	func testABridgeThatIsGoneMeansReattaching() {
		// All guests stopped: nothing carries the gateway address any more.
		XCTAssertTrue(self.needsRebind(current: nil))
	}

	func testABridgeRecreatedUnderAnotherNameMeansReattaching() {
		XCTAssertTrue(self.needsRebind(current: DHCPBinding(interface: "bridge101", hardwareAddress: self.bridge.hardwareAddress)))
	}

	func testABridgeRecreatedWithTheSameNameButAnotherHardwareAddressMeansReattaching() {
		XCTAssertTrue(self.needsRebind(current: DHCPBinding(interface: "bridge100", hardwareAddress: [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbd])))
	}

	func testADescriptorTheKernelDetachedMeansReattachingEvenIfTheBridgeLooksTheSame() {
		// The same name and address can come back with the next guest; the old descriptor is dead all the same.
		XCTAssertTrue(self.needsRebind(current: self.bridge, descriptorAttached: false))
	}

	func testAFailedReadMeansReattaching() {
		XCTAssertTrue(self.needsRebind(current: self.bridge, readFailed: true))
	}
}
