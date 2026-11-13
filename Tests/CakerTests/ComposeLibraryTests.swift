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

	// MARK: Bundled library

	func testBundledLibraryIsValid() throws {
		let library = ComposeLibrary.loadBundled()

		XCTAssertFalse(library.templates.isEmpty)
		XCTAssertNoThrow(try library.validate())
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

	// MARK: Sync

	func testInstallReportsWhatChangedAndKeepsTheCopy() throws {
		let destination = self.temporaryDirectory.appendingPathComponent("ComposeLibrary.json")
		let first = ComposeLibrary(templates: [self.template(id: "keep"), self.template(id: "gone")])
		var changed = self.template(id: "keep")

		changed = ComposeLibraryTemplate(id: changed.id, name: "Renamed", category: changed.category, summary: changed.summary, tags: changed.tags, compose: changed.compose)

		let second = ComposeLibrary(templates: [changed, self.template(id: "new")])

		let initial = try ComposeLibrary.install(JSONEncoder().encode(first), destination: destination)

		XCTAssertEqual(initial.templates, 2)
		XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))

		let result = try ComposeLibrary.install(JSONEncoder().encode(second), destination: destination)

		XCTAssertEqual(result.added, ["new"])
		XCTAssertEqual(result.updated, ["keep"])
		XCTAssertEqual(result.removed, ["gone"])
		XCTAssertTrue(result.changed)
		XCTAssertEqual(try ComposeLibrary.install(JSONEncoder().encode(second), destination: destination).changed, false)
	}

	func testInstallRefusesAnInvalidLibraryWithoutTouchingTheCopy() throws {
		let destination = self.temporaryDirectory.appendingPathComponent("ComposeLibrary.json")
		let good = try JSONEncoder().encode(ComposeLibrary(templates: [self.template()]))

		_ = try ComposeLibrary.install(good, destination: destination)

		XCTAssertThrowsError(try ComposeLibrary.install(Data("not json".utf8), destination: destination))
		XCTAssertThrowsError(try ComposeLibrary.install(JSONEncoder().encode(ComposeLibrary(templates: [self.template(id: "BAD")])), destination: destination))
		XCTAssertEqual(try Data(contentsOf: destination), good)
	}

	func testReloadFollowsTheSyncedCopy() throws {
		let destination = self.temporaryDirectory.appendingPathComponent("ComposeLibrary.json")
		let library = ComposeLibrary(templates: [self.template(id: "only-here")])

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		try JSONEncoder().encode(library).write(to: destination)

		XCTAssertEqual(ComposeLibrary.reloadIfChanged(overrideURL: destination).templates.map(\.id), ["only-here"])

		// Removing the copy falls back to the bundled library.
		try FileManager.default.removeItem(at: destination)

		XCTAssertNotNil(ComposeLibrary.reloadIfChanged(overrideURL: destination).template(id: "postgres"))
	}

	func testADamagedSyncedCopyIsIgnored() throws {
		let destination = self.temporaryDirectory.appendingPathComponent("ComposeLibrary.json")

		defer { _ = ComposeLibrary.reloadIfChanged(overrideURL: nil) }

		try Data("{ broken".utf8).write(to: destination)

		XCTAssertNotNil(ComposeLibrary.reloadIfChanged(overrideURL: destination).template(id: "postgres"))
	}
}
