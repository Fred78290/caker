//
//  ComposeLibraryTests.swift
//  CakerTests
//

import Foundation
import XCTest
import Yams

@testable import CakedLib

final class ComposeLibraryTests: XCTestCase {
	private var temporaryDirectory: URL!

	override func setUpWithError() throws {
		self.temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("ComposeLibraryTests-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: self.temporaryDirectory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try? FileManager.default.removeItem(at: self.temporaryDirectory)
	}

	private func template(id: String = "demo", compose: String? = nil) -> ComposeLibraryTemplate {
		ComposeLibraryTemplate(
			id: id,
			name: "Demo",
			category: "Web",
			summary: "A demo",
			tags: ["demo", "sample"],
			compose: compose ?? "name: demo\nservices:\n  web:\n    image: ubuntu:24.04\n  db:\n    image: ubuntu:24.04\n    depends_on:\n      - web\n"
		)
	}

	private static let demoCompose = "name: demo\nservices:\n  web:\n    image: ubuntu:24.04\n"

	/// A template file as it is published: `# library-*` metadata, then the compose text.
	private func file(id: String, name: String = "Demo", compose: String = ComposeLibraryTests.demoCompose) -> String {
		"# library-id: \(id)\n# library-name: \(name)\n# library-category: Web\n# library-summary: A demo\n# library-tags: demo, sample\n\(compose)"
	}

	private func index(_ ids: [String], version: Int = ComposeLibrary.supportedVersion) -> Data {
		try! JSONEncoder().encode(ComposeLibrary.Index(version: version, templates: ids))
	}

	private var synced: URL {
		self.temporaryDirectory.appendingPathComponent(ComposeLibrary.directoryName, isDirectory: true)
	}

	// MARK: Bundled library

	func testBundledLibraryIsValid() throws {
		let library = ComposeLibrary.loadBundled()

		XCTAssertFalse(library.templates.isEmpty)
		XCTAssertNoThrow(try library.validate())
	}

	func testBundledFolderHasNoUnreadableTemplateAndItsIndexListsEveryFile() throws {
		let directory = ComposeLibrary.bundledDirectory()

		XCTAssertTrue(ComposeLibrary.templates(in: directory).errors.isEmpty, "\(ComposeLibrary.templates(in: directory).errors)")

		// The index is what GitHub sync downloads from: a template missing from it is never published.
		let listed = try ComposeLibrary.parseIndex(Data(contentsOf: directory.appendingPathComponent(ComposeLibrary.indexFileName)))
		let files = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".yml") }.map { String($0.dropLast(4)) }

		XCTAssertEqual(listed.sorted(), files.sorted())
	}

	func testEveryBundledTemplateBuildsEveryService() throws {
		for template in ComposeLibrary.loadBundled().templates {
			let compose = try template.composeFile()

			XCTAssertEqual(compose.name, template.projectName, template.id)

			for (service, definition) in compose.services {
				// The same step `compose up` runs for each service: a field it can't honour throws here.
				let built = try definition.toBuildOptions(name: "compose-\(compose.name)-\(service)", composeNetworks: compose.networks)

				defer { built.cleanup.forEach { try? FileManager.default.removeItem(at: $0) } }

				XCTAssertEqual(built.options.name, "compose-\(compose.name)-\(service)", "\(template.id)/\(service)")
			}

			XCTAssertNoThrow(try compose.startOrder(filter: []), template.id)
		}
	}

	func testBundledTemplatesDoNotCarryLibraryMetadataComments() {
		for template in ComposeLibrary.loadBundled().templates {
			XCTAssertFalse(template.compose.contains("# library-"), template.id)
		}
	}

	func testBundledTemplatesPointAtTheirOwnProject() throws {
		// A template names its peers through compose DNS (<service>.<project>.<domain>): the project must be its own.
		for template in ComposeLibrary.loadBundled().templates {
			let regex = try NSRegularExpression(pattern: #"[a-z0-9-]+\.([a-z0-9-]+)\.compose\.internal"#)
			let text = template.compose as NSString

			for match in regex.matches(in: template.compose, range: NSRange(location: 0, length: text.length)) {
				XCTAssertEqual(text.substring(with: match.range(at: 1)), template.projectName, "\(template.id) refers to another project")
			}
		}
	}

	func testTemplatesThatServeSomethingForwardItsPortsToTheHost() throws {
		let library = ComposeLibrary.loadBundled()
		let expected: [String: (service: String, ports: [String])] = [
			"docker-host": ("docker", ["8080:8080/tcp", "8443:8443/tcp"]),
			"k3s": ("server", ["6443:6443/tcp", "8080:80/tcp", "8443:443/tcp"]),
			"ubuntu-dev": ("dev", ["3000:3000/tcp", "8000:8000/tcp"]),
		]

		for (id, entry) in expected {
			let compose = try XCTUnwrap(library.template(id: id)).composeFile()
			let service = try XCTUnwrap(compose.services[entry.service], id)
			let built = try service.toBuildOptions(name: "compose-\(compose.name)-\(entry.service)", composeNetworks: compose.networks)

			defer { built.cleanup.forEach { try? FileManager.default.removeItem(at: $0) } }

			XCTAssertEqual(built.options.forwardedPorts.map { "\($0)" }.filter { $0.contains(".sock") == false }.sorted(), entry.ports.sorted(), id)
		}
	}

	func testDockerHostForwardsTheDockerSocket() throws {
		let compose = try XCTUnwrap(ComposeLibrary.loadBundled().template(id: "docker-host")).composeFile()
		let service = try XCTUnwrap(compose.services["docker"])
		let built = try service.toBuildOptions(name: "compose-dockerhost-docker", composeNetworks: compose.networks)

		defer { built.cleanup.forEach { try? FileManager.default.removeItem(at: $0) } }

		let sockets = built.options.forwardedPorts.map { "\($0)" }.filter { $0.contains(".sock") }

		XCTAssertEqual(sockets.count, 1)
		XCTAssertTrue(sockets[0].contains("~/.docker/run/docker.sock") && sockets[0].contains("/var/run/docker.sock"), sockets[0])
	}

	// MARK: Search

	func testSearchMatchesEveryWordAcrossFields() {
		let library = ComposeLibrary(templates: [self.template(id: "demo"), self.template(id: "other")])

		XCTAssertEqual(library.search("demo sample").count, 2)
		XCTAssertEqual(library.search("other").map(\.id), ["other"])
		XCTAssertTrue(library.search("missing").isEmpty)
		XCTAssertEqual(library.search(nil, category: "web").count, 2)
		XCTAssertTrue(library.search(nil, category: "Database").isEmpty)
	}

	func testTemplateLookupIgnoresCase() {
		XCTAssertNotNil(ComposeLibrary(templates: [self.template()]).template(id: "DEMO"))
	}

	// MARK: Validation

	func testValidationRefusesBadTemplates() {
		XCTAssertThrowsError(try ComposeLibrary(templates: [self.template(id: "Bad_Id")]).validate())
		XCTAssertThrowsError(try ComposeLibrary(templates: [self.template(), self.template()]).validate())
		XCTAssertThrowsError(try ComposeLibrary(templates: [self.template(compose: "name: demo\nservices: [")]).validate())
		XCTAssertThrowsError(try ComposeLibrary(templates: [self.template(compose: "name: demo\nservices: {}\n")]).validate())
		XCTAssertThrowsError(try ComposeLibrary(version: ComposeLibrary.supportedVersion + 1, templates: []).validate())
	}

	// MARK: Rename and clone

	func testRenamingFollowsTheProjectInDnsAndVmNames() throws {
		let template = self.template(compose: """
			name: lamp
			services:
			  db:
			    image: ubuntu:24.04
			  web:
			    image: ubuntu:24.04
			    depends_on: [db]
			    write_files:
			      - path: /var/www/html/index.php
			        content: db.lamp.compose.internal (compose-lamp-db)
			""")

		let text = try template.composeText(projectName: "shop")

		XCTAssertTrue(text.contains("name: shop"))
		XCTAssertTrue(text.contains("db.shop.compose.internal (compose-shop-db)"))
		XCTAssertFalse(text.contains("lamp"))
		XCTAssertEqual(try YAMLDecoder().decode(ComposeFile.self, from: text).name, "shop")
	}

	func testRenamingRefusesAnInvalidProjectName() {
		for name in ["Shop", "my shop", "-shop", "shop-", "a/b", ""] {
			XCTAssertThrowsError(try self.template().composeText(projectName: name), name)
		}
	}

	func testWithoutANewNameTheTextIsUntouched() throws {
		XCTAssertEqual(try self.template().composeText(projectName: nil), self.template().compose)
	}

	func testConfiguredDomainReplacesTheDefaultOneWithAndWithoutARename() throws {
		let template = try ComposeLibraryTemplate.parse("""
			# library-id: lamp
			# library-name: LAMP
			# library-category: Web
			# library-summary: s
			# library-tags: a
			name: lamp
			services:
			  db:
			    image: ubuntu:24.04
			    environment:
			      HOST: db.lamp.compose.internal
			""")

		let unchanged = try template.composeText(projectName: nil, domain: "dev.test")
		let renamed = try template.composeText(projectName: "shop", domain: "dev.test")

		XCTAssertTrue(unchanged.contains("db.lamp.dev.test"))
		XCTAssertFalse(unchanged.contains("compose.internal"))
		XCTAssertTrue(renamed.contains("db.shop.dev.test"))
		XCTAssertFalse(renamed.contains("compose.internal"))
		XCTAssertEqual(try template.composeText(projectName: nil, domain: ComposeDNS.defaultDomainSuffix), template.compose)
	}

	func testCloneWritesTheTemplateAndRefusesToOverwrite() throws {
		let destination = self.temporaryDirectory.appendingPathComponent("project/compose.yml")

		try ComposeLibrary.clone(self.template(), to: destination)

		XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), self.template().compose)
		XCTAssertThrowsError(try ComposeLibrary.clone(self.template(), to: destination))
		XCTAssertNoThrow(try ComposeLibrary.clone(self.template(), projectName: "renamed", to: destination, force: true))
		XCTAssertTrue(try String(contentsOf: destination, encoding: .utf8).contains("name: renamed"))
	}

	func testDestinationResolution() throws {
		let directory = self.temporaryDirectory!

		XCTAssertEqual(ComposeLibrary.destination(output: nil, currentDirectory: directory).lastPathComponent, ComposeFile.filename)
		XCTAssertEqual(ComposeLibrary.destination(output: directory.path, currentDirectory: directory).lastPathComponent, ComposeFile.filename)
		XCTAssertEqual(ComposeLibrary.destination(output: "new-dir/", currentDirectory: directory).deletingLastPathComponent().lastPathComponent, "new-dir")
		XCTAssertEqual(ComposeLibrary.destination(output: "my-stack.yml", currentDirectory: directory).lastPathComponent, "my-stack.yml")
	}

	// MARK: Template files

	func testParseReadsTheMetadataAndStripsTheHeader() throws {
		let template = try ComposeLibraryTemplate.parse(self.file(id: "demo"), id: "demo")

		XCTAssertEqual(template.id, "demo")
		XCTAssertEqual(template.name, "Demo")
		XCTAssertEqual(template.category, "Web")
		XCTAssertEqual(template.summary, "A demo")
		XCTAssertEqual(template.tags, ["demo", "sample"])
		XCTAssertEqual(template.compose, ComposeLibraryTests.demoCompose)
		XCTAssertNoThrow(try template.validate())
	}

	func testParseKeepsALibraryCommentThatIsNotInTheHeader() throws {
		let template = try ComposeLibraryTemplate.parse(self.file(id: "demo", compose: "name: demo\n# library-note: kept\nservices:\n  web:\n    image: ubuntu:24.04\n"))

		XCTAssertTrue(template.compose.contains("# library-note: kept"))
	}

	func testParseRefusesMissingMetadataAndAnIdThatIsNotTheFileName() {
		XCTAssertThrowsError(try ComposeLibraryTemplate.parse(ComposeLibraryTests.demoCompose, id: "demo"))
		XCTAssertThrowsError(try ComposeLibraryTemplate.parse("# library-id: demo\n" + ComposeLibraryTests.demoCompose))
		XCTAssertThrowsError(try ComposeLibraryTemplate.parse(self.file(id: "demo"), id: "other"))
	}

	// MARK: Index

	func testIndexRefusesWhatCouldNotBeSafelyUsedAsAFileName() {
		XCTAssertNoThrow(try ComposeLibrary.parseIndex(self.index(["a", "b-c"])))
		XCTAssertThrowsError(try ComposeLibrary.parseIndex(self.index(["../../etc/passwd"])))
		XCTAssertThrowsError(try ComposeLibrary.parseIndex(self.index(["a/b"])))
		XCTAssertThrowsError(try ComposeLibrary.parseIndex(self.index(["Upper"])))
		XCTAssertThrowsError(try ComposeLibrary.parseIndex(self.index(["a", "a"])))
		XCTAssertThrowsError(try ComposeLibrary.parseIndex(self.index([])))
		XCTAssertThrowsError(try ComposeLibrary.parseIndex(self.index(["a"], version: ComposeLibrary.supportedVersion + 1)))
		XCTAssertThrowsError(try ComposeLibrary.parseIndex(Data("not json".utf8)))
	}

	// MARK: Sync

	func testInstallWritesOneFilePerTemplateAndReportsWhatChanged() throws {
		let destination = self.synced
		let first = try ComposeLibrary.install(index: self.index(["keep", "gone"]), files: ["keep": self.file(id: "keep"), "gone": self.file(id: "gone")], destination: destination)

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		XCTAssertEqual(first.templates, 2)

		for name in ["keep.yml", "gone.yml", ComposeLibrary.indexFileName] {
			XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent(name).path), name)
		}

		// The file is stored as published, header included, so it stays a template the library can read.
		XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("keep.yml"), encoding: .utf8), self.file(id: "keep"))

		let files = ["keep": self.file(id: "keep", name: "Renamed"), "new": self.file(id: "new")]
		let result = try ComposeLibrary.install(index: self.index(["keep", "new"]), files: files, destination: destination)

		XCTAssertEqual(result.added, ["new"])
		XCTAssertEqual(result.updated, ["keep"])
		XCTAssertEqual(result.removed, ["gone"])
		XCTAssertTrue(result.changed)
		XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("gone.yml").path))
		XCTAssertFalse(try ComposeLibrary.install(index: self.index(["keep", "new"]), files: files, destination: destination).changed)
	}

	func testInstallLeavesATemplateTheUserAddedByHand() throws {
		let destination = self.synced

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		_ = try ComposeLibrary.install(index: self.index(["one"]), files: ["one": self.file(id: "one")], destination: destination)
		try self.file(id: "mine").write(to: destination.appendingPathComponent("mine.yml"), atomically: true, encoding: .utf8)

		let result = try ComposeLibrary.install(index: self.index(["two"]), files: ["two": self.file(id: "two")], destination: destination)

		XCTAssertEqual(result.removed, ["one"])
		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).templates.map(\.id), ["mine", "two"])
	}

	func testInstallFailsBeforeWritingTheIndexWhenARetiredTemplateCannotBeRemoved() throws {
		let destination = self.synced
		let retired = destination.appendingPathComponent("gone.yml")

		defer {
			try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: retired.path)
			_ = ComposeLibrary.reloadIfChanged(overrideURL: nil)
		}

		_ = try ComposeLibrary.install(index: self.index(["keep", "gone"]), files: ["keep": self.file(id: "keep"), "gone": self.file(id: "gone")], destination: destination)

		let oldIndex = try Data(contentsOf: destination.appendingPathComponent(ComposeLibrary.indexFileName))

		// An immutable file can't be removed: the sync must say so instead of dropping it from the index
		// and leaving it in the folder, where it would still be loaded.
		try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: retired.path)

		XCTAssertThrowsError(try ComposeLibrary.install(index: self.index(["keep"]), files: ["keep": self.file(id: "keep")], destination: destination))
		XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent(ComposeLibrary.indexFileName)), oldIndex)
		XCTAssertTrue(FileManager.default.fileExists(atPath: retired.path))
	}

	func testInstallToleratesARetiredTemplateThatWasAlreadyRemoved() throws {
		let destination = self.synced

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		_ = try ComposeLibrary.install(index: self.index(["keep", "gone"]), files: ["keep": self.file(id: "keep"), "gone": self.file(id: "gone")], destination: destination)
		try FileManager.default.removeItem(at: destination.appendingPathComponent("gone.yml"))

		let result = try ComposeLibrary.install(index: self.index(["keep"]), files: ["keep": self.file(id: "keep")], destination: destination)

		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).templates.map(\.id), ["keep"])
		XCTAssertEqual(result.templates, 1)
	}

	func testInstallRefusesAnInvalidLibraryWithoutTouchingTheCopy() throws {
		let destination = self.synced

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		_ = try ComposeLibrary.install(index: self.index(["good"]), files: ["good": self.file(id: "good")], destination: destination)

		let before = try Data(contentsOf: destination.appendingPathComponent("good.yml"))

		// Listed but not downloaded, an id that isn't the file's, a broken compose file, a path as id.
		XCTAssertThrowsError(try ComposeLibrary.install(index: self.index(["good", "absent"]), files: ["good": self.file(id: "good")], destination: destination))
		XCTAssertThrowsError(try ComposeLibrary.install(index: self.index(["good"]), files: ["good": self.file(id: "other")], destination: destination))
		XCTAssertThrowsError(try ComposeLibrary.install(index: self.index(["good"]), files: ["good": self.file(id: "good", compose: "name: demo\nservices: [")], destination: destination))
		XCTAssertThrowsError(try ComposeLibrary.install(index: self.index(["../escape"]), files: ["../escape": self.file(id: "../escape")], destination: destination))

		XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("good.yml")), before)
		XCTAssertFalse(FileManager.default.fileExists(atPath: self.temporaryDirectory.appendingPathComponent("escape.yml").path))
	}

	// MARK: Reload

	func testReloadFollowsTheSyncedFolderAndEditsToIt() throws {
		let destination = self.synced

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		_ = try ComposeLibrary.install(index: self.index(["only-here"]), files: ["only-here": self.file(id: "only-here")], destination: destination)

		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).templates.map(\.id), ["only-here"])

		// A template can be edited in place.
		try self.file(id: "only-here", name: "Edited").write(to: destination.appendingPathComponent("only-here.yml"), atomically: false, encoding: .utf8)

		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).template(id: "only-here")?.name, "Edited")

		// Removing the folder falls back to the bundled library.
		try FileManager.default.removeItem(at: destination)

		XCTAssertNotNil(ComposeLibrary.reloadIfChanged(overrideURL: destination).template(id: "postgres"))
	}

	/// Editing a file that is older than the newest one must still be noticed: the signature tracks each
	/// entry, not only the latest date.
	func testReloadNoticesAnEditToAFileOlderThanTheNewestOne() throws {
		let destination = self.synced
		let fm = FileManager.default

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		_ = try ComposeLibrary.install(index: self.index(["a", "b"]), files: ["a": self.file(id: "a"), "b": self.file(id: "b")], destination: destination)

		let now = Date()
		let fileA = destination.appendingPathComponent("a.yml")
		let fileB = destination.appendingPathComponent("b.yml")

		try fm.setAttributes([.modificationDate: now.addingTimeInterval(-100)], ofItemAtPath: fileA.path(percentEncoded: false))
		try fm.setAttributes([.modificationDate: now.addingTimeInterval(100)], ofItemAtPath: fileB.path(percentEncoded: false))

		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).template(id: "a")?.name, "Demo")

		// Edit `a` in place, then give it a date that is still older than `b`'s (the newest).
		try self.file(id: "a", name: "Edited").write(to: fileA, atomically: false, encoding: .utf8)
		try fm.setAttributes([.modificationDate: now.addingTimeInterval(-50)], ofItemAtPath: fileA.path(percentEncoded: false))

		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).template(id: "a")?.name, "Edited")

		// Removing `a` is noticed too, while `b` stays the newest.
		try fm.removeItem(at: fileA)
		try fm.setAttributes([.modificationDate: now.addingTimeInterval(100)], ofItemAtPath: destination.path(percentEncoded: false))

		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).templates.map(\.id), ["b"])
	}

	func testAFolderThatWasNotSyncedIsIgnored() throws {
		let destination = self.synced

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
		try self.file(id: "no-index").write(to: destination.appendingPathComponent("no-index.yml"), atomically: true, encoding: .utf8)

		let library = ComposeLibrary.reloadIfChanged(overrideURL: destination)

		XCTAssertNil(library.template(id: "no-index"))
		XCTAssertNotNil(library.template(id: "postgres"))
	}

	func testAFolderWhoseIndexIsNewerOrUnreadableFallsBackToTheBundledLibrary() throws {
		let destination = self.synced

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		_ = try ComposeLibrary.install(index: self.index(["fine"]), files: ["fine": self.file(id: "fine")], destination: destination)

		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).templates.map(\.id), ["fine"])

		// An index written by a newer caker is not understood: the bundled copy is used.
		try self.index(["fine"], version: ComposeLibrary.supportedVersion + 1).write(to: destination.appendingPathComponent(ComposeLibrary.indexFileName))

		var library = ComposeLibrary.reloadIfChanged(overrideURL: destination)

		XCTAssertNil(library.template(id: "fine"))
		XCTAssertNotNil(library.template(id: "postgres"))

		// So is one that can't be parsed.
		try Data("{ broken".utf8).write(to: destination.appendingPathComponent(ComposeLibrary.indexFileName))

		library = ComposeLibrary.reloadIfChanged(overrideURL: destination)

		XCTAssertNil(library.template(id: "fine"))
		XCTAssertNotNil(library.template(id: "postgres"))
	}

	func testAnUnreadableTemplateIsSkippedAndTheOthersStay() throws {
		let destination = self.synced

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		_ = try ComposeLibrary.install(index: self.index(["fine", "doomed"]), files: ["fine": self.file(id: "fine"), "doomed": self.file(id: "doomed")], destination: destination)
		try Data("{ broken".utf8).write(to: destination.appendingPathComponent("doomed.yml"))

		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).templates.map(\.id), ["fine"])
	}

	func testAFolderWithNothingUsableFallsBackToTheBundledLibrary() throws {
		let destination = self.synced

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		_ = try ComposeLibrary.install(index: self.index(["doomed"]), files: ["doomed": self.file(id: "doomed")], destination: destination)
		try Data("{ broken".utf8).write(to: destination.appendingPathComponent("doomed.yml"))

		XCTAssertNotNil(ComposeLibrary.reloadIfChanged(overrideURL: destination).template(id: "postgres"))
	}
}
