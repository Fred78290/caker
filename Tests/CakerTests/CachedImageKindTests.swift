import XCTest

@testable import CakedLib
@testable import GRPCLib

/// Covers `CachedImageKind`, the cache `type()` string -> image source mapping `caker`'s image
/// cache view uses to decide whether (and how) a VM can be created from a cached entry.
final class CachedImageKindTests: XCTestCase {
	func testCacheTypesMapToImageSources() {
		XCTAssertEqual(CachedImageKind(cacheType: "cloud-images").imageSource, .qcow2)
		XCTAssertEqual(CachedImageKind(cacheType: "iso").imageSource, .iso)
		XCTAssertEqual(CachedImageKind(cacheType: "ipsw").imageSource, .ipsw)
		XCTAssertEqual(CachedImageKind(cacheType: "oci").imageSource, .oci)
		XCTAssertEqual(CachedImageKind(cacheType: "simplestream").imageSource, .stream)
	}

	func testKindsThatCannotBeBuiltFromCacheAreDisabled() {
		for type in ["raw-images", "OCIs", "templates", "something-new"] {
			let kind = CachedImageKind(cacheType: type)

			XCTAssertNil(kind.imageSource, type)
			XCTAssertFalse(kind.canCreateVirtualMachine, type)
		}
	}

	func testUnknownTypeKeepsItsName() {
		XCTAssertEqual(CachedImageKind(cacheType: "something-new"), .unknown("something-new"))
	}

	func testOnlyIPSWIsDarwin() {
		XCTAssertEqual(CachedImageKind.ipsw.os, .darwin)
		XCTAssertEqual(CachedImageKind.iso.os, .linux)
		XCTAssertEqual(CachedImageKind.cloudImage.os, .linux)
	}

	func testTemplatesAreNotListed() {
		XCTAssertFalse(CachedImageKind.template.isListed)
		XCTAssertTrue(CachedImageKind.cloudImage.isListed)
		XCTAssertTrue(CachedImageKind.rawImage.isListed)
	}
}
