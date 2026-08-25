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

	// MARK: - VM image shorthand flags (--macos12, --ubuntu2604, ...)
	//
	// These build their `BuildOptions` via real `BuildOptions.parse([...])` parsing, not the bare
	// `BuildOptions()` designated init or the `name:diskFormat:` convenience one. `imageShorthand`
	// (an `@OptionGroup`) is only safe to read on an instance that went through actual ArgumentParser
	// parsing — reading it on one built any other way crashes, by ArgumentParser's own design (see
	// `imageShorthand`'s doc comment in BuildOptions.swift). `.parse([...])` is exactly what `caked
	// build`/`cakectl build` do under the hood, so this also exercises the real parsing path.

	func testNoShorthandFlagLeavesImageIdUnset() throws {
		var options = try BuildOptions.parse(["vm"])

		try options.validate(remote: false)

		XCTAssertNil(options.imageId)
	}

	func testSingleShorthandFlagResolvesIntoImageId() throws {
		var options = try BuildOptions.parse(["--macos12", "vm"])

		try options.validate(remote: false)

		XCTAssertEqual(options.imageId, "macos12")
		XCTAssertEqual(options.selectedImageID, "macos12")
	}

	func testTwoShorthandFlagsFailValidationWithAClearError() throws {
		// The ambiguity check lives in `BuildOptions.validate()` (ArgumentParser's own zero-arg
		// post-parse hook — see its doc comment), which runs automatically as part of parsing
		// itself, so the throw surfaces from `.parse(...)` directly rather than from a later
		// explicit `validate(remote:)` call. ArgumentParser wraps the original `ValidationError` in
		// its own internal (non-public) `ParserError`, so match on the rendered message instead of
		// trying to unwrap that type.
		XCTAssertThrowsError(try BuildOptions.parse(["--macos12", "--ubuntu2604", "vm"])) { error in
			let message = String(describing: error)

			XCTAssertTrue(message.contains("macos12"), "Error should name the conflicting flags: \(message)")
			XCTAssertTrue(message.contains("ubuntu2604"), "Error should name the conflicting flags: \(message)")
		}
	}
}
