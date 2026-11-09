import Foundation
import XCTest

@testable import CakedLib

final class PIDFileSafetyTests: XCTestCase {
	private var root: URL!

	override func setUpWithError() throws {
		self.root = FileManager.default.temporaryDirectory.appendingPathComponent("pidsafety-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
		// /var is a link to /private/var: the walk wants the canonical path, as the helper hands it to caked.
		self.root = URL(fileURLWithPath: URL.canonicalPath(self.root.path))
	}

	override func tearDownWithError() throws {
		try? FileManager.default.removeItem(at: self.root)
	}

	func testOpenDirectoryRefusesASymlinkComponentWhenPathsAreNotResolved() throws {
		let real = self.root.appendingPathComponent("real")
		let link = self.root.appendingPathComponent("link")

		try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
		try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

		setenv(URL.noFollowPathsEnvironmentKey, "1", 1)

		defer {
			unsetenv(URL.noFollowPathsEnvironmentKey)
		}

		let descriptor = try URL.openDirectoryWithoutFollowingSymlinks(real.path)

		close(descriptor)
		XCTAssertThrowsError(try URL.openDirectoryWithoutFollowingSymlinks(link.path), "a symlink swapped in after validation must not be followed")
		XCTAssertThrowsError(try URL.openDirectoryWithoutFollowingSymlinks(link.appendingPathComponent("sub").path))
	}

	func testOpenDirectoryResolvesASymlinkOnceWhenNotLaunchedByTheHelper() throws {
		let real = self.root.appendingPathComponent("real")
		let link = self.root.appendingPathComponent("link")

		try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
		try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
		unsetenv(URL.noFollowPathsEnvironmentKey)

		let descriptor = try URL.openDirectoryWithoutFollowingSymlinks(link.path)

		close(descriptor)
	}

	func testWritePIDAndRemoveWithoutFollowingSymlinksKeepTheFileInItsDirectory() throws {
		let file = self.root.appendingPathComponent("vmnet.pid")

		try file.writePIDWithoutFollowingSymlinks()
		XCTAssertEqual(file.readPID(), getpid())

		file.removeWithoutFollowingSymlinks()
		XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
	}

	func testRemoveNeverFollowsASymlinkAtTheFileItself() throws {
		let target = self.root.appendingPathComponent("target.pid")
		let link = self.root.appendingPathComponent("vmnet.pid")

		try "1".write(to: target, atomically: true, encoding: .ascii)
		try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

		link.removeWithoutFollowingSymlinks()

		XCTAssertTrue(FileManager.default.fileExists(atPath: target.path), "only the link is removed")
	}
}
