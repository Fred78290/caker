import XCTest

@testable import CakedLib
@testable import GRPCLib

/// Covers `VMImageCatalog.resolveShorthand(_:)`, the id -> URL/imageSource/macosVersion
/// resolution `VMBuilder.buildVM` uses for the `--<id>` shorthand flags generated in
/// `Sources/Grpc/options/VMImageShorthandFlags.swift`. See `VMImageCatalogURLTests.swift` for
/// catalog-shape/reachability coverage — this file is specifically about the resolution logic.
final class VMImageCatalogResolutionTests: XCTestCase {
	func testIPSWIdResolvesToIPSWSourceAndMatchingMacOSVersion() throws {
		let catalog = VMImageCatalog.shared

		let resolution = try XCTUnwrap(catalog.resolveShorthand("macos12"))

		XCTAssertEqual(resolution.url, catalog.current.ipsw.first(where: { $0.id == "macos12" })?.url)
		XCTAssertEqual(resolution.imageSource, .ipsw)
		XCTAssertEqual(resolution.macosVersion, .macos12)
	}

	func testISOIdResolvesToISOSourceWithNoMacOSVersion() throws {
		let catalog = VMImageCatalog.shared

		let resolution = try XCTUnwrap(catalog.resolveShorthand("ubuntu2604Desktop"))

		XCTAssertEqual(resolution.url, catalog.current.iso.first(where: { $0.id == "ubuntu2604Desktop" })?.url)
		XCTAssertEqual(resolution.imageSource, .iso)
		XCTAssertNil(resolution.macosVersion)
	}

	func testCloudIdResolvesToQcow2SourceWithNoMacOSVersion() throws {
		let catalog = VMImageCatalog.shared

		let resolution = try XCTUnwrap(catalog.resolveShorthand("ubuntu2604"))

		XCTAssertEqual(resolution.url, catalog.current.cloud.first(where: { $0.id == "ubuntu2604" })?.url)
		XCTAssertEqual(resolution.imageSource, .qcow2)
		XCTAssertNil(resolution.macosVersion)
	}

	/// `centos9`/`centos10` are the one known ambiguity: they appear in both the `iso` and
	/// `cloud` categories under the same id. Resolution always prefers `iso` — see
	/// `VMImageCatalog.resolveShorthand`'s doc comment.
	func testAmbiguousCentosIdPrefersISOOverCloud() throws {
		let catalog = VMImageCatalog.shared

		let resolution = try XCTUnwrap(catalog.resolveShorthand("centos9"))

		XCTAssertEqual(resolution.url, catalog.current.iso.first(where: { $0.id == "centos9" })?.url)
		XCTAssertEqual(resolution.imageSource, .iso)
	}

	func testUnknownIdResolvesToNil() {
		let catalog = VMImageCatalog.shared

		XCTAssertNil(catalog.resolveShorthand("not-a-real-catalog-id"))
	}
}
