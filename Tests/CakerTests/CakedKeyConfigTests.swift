//
//  CakedKeyConfigTests.swift
//  CakerTests
//

import XCTest
import Foundation
import GRPCLib

@testable import CakedLib

/// Reads and writes the real `UserDefaults.shared` store, like `ComposeDNSTests`: every key's
/// raw value is saved in `setUp` and put back in `tearDown`.
final class CakedKeyConfigTests: XCTestCase {
	private var saved: [CakedKeyConfig: Any] = [:]

	override func setUp() {
		super.setUp()

		for key in CakedKeyConfig.allCases {
			if let value = UserDefaults.shared.object(forKey: key.rawValue) {
				saved[key] = value
			}
		}
	}

	override func tearDown() {
		for key in CakedKeyConfig.allCases {
			if let value = saved[key] {
				UserDefaults.shared.set(value, forKey: key.rawValue)
			} else {
				key.removeObject()
			}
		}

		saved = [:]
		super.tearDown()
	}

	// MARK: - Defaults

	func testDefaultValuePerKey() {
		XCTAssertEqual(CakedKeyConfig.imdsEnabled.defaultValue as? Bool, true)
		XCTAssertEqual(CakedKeyConfig.primaryName.defaultValue as? String, "primary")
		XCTAssertEqual(CakedKeyConfig.composeDnsDomain.defaultValue as? String, "compose.internal")

		for key in [CakedKeyConfig.bridgedNetwork, .driver, .imageMirror, .passphrase, .privilegedMounts, .cakeHome] {
			XCTAssertNil(key.defaultValue, key.rawValue)
		}

		XCTAssertEqual(CakedKeyConfig.allCases.filter(\.isBoolean), [.imdsEnabled])
	}

	func testUnsetKeysReturnTheirDefault() {
		CakedKeyConfig.imdsEnabled.removeObject()
		CakedKeyConfig.primaryName.removeObject()
		CakedKeyConfig.composeDnsDomain.removeObject()
		CakedKeyConfig.bridgedNetwork.removeObject()

		XCTAssertTrue(CakedKeyConfig.imdsEnabled.bool())
		XCTAssertTrue(IMDSNetworkInterface.imdsEnabled, "IMDS is on until it is turned off, as in Caker.app's settings")
		XCTAssertEqual(CakedKeyConfig.primaryName.string(), "primary")
		XCTAssertEqual(GetOptions.primaryName, "primary")
		XCTAssertEqual(CakedKeyConfig.composeDnsDomain.string(), "compose.internal")
		XCTAssertEqual(ComposeDNS.domainSuffix, ComposeDNS.defaultDomainSuffix)
		XCTAssertNil(CakedKeyConfig.bridgedNetwork.string(), "no default: unset means no bridged interface")
	}

	func testExplicitDefaultWinsOverTheKeyDefault() {
		CakedKeyConfig.imdsEnabled.removeObject()
		CakedKeyConfig.primaryName.removeObject()

		XCTAssertFalse(CakedKeyConfig.imdsEnabled.bool(false))
		XCTAssertEqual(CakedKeyConfig.primaryName.string("other"), "other")
	}

	func testStoredValueWinsOverTheDefault() {
		CakedKeyConfig.imdsEnabled.set(false)
		CakedKeyConfig.primaryName.set("dev")

		XCTAssertFalse(CakedKeyConfig.imdsEnabled.bool())
		XCTAssertEqual(CakedKeyConfig.primaryName.string(), "dev")
	}

	func testRawGetDoesNotFallBackToTheDefault() {
		CakedKeyConfig.primaryName.removeObject()

		XCTAssertNil(CakedKeyConfig.primaryName.get() as String?)
		XCTAssertFalse(CakedKeyConfig.primaryName.exists())
	}

	// MARK: - Booleans

	func testParseBool() {
		for value in ["true", "TRUE", "yes", "on", "1", " true "] {
			XCTAssertEqual(CakedKeyConfig.parseBool(value), true, value)
		}

		for value in ["false", "No", "off", "0"] {
			XCTAssertEqual(CakedKeyConfig.parseBool(value), false, value)
		}

		for value in ["", "maybe", "2"] {
			XCTAssertNil(CakedKeyConfig.parseBool(value), value)
		}
	}

	func testBooleanStoredAsStringIsParsed() {
		// What `set` stored before it learned about booleans.
		CakedKeyConfig.imdsEnabled.set("false")
		XCTAssertFalse(CakedKeyConfig.imdsEnabled.bool())

		CakedKeyConfig.imdsEnabled.set("YES")
		XCTAssertTrue(CakedKeyConfig.imdsEnabled.bool())

		CakedKeyConfig.imdsEnabled.set("garbage")
		XCTAssertTrue(CakedKeyConfig.imdsEnabled.bool(), "an unrecognized string falls back to the default")
	}

	// MARK: - What `get` prints

	func testStringValuePrintsDefaultsAndBooleansAsTrueFalse() {
		CakedKeyConfig.imdsEnabled.removeObject()
		CakedKeyConfig.primaryName.removeObject()
		CakedKeyConfig.composeDnsDomain.removeObject()
		CakedKeyConfig.bridgedNetwork.removeObject()

		XCTAssertEqual(CakedKeyConfig.imdsEnabled.stringValue, "true")
		XCTAssertEqual(CakedKeyConfig.primaryName.stringValue, "primary")
		XCTAssertEqual(CakedKeyConfig.composeDnsDomain.stringValue, "compose.internal")
		XCTAssertNil(CakedKeyConfig.bridgedNetwork.stringValue)

		// As Caker.app's `@AppStorage` stores it: a number, which `UserDefaults.string(forKey:)` reads as "0".
		CakedKeyConfig.imdsEnabled.set(false)
		XCTAssertEqual(CakedKeyConfig.imdsEnabled.stringValue, "false")

		CakedKeyConfig.imdsEnabled.set("true")
		XCTAssertEqual(CakedKeyConfig.imdsEnabled.stringValue, "true")
	}

	// MARK: - `set`

	func testSetStoresBooleanKeysAsBool() throws {
		try SetOptions.parse(["client.imds-enabled=false"]).run()

		let stored = UserDefaults.shared.object(forKey: CakedKeyConfig.imdsEnabled.rawValue)
		XCTAssertNil(stored as? String, "stored as a Bool, the type @AppStorage reads, not as a string")
		XCTAssertEqual(stored as? Bool, false)
		XCTAssertFalse(IMDSNetworkInterface.imdsEnabled)

		try SetOptions.parse(["client.imds-enabled=yes"]).run()
		XCTAssertEqual(UserDefaults.shared.object(forKey: CakedKeyConfig.imdsEnabled.rawValue) as? Bool, true)
	}

	func testSetRejectsANonBooleanValueForABooleanKey() throws {
		CakedKeyConfig.imdsEnabled.set(false)

		XCTAssertThrowsError(try SetOptions.parse(["client.imds-enabled=maybe"]).run())
		XCTAssertFalse(CakedKeyConfig.imdsEnabled.bool(), "a rejected value leaves the stored one alone")
	}

	func testSetStoresOtherKeysAsStrings() throws {
		try SetOptions.parse(["client.primary-name=dev"]).run()

		XCTAssertEqual(CakedKeyConfig.primaryName.get() as String?, "dev")
		XCTAssertEqual(CakedKeyConfig.primaryName.stringValue, "dev")
	}
}
