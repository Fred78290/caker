import Foundation
import XCTest

@testable import CakedLib

// The pinned PID directory is compiled in only with `BECOME_PARANOID=1`.
#if BECOME_PARANOID

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

	func testPinnedPIDDirectorySurvivesReplacementAndKeepsCleanupAnchored() throws {
		let parent = self.root.appendingPathComponent("network")
		let moved = self.root.appendingPathComponent("moved")
		let outside = self.root.appendingPathComponent("outside")
		try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
		let pid = parent.appendingPathComponent("vmnet.pid")
		let descriptor = try URL.openPIDDirectory(pid, beneath: self.root, owner: getuid())
		defer { close(descriptor) }
		try FileManager.default.moveItem(at: parent, to: moved)
		try FileManager.default.createSymbolicLink(at: parent, withDestinationURL: outside)
		XCTAssertThrowsError(try URL.openPIDDirectory(pid, beneath: self.root, owner: getuid()))

		// Exercise the same inherited directory used by the privileged child.
		guard geteuid() == 0 else { throw XCTSkip("Inherited PID writes require root") }
		setenv(URL.pidDirectoryEnvironmentKey, String(descriptor), 1)
		setenv(URL.pidPathEnvironmentKey, pid.path(percentEncoded: false), 1)
		defer {
			unsetenv(URL.pidDirectoryEnvironmentKey)
			unsetenv(URL.pidPathEnvironmentKey)
		}
		try pid.writePIDWithoutFollowingSymlinks()
		XCTAssertEqual(moved.appendingPathComponent("vmnet.pid").readPID(), getpid())
		XCTAssertFalse(outside.appendingPathComponent("vmnet.pid").fileExists)
		let outsidePID = outside.appendingPathComponent("vmnet.pid")
		try "sentinel".write(to: outsidePID, atomically: true, encoding: .ascii)
		pid.removeWithoutFollowingSymlinks()
		XCTAssertEqual(try String(contentsOf: outsidePID, encoding: .ascii), "sentinel")
		XCTAssertFalse(moved.appendingPathComponent("vmnet.pid").fileExists)
	}

	func testPIDDirectoryRefusesAHomeReplacedBySymlinkOrNotOwnedByTheCaller() throws {
		let realHome = self.root.appendingPathComponent("realhome")
		let home = self.root.appendingPathComponent("home")

		try FileManager.default.createDirectory(at: realHome.appendingPathComponent("net"), withIntermediateDirectories: true)

		close(try URL.openPIDDirectory(realHome.appendingPathComponent("net/vmnet.pid"), beneath: realHome, owner: getuid()))
		XCTAssertThrowsError(try URL.openPIDDirectory(realHome.appendingPathComponent("net/vmnet.pid"), beneath: realHome, owner: getuid() &+ 1))

		// The home is replaced by a link after the validation: nothing below it is reachable.
		try FileManager.default.createSymbolicLink(at: home, withDestinationURL: realHome)
		XCTAssertThrowsError(try URL.openPIDDirectory(home.appendingPathComponent("net/vmnet.pid"), beneath: home, owner: getuid()))
	}

	func testPIDDirectoryRejectsPathsOutsideHome() throws {
		let home = self.root.appendingPathComponent("home")
		try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
		XCTAssertThrowsError(try URL.openPIDDirectory(self.root.appendingPathComponent("vmnet.pid"), beneath: home, owner: getuid()))
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

#endif
