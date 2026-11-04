//
//  AppStoreGuestDNSTests.swift
//  CakerTests
//

import Foundation
import XCTest

@testable import CakedLib

final class AppStoreGuestDNSTests: XCTestCase {
	private func syntaxIsValid(_ script: String) throws -> Bool {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sh")

		defer { try? FileManager.default.removeItem(at: url) }

		try script.write(to: url, atomically: true, encoding: .utf8)

		let process = Process()

		process.executableURL = URL(fileURLWithPath: "/bin/sh")
		process.arguments = ["-n", url.path(percentEncoded: false)]

		try process.run()
		process.waitUntilExit()

		return process.terminationStatus == 0
	}

	func testFragmentsAreEmptyInTheFullBuildAndCompleteInTheAppStoreBuild() throws {
		let cloud = AppStoreGuestDNS.cloudInitFragment(domain: "compose.internal", ip: "192.168.32.1", port: "28053")
		let ssh = AppStoreGuestDNS.sshFragment(domain: "compose.internal", ip: "192.168.32.1", port: "28053")

		if AppStoreGuestDNS.needsGuestWiring {
			for fragment in [cloud, ssh] {
				XCTAssertTrue(fragment.contains("COMPOSEDONS_DOMAIN_SUFFIX=\"compose.internal\""))
				XCTAssertTrue(fragment.contains("COMPOSEDONS_DNS_IP=\"192.168.32.1\""))
				XCTAssertTrue(fragment.contains("COMPOSEDONS_DNS_PORT=\"28053\""))
				XCTAssertTrue(fragment.contains("dnsmasq"))
				XCTAssertTrue(try syntaxIsValid(fragment), fragment)
			}
		} else {
			XCTAssertEqual(cloud, "")
			XCTAssertEqual(ssh, "")
		}
	}

	func testInstallScriptsRenderToValidShellInBothBuilds() throws {
		let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/cakedlib/Resources")
		let fragment = AppStoreGuestDNS.cloudInitFragment(domain: "compose.internal", ip: "192.168.32.1", port: "28053")
		let cloud = String(format: try String(contentsOf: directory.appendingPathComponent("cloudinit-install-cakeagent.sh"), encoding: .utf8), "5000", "", "ca", "key", "pem", fragment)
		let ssh = String(
			format: try String(contentsOf: directory.appendingPathComponent("ssh-install-cakeagent.sh"), encoding: .utf8), "admin", "snapshot", "5000", "", "ssh-rsa AAAA", "ca", "pem", "key",
			AppStoreGuestDNS.sshFragment(domain: "compose.internal", ip: "192.168.32.1", port: "28053"))

		XCTAssertTrue(try syntaxIsValid(cloud))
		XCTAssertTrue(try syntaxIsValid(ssh))
		XCTAssertEqual(cloud.contains("dnsmasq"), fragment.isEmpty == false)
		XCTAssertEqual(ssh.contains("dnsmasq"), fragment.isEmpty == false)
		XCTAssertFalse(cloud.contains("%@") || ssh.contains("%9$@"), "every placeholder is filled")
	}
}
