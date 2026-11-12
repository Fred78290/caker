import Foundation
import XCTest

@testable import CakedLib
@testable import GRPCLib

final class InternalDHCPSettingTests: XCTestCase {
	func testKeyFollowsTheLocalNamespaceAndIsABoolean() {
		XCTAssertEqual(CakedKeyConfig.useInternalDHCPServer.rawValue, "local.use-dhcp-server")
		XCTAssertTrue(CakedKeyConfig.useInternalDHCPServer.isBoolean)
		XCTAssertEqual(CakedKeyConfig.useInternalDHCPServer.defaultValue as? Bool, CakedKeyConfig.defaultUseInternalDHCPServer)
	}

	func testPrivilegedLaunchHandsDownTheChoiceToTheRootProcess() throws {
		let original: Bool? = CakedKeyConfig.useInternalDHCPServer.get()

		defer {
			if let original {
				CakedKeyConfig.useInternalDHCPServer.set(original)
			} else {
				CakedKeyConfig.useInternalDHCPServer.removeObject()
			}
		}

		guard ProcessInfo.processInfo.environment["CAKED_VMNET_DHCP"] == nil, let sudo = URL.binary("sudo") else {
			throw XCTSkip("needs an unset CAKED_VMNET_DHCP and sudo")
		}

		_ = sudo

		CakedKeyConfig.useInternalDHCPServer.set(false)
		let off = try SudoCaked.privilegedLaunch(binary: URL(fileURLWithPath: "/usr/bin/true"), runMode: .user)
		XCTAssertEqual(off.environment["CAKED_VMNET_DHCP"], "vmnet")

		CakedKeyConfig.useInternalDHCPServer.set(true)
		let on = try SudoCaked.privilegedLaunch(binary: URL(fileURLWithPath: "/usr/bin/true"), runMode: .user)
		XCTAssertNil(on.environment["CAKED_VMNET_DHCP"])
	}
}
