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
}
