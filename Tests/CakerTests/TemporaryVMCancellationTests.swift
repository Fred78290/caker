//
//  TemporaryVMCancellationTests.swift
//  CakerTests
//

import Foundation
import XCTest

@testable import CakedLib
@testable import GRPCLib

/// Cancelling and failing the operations that work on a temporary VM copy: duplicate, create template
/// and push (through `TemplateHandler.cleanCloudInit(source:...)`).
final class TemporaryVMCancellationTests: XCTestCase {
	private var sourceDirectory: URL!

	override func setUpWithError() throws {
		self.sourceDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("duplicate-\(UUID().uuidString).vm")
		try FileManager.default.createDirectory(at: self.sourceDirectory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try? FileManager.default.removeItem(at: self.sourceDirectory)
	}

	/// A stopped macOS VM (no cloud-init step) with a config but, unless `withDisk`, no disk: copying it fails.
	private func makeSource(withDisk: Bool) throws -> VMLocation {
		let config = CakeConfig(
			location: self.sourceDirectory, rootDisk: nil, diskFormat: .raw, os: .darwin, autostart: false, configuredUser: "admin", configuredPassword: "x",
			configuredGroup: "adm", configuredGroups: nil, configuredPlatform: .unknown, clearPassword: false, displayRefit: false,
			ifname: false, cpuCountMin: 2, memorySize: 4096 * MoB, memorySizeMin: 512 * MoB, screenSize: .init(width: 1024, height: 768))

		try config.save()

		let location = VMLocation(rootURL: self.sourceDirectory)

		if withDisk {
			FileManager.default.createFile(atPath: location.diskURL.path(percentEncoded: false), contents: Data())
			FileManager.default.createFile(atPath: location.nvramURL.path(percentEncoded: false), contents: Data())
		}

		return location
	}

	/// A target name nothing uses, so a test never touches a real VM.
	private func unusedName() -> String {
		"duplicate-test-\(UUID().uuidString.prefix(8))"
	}

	private func temporaryEntries() throws -> Set<String> {
		let directory = try Home(runMode: .user).temporaryDirectory

		return Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? [])
	}

	func testCancelledTokenStopsBeforeAnythingIsCopied() throws {
		let source = try makeSource(withDisk: true)
		let target = unusedName()
		let cancellation = TemporaryVMCancellation(runMode: .user)
		let before = try temporaryEntries()

		cancellation.cancel()

		let reply = DuplicateHandler.duplicate(location: source, to: target, resetMacAddress: true, runMode: .user, cancellation: cancellation)

		XCTAssertFalse(reply.duplicated)
		XCTAssertEqual(reply.reason, DuplicateHandler.cancelledReason)
		XCTAssertFalse(StorageLocation(runMode: .user).exists(target))
		XCTAssertEqual(try temporaryEntries(), before)
	}

	func testCancellingTheTaskReturnsCancelled() async throws {
		let source = try makeSource(withDisk: true)
		let target = unusedName()
		let before = try temporaryEntries()
		let task = Task {
			// Wait to be cancelled first, so the duplicate starts cancelled.
			while Task.isCancelled == false {
				await Task.yield()
			}

			return await DuplicateHandler.duplicate(vmURL: source.rootURL, to: target, resetMacAddress: true, runMode: .user)
		}

		task.cancel()

		let reply = await task.value

		XCTAssertFalse(reply.duplicated)
		XCTAssertEqual(reply.reason, DuplicateHandler.cancelledReason)
		XCTAssertFalse(StorageLocation(runMode: .user).exists(target))
		XCTAssertEqual(try temporaryEntries(), before)
	}

	func testAFailedCopyDeletesTheTemporaryCopyButNeverTheSource() throws {
		let source = try makeSource(withDisk: false)
		let target = unusedName()
		let before = try temporaryEntries()

		let reply = DuplicateHandler.duplicate(location: source, to: target, resetMacAddress: true, runMode: .user, cancellation: TemporaryVMCancellation(runMode: .user))

		XCTAssertFalse(reply.duplicated)
		XCTAssertNotEqual(reply.reason, DuplicateHandler.cancelledReason)
		XCTAssertTrue(FileManager.default.fileExists(atPath: source.configURL.path(percentEncoded: false)), "the source VM must survive a failed duplicate")
		XCTAssertFalse(StorageLocation(runMode: .user).exists(target))
		XCTAssertEqual(try temporaryEntries(), before, "the temporary copy must be deleted")
	}

	/// `createTemplate` and `push` go through this helper: a failure must not leave the temporary copy behind.
	func testAFailedCloudInitCleanupDeletesItsTemporaryCopy() throws {
		let source = try makeSource(withDisk: false)
		let before = try temporaryEntries()

		XCTAssertThrowsError(try TemplateHandler.cleanCloudInit(source: source, startMode: .background, runMode: .user))
		XCTAssertTrue(FileManager.default.fileExists(atPath: source.configURL.path(percentEncoded: false)), "the source VM must survive")
		XCTAssertEqual(try temporaryEntries(), before, "the temporary copy must be deleted")
	}

	func testCancelledCloudInitCleanupThrowsAndDeletesItsTemporaryCopy() throws {
		let source = try makeSource(withDisk: true)
		let cancellation = TemporaryVMCancellation(runMode: .user)
		let before = try temporaryEntries()

		cancellation.cancel()

		XCTAssertThrowsError(try TemplateHandler.cleanCloudInit(source: source, startMode: .background, runMode: .user, cancellation: cancellation)) { error in
			XCTAssertTrue(error is CancellationError)
		}
		XCTAssertEqual(try temporaryEntries(), before, "the temporary copy must be deleted")
	}

	func testCancellingTemplateCreationReturnsCancelledAndWritesNoTemplate() async throws {
		let source = try makeSource(withDisk: true)
		let templateName = unusedName()
		let task = Task {
			// Wait to be cancelled first, so the creation starts cancelled.
			while Task.isCancelled == false {
				await Task.yield()
			}

			return await TemplateHandler.createTemplate(vmURL: source.rootURL, templateName: templateName, runMode: .user)
		}

		task.cancel()

		let reply = await task.value

		XCTAssertFalse(reply.created)
		XCTAssertEqual(reply.reason, TemporaryVMCancellation.cancelledReason)
		XCTAssertFalse(StorageLocation(runMode: .user, template: true).exists(templateName))
	}

	/// A stand-in for a temporary VM's `caked vmrun`: a process that ignores SIGINT, so only SIGKILL stops it,
	/// with its PID published in `location`'s PID file.
	private func startStubbornProcess(publishingIn location: VMLocation) throws -> Process {
		let process = Process()

		process.executableURL = URL(fileURLWithPath: "/bin/sh")
		// An ignored signal stays ignored across exec, so `sleep` ignores SIGINT too
		process.arguments = ["-c", "trap '' INT; exec /bin/sleep 60"]
		try process.run()
		// Let the shell install the trap before anything signals it
		Thread.sleep(forTimeInterval: 0.3)
		try "\(process.processIdentifier)".write(to: location.pidFile, atomically: true, encoding: .ascii)

		return process
	}

	func testKillingATemporaryVMIsBoundedAndFallsBackToSIGKILL() throws {
		let location = VMLocation(rootURL: self.sourceDirectory)
		let process = try startStubbornProcess(publishingIn: location)
		let start = Date()

		location.killTemporaryVirtualMachine(runMode: .user, timeout: 1)

		process.waitUntilExit()

		XCTAssertLessThan(Date().timeIntervalSince(start), 5, "the wait must be bounded")
		XCTAssertEqual(process.terminationReason, .uncaughtSignal)
		XCTAssertEqual(process.terminationStatus, SIGKILL)
		XCTAssertFalse(FileManager.default.fileExists(atPath: location.pidFile.path(percentEncoded: false)))
	}

	/// The temporary VM can publish its PID after the cancellation: it must still be killed then, not left to boot.
	func testCancelKillsATemporaryVMThatStartsAfterward() throws {
		let temporary = try VMLocation.tempDirectory(runMode: .user)
		let cancellation = TemporaryVMCancellation(runMode: .user)

		defer {
			try? temporary.delete()
		}

		try cancellation.register(temporary)
		cancellation.cancel()

		Thread.sleep(forTimeInterval: 0.5)

		let process = try startStubbornProcess(publishingIn: temporary)
		let exited = expectation(description: "the late temporary VM is killed")

		process.terminationHandler = { _ in
			exited.fulfill()
		}

		if process.isRunning == false {
			exited.fulfill()
		}

		// SIGINT is ignored: the kill's own 15 s wait, then SIGKILL
		wait(for: [exited], timeout: 25)

		XCTAssertEqual(process.terminationStatus, SIGKILL)

		// Deleting the copy (what the operation does once it has cleaned up) ends the watch
		try temporary.delete()
	}

	/// A source whose config names `rootDisk` and whose disk is at `diskPath` (created with `contents`).
	private func makeSource(rootDisk: String, diskPath: URL, contents: String) throws -> VMLocation {
		let config = CakeConfig(
			location: self.sourceDirectory, rootDisk: rootDisk, diskFormat: .raw, os: .darwin, autostart: false, configuredUser: "admin", configuredPassword: "x",
			configuredGroup: "adm", configuredGroups: nil, configuredPlatform: .unknown, clearPassword: false, displayRefit: false,
			ifname: false, cpuCountMin: 2, memorySize: 4096 * MoB, memorySizeMin: 512 * MoB, screenSize: .init(width: 1024, height: 768))

		try config.save()
		try FileManager.default.createDirectory(at: diskPath.deletingLastPathComponent(), withIntermediateDirectories: true)
		try contents.write(to: diskPath, atomically: true, encoding: .utf8)

		let location = VMLocation(rootURL: self.sourceDirectory)

		FileManager.default.createFile(atPath: location.nvramURL.path(percentEncoded: false), contents: Data())

		return location
	}

	private func makeTarget() throws -> VMLocation {
		let target = FileManager.default.temporaryDirectory.appendingPathComponent("duplicate-target-\(UUID().uuidString)")

		try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
		addTeardownBlock {
			try? FileManager.default.removeItem(at: target)
		}

		return VMLocation(rootURL: target)
	}

	/// The copy of a VM whose disk is elsewhere (absolute `rootDisk`) must use its own disk, never the source's.
	func testCopyOfAVMWithAnAbsoluteDiskUsesItsOwnDisk() throws {
		let outside = FileManager.default.temporaryDirectory.appendingPathComponent("outside-\(UUID().uuidString)/root.img")

		addTeardownBlock {
			try? FileManager.default.removeItem(at: outside.deletingLastPathComponent())
		}

		let source = try makeSource(rootDisk: outside.path(percentEncoded: false), diskPath: outside, contents: "source disk")
		let target = try makeTarget()

		try source.copyTo(target)

		let copied = target.rootURL.appendingPathComponent("disk.img")

		XCTAssertEqual(try String(contentsOf: copied, encoding: .utf8), "source disk")
		XCTAssertNil(try CakeConfig(location: target.rootURL).rootDisk)
		XCTAssertEqual(target.diskURL.resolvingSymlinksInPath(), copied.resolvingSymlinksInPath())
	}

	/// A relative custom disk keeps its path, inside the copy.
	func testCopyOfAVMWithARelativeDiskKeepsItsPath() throws {
		let source = try makeSource(rootDisk: "disks/root.img", diskPath: self.sourceDirectory.appendingPathComponent("disks/root.img"), contents: "source disk")
		let target = try makeTarget()

		try source.copyTo(target)

		let copied = target.rootURL.appendingPathComponent("disks/root.img")

		XCTAssertEqual(try String(contentsOf: copied, encoding: .utf8), "source disk")
		XCTAssertEqual(try CakeConfig(location: target.rootURL).rootDisk, "disks/root.img")
		XCTAssertEqual(target.diskURL.resolvingSymlinksInPath(), copied.resolvingSymlinksInPath())
	}

	/// A relative path leaving the VM's folder is treated like an absolute one.
	func testCopyOfAVMWithADiskOutsideItsFolderUsesItsOwnDisk() throws {
		let name = "outside-\(UUID().uuidString).img"
		let outside = self.sourceDirectory.deletingLastPathComponent().appendingPathComponent(name)

		addTeardownBlock {
			try? FileManager.default.removeItem(at: outside)
		}

		let source = try makeSource(rootDisk: "../\(name)", diskPath: outside, contents: "source disk")
		let target = try makeTarget()

		try source.copyTo(target)

		XCTAssertNil(try CakeConfig(location: target.rootURL).rootDisk)
		XCTAssertEqual(target.diskURL.resolvingSymlinksInPath(), target.rootURL.appendingPathComponent("disk.img").resolvingSymlinksInPath())
	}

	func testRegisteringAfterCancelThrows() throws {
		let cancellation = TemporaryVMCancellation(runMode: .user)
		let temporary = VMLocation(rootURL: self.sourceDirectory)

		cancellation.cancel()

		XCTAssertThrowsError(try cancellation.register(temporary)) { error in
			XCTAssertTrue(error is CancellationError)
		}
	}

	func testCommitAfterCancelDoesNotRun() {
		let cancellation = TemporaryVMCancellation(runMode: .user)
		var ran = false

		cancellation.cancel()

		XCTAssertThrowsError(try cancellation.commit { ran = true })
		XCTAssertFalse(ran)
	}

	func testCancelAfterCommitIsIgnored() throws {
		let cancellation = TemporaryVMCancellation(runMode: .user)

		try cancellation.commit {}
		cancellation.cancel()

		XCTAssertFalse(cancellation.isCancelled, "a duplicate already moved into place is finished")
	}
}
