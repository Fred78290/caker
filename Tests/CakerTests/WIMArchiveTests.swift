//
//  WIMArchiveTests.swift
//  CakerTests
//

import CryptoKit
import Foundation
import XCTest

@testable import CakedLib

final class WIMArchiveTests: XCTestCase {
	private var directory: URL!

	override func setUpWithError() throws {
		self.directory = FileManager.default.temporaryDirectory.appendingPathComponent("wim-tests-\(UUID().uuidString)")

		try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try? FileManager.default.removeItem(at: self.directory)
	}

	private func makeFixture(named name: String = "fixture.wim") throws -> URL {
		let url = self.directory.appendingPathComponent(name)

		try WIMFixture.data.write(to: url)

		return url
	}

	private func sha1(_ data: Data) -> String {
		Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
	}

	// MARK: - Reading

	func testReadsTheHeaderAndImageDescription() throws {
		let wim = try WIMArchive(url: try self.makeFixture())

		XCTAssertEqual(wim.imageCount, 1)

		let images = try wim.images()

		XCTAssertEqual(images.count, 1)
		XCTAssertEqual(images[0].index, 1)
		XCTAssertEqual(images[0].name, "Fixture")
		XCTAssertEqual(images[0].language, "en-US")
	}

	func testListsEveryFileAndDirectory() throws {
		let files = try WIMArchive(url: try self.makeFixture()).files(ofImage: 1)
		let paths = Set(files.map { $0.path.lowercased() })

		XCTAssertEqual(files.count, 700 + 4 + 3 + 1 + 1, "700 numbered files, 4 named ones, the directories Windows, System32 and drivers, Program Files and its file")
		XCTAssertTrue(paths.contains("windows\\system32\\startnet.cmd"))
		XCTAssertTrue(paths.contains("windows\\system32\\drivers\\caker-test-file-with-a-fairly-long-name-0001.dll"))
		XCTAssertTrue(paths.contains("program files\\readme.txt"))
		XCTAssertEqual(files.first { $0.path == "Windows\\System32" }?.isDirectory, true)
	}

	func testDecompressesFilesAcrossChunksAndUndoesCallTranslation() throws {
		let wim = try WIMArchive(url: try self.makeFixture())

		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\startnet.cmd"), Data("wpeinit\r\n".utf8))
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "windows\\system32\\NOTES.TXT").map(self.sha1), "49a0f16e0a6c13f90269cfd4f2e7edc0c95fdf22", "case-insensitive lookup")
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\code.dll").map(self.sha1), "5122b8c7bf24a6e95ca07b33674c40dbdbcf5736", "x86 CALL translation undone")
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\random.bin").map(self.sha1), "6a85e315c7e2b39370988d0967fecd6275c5b525", "incompressible chunks stored as is")
		XCTAssertNil(try wim.contents(ofImage: 1, path: "Windows\\System32\\missing.txt"))
	}

	func testEveryFileMatchesItsRecordedHash() throws {
		let wim = try WIMArchive(url: try self.makeFixture())

		for file in try wim.files(ofImage: 1) where file.isDirectory == false && file.hash.contains(where: { $0 != 0 }) {
			let data = try XCTUnwrap(try wim.contents(ofImage: 1, path: file.path), file.path)

			XCTAssertEqual(Array(Insecure.SHA1.hash(data: data)), file.hash, file.path)
		}
	}

	func testRejectsAFileThatIsNotAWIM() throws {
		let url = self.directory.appendingPathComponent("not.wim")

		try Data(count: 512).write(to: url)

		XCTAssertThrowsError(try WIMArchive(url: url))
	}

	func testRejectsAMissingImage() throws {
		let wim = try WIMArchive(url: try self.makeFixture())

		XCTAssertThrowsError(try wim.files(ofImage: 2))
	}

	// MARK: - Adding files

	func testAddedFilesAreReadableAndOldOnesUntouched() throws {
		let url = try self.makeFixture()
		let before = try WIMArchive(url: url).files(ofImage: 1)

		try WIMArchive(url: url).addFiles(
			[("winpeshl.ini", Data("[LaunchApps]\r\ncmd.exe\r\n".utf8)), ("pe.cmd", Data("@echo off\r\n".utf8))],
			toDirectory: ["Windows", "System32"], ofImage: 1)

		let wim = try WIMArchive(url: url)
		let after = try wim.files(ofImage: 1)

		XCTAssertEqual(after.count, before.count + 2)
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\winpeshl.ini"), Data("[LaunchApps]\r\ncmd.exe\r\n".utf8))
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\PE.CMD"), Data("@echo off\r\n".utf8))
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\startnet.cmd"), Data("wpeinit\r\n".utf8))
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\random.bin").map(self.sha1), "6a85e315c7e2b39370988d0967fecd6275c5b525")
		XCTAssertEqual(Set(before.map { $0.path }).subtracting(after.map { $0.path }), [], "no file lost")
	}

	func testAddedFilesKeepTheDirectoryInNameOrder() throws {
		let url = try self.makeFixture()

		try WIMArchive(url: url).addFiles([("zzz.txt", Data("z".utf8)), ("AAA.txt", Data("a".utf8)), ("mid.txt", Data("m".utf8))], toDirectory: ["Windows", "System32"], ofImage: 1)

		let names = try WIMArchive(url: url).files(ofImage: 1).filter { $0.path.lowercased().hasPrefix("windows\\system32\\") && $0.path.dropFirst("Windows\\System32\\".count).contains("\\") == false }.map { String($0.path.dropFirst("Windows\\System32\\".count)).uppercased() }

		XCTAssertEqual(names, names.sorted { Array($0.utf16).lexicographicallyPrecedes(Array($1.utf16)) })
		XCTAssertTrue(names.contains("AAA.TXT") && names.contains("ZZZ.TXT"))
	}

	func testAddingAFileOfAnExistingNameReplacesIt() throws {
		let url = try self.makeFixture()
		let count = try WIMArchive(url: url).files(ofImage: 1).count

		try WIMArchive(url: url).addFiles([("STARTNET.CMD", Data("cmd /k\r\n".utf8))], toDirectory: ["Windows", "System32"], ofImage: 1)

		let wim = try WIMArchive(url: url)

		XCTAssertEqual(try wim.files(ofImage: 1).count, count)
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\startnet.cmd"), Data("cmd /k\r\n".utf8))
	}

	func testAddingTwoFilesWithTheSameContentSharesOneResource() throws {
		let url = try self.makeFixture()

		try WIMArchive(url: url).addFiles([("a.txt", Data("same".utf8)), ("b.txt", Data("same".utf8))], toDirectory: ["Windows"], ofImage: 1)

		let wim = try WIMArchive(url: url)

		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\a.txt"), Data("same".utf8))
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\b.txt"), Data("same".utf8))
	}

	func testAddingAnEmptyFileNeedsNoResource() throws {
		let url = try self.makeFixture()

		try WIMArchive(url: url).addFiles([("empty.txt", Data())], toDirectory: ["Windows"], ofImage: 1)

		XCTAssertEqual(try WIMArchive(url: url).contents(ofImage: 1, path: "Windows\\empty.txt"), Data())
	}

	func testAddingToAMissingDirectoryThrowsAndLeavesTheFileUntouched() throws {
		let url = try self.makeFixture()

		XCTAssertThrowsError(try WIMArchive(url: url).addFiles([("x.txt", Data("x".utf8))], toDirectory: ["Windows", "Nope"], ofImage: 1))
		XCTAssertEqual(try Data(contentsOf: url), WIMFixture.data)
	}

	func testEditsCanBeStacked() throws {
		let url = try self.makeFixture()

		try WIMArchive(url: url).addFiles([("one.txt", Data("1".utf8))], toDirectory: ["Windows", "System32"], ofImage: 1)
		try WIMArchive(url: url).addFiles([("two.txt", Data("2".utf8))], toDirectory: ["Windows", "System32"], ofImage: 1)

		let wim = try WIMArchive(url: url)

		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\one.txt"), Data("1".utf8))
		XCTAssertEqual(try wim.contents(ofImage: 1, path: "Windows\\System32\\two.txt"), Data("2".utf8))
	}

	/// wimlib, if installed, is the reference implementation: it must accept the edited file and read the same files.
	func testWimlibAcceptsAnEditedWIM() throws {
		guard let wimlib = ["/opt/homebrew/bin/wimlib-imagex", "/usr/local/bin/wimlib-imagex"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
			throw XCTSkip("wimlib-imagex is not installed")
		}

		let url = try self.makeFixture()

		try WIMArchive(url: url).addFiles([("winpeshl.ini", Data("[LaunchApps]\r\ncmd.exe\r\n".utf8)), ("pe.cmd", Data("@echo off\r\n".utf8))], toDirectory: ["Windows", "System32"], ofImage: 1)

		_ = try Process.capture(wimlib, ["verify", url.path])

		let extracted = self.directory.appendingPathComponent("extracted", isDirectory: true)

		_ = try Process.capture(wimlib, ["extract", url.path, "1", "/Windows/System32/pe.cmd", "/Windows/System32/startnet.cmd", "--dest-dir=\(extracted.path)"])

		XCTAssertEqual(try Data(contentsOf: extracted.appendingPathComponent("pe.cmd")), Data("@echo off\r\n".utf8))
		XCTAssertEqual(try Data(contentsOf: extracted.appendingPathComponent("startnet.cmd")), Data("wpeinit\r\n".utf8))
	}
}
