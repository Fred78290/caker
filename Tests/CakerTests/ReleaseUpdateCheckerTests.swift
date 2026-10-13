import XCTest

@testable import CakedLib

/// Covers `ReleaseUpdateChecker`, the appcast check behind `caked check-update`/`cakectl check-update`.
/// Nothing here touches the network: the feed is parsed from inline XML.
final class ReleaseUpdateCheckerTests: XCTestCase {
	// The shape `Scripts/sparkle-sign-release.sh` publishes: version attributes on the enclosure,
	// a French pubDate, no item <link>.
	private let signedReleaseFeed = """
		<?xml version="1.0" encoding="utf-8"?>
		<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
		  <channel>
		    <title>Caker Updates</title>
		    <link>https://github.com/Fred78290/caker</link>
		    <item>
		      <title>Caker 1.0.3657</title>
		      <description><![CDATA[<h2>Caker 1.0.3657</h2><ul><li>fix</li></ul>]]></description>
		      <pubDate>dim., 11 oct. 2026 15:49:54 +0000</pubDate>
		      <enclosure url="https://github.com/Fred78290/caker/releases/download/v1.0.3657/Caker.dmg" sparkle:version="1.0.3657" sparkle:shortVersionString="1.0.3657" type="application/octet-stream" length="198948485"/>
		    </item>
		  </channel>
		</rss>
		"""

	// The shape `Scripts/sparkle-generate-appcast-xml.sh` produces: version elements, item links,
	// minimum macOS and sparkle:os.
	private let generatedFeed = """
		<?xml version="1.0" encoding="utf-8"?>
		<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
		    <channel>
		        <title>Caker Updates</title>
		        <link>https://github.com/Fred78290/caker</link>
		        <item>
		            <title>v1.0.3600</title>
		            <link>https://github.com/Fred78290/caker/releases/tag/v1.0.3600</link>
		            <pubDate>Mon, 05 Oct 2026 10:00:00 +0000</pubDate>
		            <sparkle:version>1.0.3600</sparkle:version>
		            <sparkle:shortVersionString>1.0.3600</sparkle:shortVersionString>
		            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
		            <enclosure url="https://example.invalid/v1.0.3600/Caker.dmg" length="1" type="application/x-apple-diskimage" sparkle:os="macos" />
		        </item>
		        <item>
		            <title>v1.0.3700</title>
		            <link>https://github.com/Fred78290/caker/releases/tag/v1.0.3700</link>
		            <sparkle:version>1.0.3700</sparkle:version>
		            <sparkle:minimumSystemVersion>27.0</sparkle:minimumSystemVersion>
		            <enclosure url="https://example.invalid/v1.0.3700/Caker.dmg" length="1" type="application/x-apple-diskimage" sparkle:os="macos" />
		            <sparkle:tags><sparkle:prerelease/></sparkle:tags>
		        </item>
		        <item>
		            <title>no version</title>
		            <enclosure url="https://example.invalid/none/Caker.dmg" length="1" type="application/x-apple-diskimage" />
		        </item>
		    </channel>
		</rss>
		"""

	private let feedURL = URL(string: "https://caker.aldunelabs.com/appcast/appcast.xml")!

	func testVersionComparatorMatchesSparkle() {
		let ascending: [(String, String)] = [
			("1.0.3657", "1.0.3700"),
			("1.0.3657", "1.1.0"),
			("1.0", "1.0.1"),
			("1.0b1", "1.0"),
			("1.0a1", "1.0b1"),
			("1.0.9", "1.0.10"),
			// Beyond Int64: Sparkle's longLongValue would saturate and call these equal.
			("1.0.99999999999999999999", "1.0.100000000000000000000"),
		]

		for (lhs, rhs) in ascending {
			XCTAssertEqual(SparkleVersionComparator.compare(lhs, rhs), .orderedAscending, "\(lhs) < \(rhs)")
			XCTAssertEqual(SparkleVersionComparator.compare(rhs, lhs), .orderedDescending, "\(rhs) > \(lhs)")
		}

		XCTAssertEqual(SparkleVersionComparator.compare("1.0.3657", "1.0.3657"), .orderedSame)
		XCTAssertEqual(SparkleVersionComparator.compare("1.0.010", "1.0.10"), .orderedSame)
	}

	func testSplitSeparatesNumbersStringsAndSeparators() {
		XCTAssertEqual(SparkleVersionComparator.split("1.10b2"), ["1", ".", "10", "b", "2"])
		XCTAssertEqual(SparkleVersionComparator.split(""), [])
	}

	func testParsesVersionFromEnclosureAttributes() throws {
		let items = try Appcast.parse(Data(self.signedReleaseFeed.utf8))

		XCTAssertEqual(items.count, 1)
		XCTAssertEqual(items.first?.version, "1.0.3657")
		XCTAssertEqual(items.first?.title, "Caker 1.0.3657")
		XCTAssertEqual(items.first?.publishedAt, "dim., 11 oct. 2026 15:49:54 +0000")
		XCTAssertEqual(items.first?.downloadURL, "https://github.com/Fred78290/caker/releases/download/v1.0.3657/Caker.dmg")
		// The channel's <link> must not leak into the item.
		XCTAssertNil(items.first?.link)
	}

	func testParsesVersionElementsAndDropsItemsWithoutVersion() throws {
		let items = try Appcast.parse(Data(self.generatedFeed.utf8))

		XCTAssertEqual(items.map(\.version), ["1.0.3600", "1.0.3700"])
		XCTAssertEqual(items.first?.link, "https://github.com/Fred78290/caker/releases/tag/v1.0.3600")
		XCTAssertEqual(items.first?.minimumSystemVersion, "15.0")
		XCTAssertEqual(items.first?.os, "macos")
	}

	func testMalformedFeedThrows() {
		XCTAssertThrowsError(try Appcast.parse(Data("<rss><channel><item>".utf8)))
	}

	func testLatestItemSkipsReleasesNeedingANewerMacOS() throws {
		let items = try Appcast.parse(Data(self.generatedFeed.utf8))

		XCTAssertEqual(ReleaseUpdateChecker.latestItem(in: items, systemVersion: "26.1.0")?.version, "1.0.3600")
		XCTAssertEqual(ReleaseUpdateChecker.latestItem(in: items, systemVersion: "27.0.0")?.version, "1.0.3700")
	}

	func testLatestItemSkipsOtherOperatingSystems() {
		let items = [
			AppcastItem(version: "1.0.1", os: "macos"),
			AppcastItem(version: "1.0.2", os: "windows"),
		]

		XCTAssertEqual(ReleaseUpdateChecker.latestItem(in: items, systemVersion: "26.0.0")?.version, "1.0.1")
	}

	func testUpdateAvailableWhenFeedIsNewer() {
		let items = [AppcastItem(version: "1.0.3700", link: "https://example.invalid/notes", downloadURL: "https://example.invalid/Caker.dmg")]
		let status = ReleaseUpdateChecker.status(currentVersion: "1.0.3657", items: items, systemVersion: "26.0.0", feedURL: self.feedURL)

		XCTAssertTrue(status.updateAvailable)
		XCTAssertEqual(status.latestVersion, "1.0.3700")
		XCTAssertEqual(status.downloadURL, "https://example.invalid/Caker.dmg")
		XCTAssertEqual(status.releaseNotesURL, "https://example.invalid/notes")
		XCTAssertEqual(status.feedURL, self.feedURL.absoluteString)
		XCTAssertTrue(status.description.contains("1.0.3700"))
		XCTAssertTrue(status.description.contains("https://example.invalid/Caker.dmg"))
	}

	func testUpToDateWhenInstalledIsLatestOrNewer() {
		let items = [AppcastItem(version: "1.0.3657")]

		XCTAssertFalse(ReleaseUpdateChecker.status(currentVersion: "1.0.3657", items: items, systemVersion: "26.0.0", feedURL: self.feedURL).updateAvailable)
		XCTAssertFalse(ReleaseUpdateChecker.status(currentVersion: "1.0.3700", items: items, systemVersion: "26.0.0", feedURL: self.feedURL).updateAvailable)
	}

	func testUnversionedBuildNeverReportsAnUpdate() {
		let items = [AppcastItem(version: "1.0.3700")]

		for version in ["SNAPSHOT", "${VERSION}", ""] {
			let status = ReleaseUpdateChecker.status(currentVersion: version, items: items, systemVersion: "26.0.0", feedURL: self.feedURL)

			XCTAssertFalse(status.updateAvailable, version)
			XCTAssertEqual(status.latestVersion, "1.0.3700", version)
		}
	}

	func testNoCompatibleReleaseIsNotAnUpdate() {
		let status = ReleaseUpdateChecker.status(currentVersion: "1.0.3657", items: [], systemVersion: "26.0.0", feedURL: self.feedURL)

		XCTAssertFalse(status.updateAvailable)
		XCTAssertNil(status.latestVersion)
		XCTAssertTrue(status.description.contains(self.feedURL.absoluteString))
	}
}
