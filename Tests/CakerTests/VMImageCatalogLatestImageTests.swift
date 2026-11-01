import XCTest

@testable import CakedLib

final class VMImageCatalogLatestImageTests: XCTestCase {
	private let manifest = """
		-----BEGIN PGP SIGNED MESSAGE-----
		Hash: SHA256

		# Latest as of Sun, 01 Nov 2026 10:30:01 +0000
		# ts=1793529001
		di-amd64-cloudinit-20261025T170057Z.qcow2 1188036608
		-----BEGIN PGP SIGNATURE-----

		iQFPBAEBCAA5FiEEU05CCatJ7uHBnZYWLERpXbn2BD0FAmrnF0AbFIAAAAAABAAO
		-----END PGP SIGNATURE-----
		"""

	func testLatestImageNameSkipsTheClearSignArmourAndComments() {
		XCTAssertEqual(VMImageCatalog.latestImageName(manifest: manifest), "di-amd64-cloudinit-20261025T170057Z.qcow2")
	}

	func testLatestImageNameRejectsAnythingButABareImageName() {
		XCTAssertNil(VMImageCatalog.latestImageName(manifest: "../../evil.qcow2 1\n"))
		XCTAssertNil(VMImageCatalog.latestImageName(manifest: "di-amd64/../x.qcow2 1\n"))
		XCTAssertNil(VMImageCatalog.latestImageName(manifest: "# nothing here\n"))
		XCTAssertNil(VMImageCatalog.latestImageName(manifest: "other.iso 1\n"))
	}

	func testReplacingCloudURLChangesOnlyTheNamedEntry() throws {
		let catalog = VMImageCatalog.loadBundled().current

		guard let before = catalog.cloud.first(where: { $0.id == "gentoo" }), let other = catalog.cloud.first(where: { $0.id != "gentoo" }) else {
			return XCTFail("the bundled catalog has a gentoo entry and others")
		}

		let replaced = catalog.replacingCloudURL(id: "gentoo", with: "https://example.com/new.qcow2")

		XCTAssertEqual(replaced.cloud.first(where: { $0.id == "gentoo" })?.url, "https://example.com/new.qcow2")
		XCTAssertEqual(replaced.cloud.first(where: { $0.id == "gentoo" })?.minCPU, before.minCPU)
		XCTAssertEqual(replaced.cloud.first(where: { $0.id == other.id })?.url, other.url)
		XCTAssertEqual(catalog.replacingCloudURL(id: "unknown", with: "https://example.com/x").cloud.count, catalog.cloud.count)
	}

	func testGentooManifestsAreTheOnesFromTheCatalogDirectories() {
		let sources = VMImageCatalog.latestImageSources

		XCTAssertEqual(sources.map(\.arch).sorted(), ["amd64", "arm64"])
		XCTAssertTrue(sources.allSatisfy { $0.manifest.scheme == "https" && $0.manifest.lastPathComponent == "latest-di-\($0.arch)-cloudinit.txt" })
	}

	/// Reads the real manifest of this host's architecture; skipped when the network is unreachable.
	func testRefreshLatestImagesResolvesGentoo() async throws {
		VMImageCatalog.resetLatestImages()
		defer { VMImageCatalog.resetLatestImages() }

		await VMImageCatalog.refreshLatestImages()

		guard let url = VMImageCatalog.loadBundled().applyingLatestImages().current.cloud.first(where: { $0.id == "gentoo" })?.url else {
			return XCTFail("gentoo entry")
		}

		try XCTSkipIf(url == VMImageCatalog.loadBundled().current.cloud.first(where: { $0.id == "gentoo" })?.url && url.contains("current-di-") == false, "manifest unreachable")
		XCTAssertTrue(url.contains("/current-di-"), url)
		XCTAssertTrue(url.hasSuffix(".qcow2"), url)
		print("GENTOO LATEST:", url)
	}
}
