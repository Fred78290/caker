//
//  AgentHandlerTests.swift
//  CakerTests
//

import Foundation
import GRPCLib
import XCTest

@testable import CakedLib

final class AgentHandlerTests: XCTestCase {
	func testSameVersionIsUpToDate() {
		let reply = AgentVersionReply(name: "vm", running: true, version: CAKEAGENT_VERSION)

		XCTAssertTrue(reply.upToDate)
		XCTAssertFalse(AgentHandler.updateIsNeeded(reply, force: false))
	}

	func testOtherVersionNeedsUpdate() {
		let reply = AgentVersionReply(name: "vm", running: true, version: "v0.0.1", expected: "v1.0.2")

		XCTAssertFalse(reply.upToDate)
		XCTAssertTrue(AgentHandler.updateIsNeeded(reply, force: false))
	}

	func testMissingOrEmptyVersionNeedsUpdate() {
		XCTAssertNil(AgentVersionReply(name: "vm", running: true, version: "").version)
		XCTAssertTrue(AgentHandler.updateIsNeeded(AgentVersionReply(name: "vm", running: true, version: nil), force: false))
		XCTAssertTrue(AgentHandler.updateIsNeeded(AgentVersionReply(name: "vm", running: true, version: ""), force: false))
	}

	func testForceInstallsEvenWhenCurrent() {
		let reply = AgentVersionReply(name: "vm", running: true, version: CAKEAGENT_VERSION)

		XCTAssertTrue(AgentHandler.updateIsNeeded(reply, force: true))
	}

	func testUpToDateOutcomeIsASuccessThatInstalledNothing() {
		let outcome = AgentHandler.upToDate(AgentVersionReply(name: "vm", running: true, version: CAKEAGENT_VERSION))

		XCTAssertTrue(outcome.success)
		XCTAssertTrue(outcome.skipped)
		XCTAssertFalse(outcome.installed)
	}

	func testFailedInstallIsNotASuccess() {
		let outcome = AgentInstallReply(InstalledAgentReply(name: "vm", installed: false, reason: "VM is not running"))

		XCTAssertFalse(outcome.success)
		XCTAssertEqual(outcome.reason, "VM is not running")
	}

	func testInstalledReplyWithoutReasonStillExplainsItself() {
		let outcome = AgentInstallReply(InstalledAgentReply(name: "vm", installed: true, reason: ""))

		XCTAssertTrue(outcome.success)
		XCTAssertTrue(outcome.reason.contains(CAKEAGENT_VERSION))
	}

	func testVersionOfAnUnknownVMReportsNotRunningInsteadOfThrowing() {
		let reply = AgentHandler.version(name: "no-such-vm-\(UUID().uuidString)", runMode: .user)

		XCTAssertFalse(reply.running)
		XCTAssertNil(reply.version)
		XCTAssertFalse(reply.upToDate)
	}
}
