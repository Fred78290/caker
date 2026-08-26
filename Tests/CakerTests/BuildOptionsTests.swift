import ArgumentParser
import XCTest

@testable import GRPCLib

final class BuildOptionsTests: XCTestCase {
	func testProvisionVarsDictHandlesDuplicateKeys() {
		var options = BuildOptions()
		options.provisionVars = [
			"username=first",
			"role=admin",
			"username=second",
		]

		XCTAssertEqual(options.provisionVarsDict["username"], "second")
		XCTAssertEqual(options.provisionVarsDict["role"], "admin")
	}

	// MARK: - VM image catalog alias (--alias <id>)
	//
	// These build their `BuildOptions` via real `BuildOptions.parse([...])` parsing, exactly what
	// `caked build`/`cakectl build` do under the hood, so this exercises the real parsing path.

	func testNoAliasLeavesImageIdUnset() throws {
		var options = try BuildOptions.parse(["vm"])

		try options.validate(remote: false)

		XCTAssertNil(options.imageId)
	}

	func testAliasResolvesIntoImageId() throws {
		var options = try BuildOptions.parse(["--alias", "macos12", "vm"])

		try options.validate(remote: false)

		XCTAssertEqual(options.imageId, "macos12")
	}
}
