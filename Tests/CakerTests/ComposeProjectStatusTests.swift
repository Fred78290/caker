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

	func testStoredComposeFileRestoresTheWholeRegisteredDefinition() throws {
		var db = ComposeService()
		db.image = "ubuntu:24.04"
		var web = ComposeService()
		web.image = "ubuntu:24.04"
		web.dependsOn = .list(["db"])
		web.packages = ["nginx"]
		let stored = ComposeFile(name: "demo", services: ["db": db, "web": web])
		let database = try ComposeFileDatabase(FileManager.default.temporaryDirectory.appendingPathComponent("compose-\(UUID().uuidString).json"))

		try database.upsert("demo", ComposeFileDatabase.ComposeFileStatus(composeFile: stored))

		let info = try XCTUnwrap(ComposeHandler.list(database: database, runMode: .user).composeFiles.first)
		let restored = try XCTUnwrap(info.storedComposeFile())

		XCTAssertEqual(restored.name, "demo")
		XCTAssertEqual(restored.services["web"]?.dependsOn?.serviceNames, ["db"])
		XCTAssertEqual(restored.services["web"]?.packages, ["nginx"])
	}

	func testStoredComposeFileIsNilWithoutPayload() {
		XCTAssertNil(self.makeInfo(services: [("app", "ubuntu:24.04", false)]).storedComposeFile())
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

	// MARK: - compose edit

	private func withEditor(_ editor: String, _ body: () throws -> Void) throws {
		let previous = ProcessInfo.processInfo.environment["EDITOR"]

		unsetenv("VISUAL")
		setenv("EDITOR", editor, 1)
		defer {
			if let previous { setenv("EDITOR", previous, 1) } else { unsetenv("EDITOR") }
		}

		try body()
	}

	func testEditableYAMLRoundTripsThroughDecodeEdited() throws {
		var web = ComposeService()
		web.image = "ubuntu:24.04"
		web.packages = ["nginx"]
		let text = try ComposeFile.editableYAML(for: ComposeFile(name: "demo", services: ["web": web]))

		XCTAssertTrue(text.hasPrefix("# Rebuilt from \"demo\""))

		let decoded = try ComposeFile.decodeEdited(text, expectedName: "demo")

		XCTAssertEqual(decoded.services["web"]?.packages, ["nginx"])
	}

	func testDecodeEditedRejectsARenamedProject() throws {
		let text = try ComposeFile.editableYAML(for: ComposeFile(name: "demo", services: [:]))

		XCTAssertThrowsError(try ComposeFile.decodeEdited(text, expectedName: "other"))
	}

	func testEditInEditorReturnsNilWhenUnchanged() throws {
		try self.withEditor("true") {
			XCTAssertNil(try ComposeFile.editInEditor("name: demo\n"))
		}
	}

	func testEditInEditorReturnsTheEditedText() throws {
		try self.withEditor("sed -i '' s/demo/changed/") {
			let edited = try XCTUnwrap(try ComposeFile.editInEditor("name: demo\n"))

			XCTAssertEqual(edited.text, "name: changed\n")
			try? FileManager.default.removeItem(at: edited.file)
		}
	}

	/// A child in its own process group is a background job on a terminal: `vi` gets stopped by
	/// SIGTTOU/SIGTTIN and `compose edit` hangs showing nothing.
	func testEditInEditorRunsTheEditorInTheCallersProcessGroup() throws {
		let editor = "sh -c '[ \"$(ps -o pgid= -p $$ | tr -d \" \")\" = \"\(getpgrp())\" ]'"

		try self.withEditor(editor) {
			XCTAssertNil(try ComposeFile.editInEditor("name: demo\n"))
		}
	}

	func testEditInEditorThrowsWhenTheEditorFails() throws {
		try self.withEditor("false") {
			XCTAssertThrowsError(try ComposeFile.editInEditor("name: demo\n"))
		}
	}
}
