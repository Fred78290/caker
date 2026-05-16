import XCTest

@testable import CakedLib

final class VMLocationLogURLTests: XCTestCase {
	func testLogURLResolvesFileInsideVMDirectory() throws {
		let temporaryDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

		let location = VMLocation(rootURL: temporaryDirectory)
		let url = try XCTUnwrap(location.logURL(named: "console.log"))

		XCTAssertEqual(url, temporaryDirectory.appendingPathComponent("console.log", isDirectory: false).absoluteURL)
	}

	func testOutputLogURLResolvesInsideVMDirectory() throws {
		let temporaryDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

		let location = VMLocation(rootURL: temporaryDirectory)

		XCTAssertEqual(location.outputLogURL, temporaryDirectory.appendingPathComponent("output.log", isDirectory: false).absoluteURL)
	}

	func testLogURLRejectsPathTraversal() throws {
		let temporaryDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

		let location = VMLocation(rootURL: temporaryDirectory)

		XCTAssertNil(location.logURL(named: "../escape.log"))
		XCTAssertNil(location.logURL(named: "logs/escape.log"))
	}
}
