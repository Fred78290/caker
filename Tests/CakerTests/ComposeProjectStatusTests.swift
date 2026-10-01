import XCTest

@testable import CakedLib
@testable import GRPCLib

/// Covers the pure logic `caker`'s Compose sidebar/menu-bar UI is built on: `ComposeReplyList.ComposeInfo`'s
/// aggregate "n/m running" summary and its "start vs. stop" primary-action decision (`GRPCLib`), plus
/// its best-effort reconstruction of a startable `ComposeFile` from what the registry still knows
/// about a project (`CakedLib`) — the same reconstruction the Compose Editor's "edit" seed and the
/// sidebar/menu-bar "start" actions rely on since no RPC returns a project's original raw definition.
final class ComposeProjectStatusTests: XCTestCase {
	private func makeInfo(name: String = "demo", services: [(name: String, image: String, running: Bool)]) -> ComposeReplyList.ComposeInfo {
		ComposeReplyList.ComposeInfo(
			name: name,
			services: services.map { ComposeServiceInfo(name: $0.name, image: $0.image, status: $0.running ? "provisioned" : "not found", running: $0.running) }
		)
	}

	func testStatusSummaryCountsRunningServices() {
		let info = self.makeInfo(services: [
			("app", "ubuntu:24.04", true),
			("database", "ubuntu:24.04", false),
		])

		XCTAssertEqual(info.runningServiceCount, 1)
		XCTAssertEqual(info.totalServiceCount, 2)
		XCTAssertEqual(info.statusSummary, "1/2 running")
	}

	func testEmptyProjectSummarizesAsZeroOverZero() {
		let info = self.makeInfo(services: [])

		XCTAssertEqual(info.runningServiceCount, 0)
		XCTAssertEqual(info.totalServiceCount, 0)
		XCTAssertEqual(info.statusSummary, "0/0 running")
	}

	func testPrimaryActionIsStartWhenNothingIsRunning() {
		let info = self.makeInfo(services: [
			("app", "ubuntu:24.04", false),
			("database", "ubuntu:24.04", false),
		])

		XCTAssertEqual(info.primaryAction, .start)
	}

	func testPrimaryActionIsStopWhenAnyServiceIsRunning() {
		let info = self.makeInfo(services: [
			("app", "ubuntu:24.04", true),
			("database", "ubuntu:24.04", false),
		])

		XCTAssertEqual(info.primaryAction, .stop)
	}

	func testEmptyProjectDefaultsToStartAction() {
		XCTAssertEqual(self.makeInfo(services: []).primaryAction, .start)
	}

	func testReconstructedComposeFileCarriesNameAndImagesOnly() {
		let info = self.makeInfo(services: [
			("database", "postgres:16", true),
			("app", "ubuntu:24.04", false),
		])

		let compose = info.reconstructedComposeFile()

		XCTAssertEqual(compose.name, "demo")
		XCTAssertEqual(compose.services.count, 2)
		XCTAssertEqual(compose.services["app"]?.image, "ubuntu:24.04")
		XCTAssertEqual(compose.services["database"]?.image, "postgres:16")
		// Nothing beyond the image survives the round trip through the reduced `ls`/`ps` projection.
		XCTAssertNil(compose.services["app"]?.ports)
		XCTAssertNil(compose.services["app"]?.dependsOn)
	}

	func testReconstructedComposeFileTreatsPlaceholderImageAsNil() {
		let info = self.makeInfo(services: [("app", "-", false)])

		let compose = info.reconstructedComposeFile()

		XCTAssertNil(compose.services["app"]?.image)
	}
}
