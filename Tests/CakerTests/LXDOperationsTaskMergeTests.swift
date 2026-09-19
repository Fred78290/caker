import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import XCTest

@testable import CakedLib
@testable import caked

/// Coverage for `LXDOperationMetadata.from(taskEntry:)` — the pure helper that turns one entry
/// from `CakedProvider.listTasks()` (a gRPC-initiated build/launch/provision task tracked in
/// `CakedProvider.runningTasks`) into a synthesized `LXDOperationMetadata`, so `GET
/// /1.0/operations`/`GET /1.0/operations/:id` can surface gRPC-initiated work alongside
/// REST-initiated operations tracked in `LXDOperationStore`, and `DELETE /1.0/operations/:id`
/// can cancel one the same way `cakectl tasks cancel <id>` already does.
///
/// There is currently no Vapor/`Application`/`Request` test harness anywhere in this repo, so
/// this file sticks to unit-level coverage of the pure conversion helper plus an
/// integration-style test that exercises the real `CakedProvider` registry end to end
/// (`listTasks()` → `LXDOperationMetadata.from(taskEntry:)` → `cancelTask(id:)`), mirroring
/// `CakedProviderCancellationTests.swift`'s own approach.
final class LXDOperationsTaskMergeTests: XCTestCase {
	/// A `CakedCommandAsync` that just sleeps and records whether it observed cancellation —
	/// duplicated from `CakedProviderCancellationTests.swift`'s own private helper of the same
	/// shape, since both files need a lightweight `executeCancellable`-compatible stand-in for
	/// `BuildHandler`/`ProvisionHandler`'s real long-running work.
	private final class CancellationFlag: @unchecked Sendable {
		private let lock = NSLock()
		private var _wasCancelled = false

		var wasCancelled: Bool {
			self.lock.lock()
			defer { self.lock.unlock() }
			return self._wasCancelled
		}

		func markCancelled() {
			self.lock.lock()
			defer { self.lock.unlock() }
			self._wasCancelled = true
		}
	}

	private struct SleepyCommand: CakedCommandAsync {
		let flag: CancellationFlag

		func replyError(error: any Error) -> Caked_Reply {
			Caked_Reply()
		}

		func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
			do {
				try await Task.sleep(nanoseconds: 5_000_000_000)
			} catch is CancellationError {
				self.flag.markCancelled()
			} catch {
				// Not expected, but don't let an unrelated error fail this test's own timing.
			}

			return Caked_Reply()
		}
	}

	// MARK: - Pure helper: LXDOperationMetadata.from(taskEntry:)

	func testFromTaskEntryWithTwoWordTitlePopulatesResources() {
		var entry = Caked_Reply.TaskReply.TaskEntry()
		entry.id = "3F2504E0-4F89-41D3-9A0C-0305E82C3301"
		entry.title = "build myvm"

		let metadata = LXDOperationMetadata.from(taskEntry: entry)

		XCTAssertEqual(metadata.id, "3f2504e0-4f89-41d3-9a0c-0305e82c3301", "the id should be lowercased for consistency with LXDOperationStore's own ids")
		XCTAssertEqual(metadata.type, "task")
		XCTAssertEqual(metadata.description, "build myvm")
		XCTAssertEqual(metadata.status, "Running")
		XCTAssertEqual(metadata.statusCode, 103)
		XCTAssertTrue(metadata.mayCancel)
		XCTAssertEqual(metadata.error, "")
		XCTAssertNil(metadata.metadata)
		XCTAssertEqual(metadata.resources["instances"], ["/1.0/instances/myvm"])
	}

	func testFromTaskEntryWithoutASecondWordLeavesResourcesEmpty() {
		var entry = Caked_Reply.TaskReply.TaskEntry()
		entry.id = UUID().uuidString
		entry.title = "singleword"

		let metadata = LXDOperationMetadata.from(taskEntry: entry)

		XCTAssertTrue(metadata.resources.isEmpty, "a title with no space to split on should not crash and should leave resources empty")
		XCTAssertEqual(metadata.description, "singleword")
		XCTAssertEqual(metadata.type, "task")
		XCTAssertTrue(metadata.mayCancel)
	}

	func testFromTaskEntryWithEmptyTitleDoesNotCrash() {
		var entry = Caked_Reply.TaskReply.TaskEntry()
		entry.id = UUID().uuidString
		entry.title = ""

		let metadata = LXDOperationMetadata.from(taskEntry: entry)

		XCTAssertTrue(metadata.resources.isEmpty)
	}

	// MARK: - Integration: real CakedProvider registry → helper → cancellation

	func testListTasksMergesIntoSynthesizedOperationMetadata() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let flag = CancellationFlag()

		let running = Task {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: flag), title: "build my-vm")
		}

		defer {
			running.cancel()
		}

		// Give `executeCancellable` a moment to register the task before listing.
		try await Task.sleep(nanoseconds: 200_000_000)

		let reply = await provider.listTasks()
		let entries = reply.tasks.list.tasks

		XCTAssertEqual(entries.count, 1)

		let entry = try XCTUnwrap(entries.first)
		let metadata = LXDOperationMetadata.from(taskEntry: entry)

		XCTAssertEqual(metadata.description, "build my-vm")
		XCTAssertTrue(metadata.mayCancel)
		XCTAssertNotNil(UUID(uuidString: metadata.id), "the synthesized operation's id should still parse as a UUID once lowercased")
		XCTAssertEqual(metadata.resources["instances"], ["/1.0/instances/my-vm"])
	}

	func testCancelTaskThroughProviderCancelsTheRegisteredTask() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let flag = CancellationFlag()

		let running = Task {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: flag), title: "provision my-vm")
		}

		try await Task.sleep(nanoseconds: 200_000_000)

		let listed = await provider.listTasks()
		let entry = try XCTUnwrap(listed.tasks.list.tasks.first)
		let metadata = LXDOperationMetadata.from(taskEntry: entry)

		// The REST controller's `deleteOperation` calls `provider.cancelTask(id:)` directly with
		// the path parameter's id — exercise that exact call, using the id as synthesized above.
		let cancelReply = await provider.cancelTask(id: metadata.id)

		XCTAssertTrue(cancelReply.tasks.cancelled.success)

		try await running.value

		XCTAssertTrue(flag.wasCancelled, "cancelling through the provider should propagate the same way stop()/cakectl tasks cancel already do")
	}

	func testCancelTaskWithUnknownIdReturnsFailureReason() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try? group.syncShutdownGracefully())
		}

		let provider = try? CakedProvider(group: group, password: nil, runMode: .user)
		let reply = await provider?.cancelTask(id: UUID().uuidString)

		XCTAssertEqual(reply?.tasks.cancelled.success, false)
		XCTAssertTrue(reply?.tasks.cancelled.hasReason ?? false)
	}

	// MARK: - listTasks()/cancelTask(id:) merging in LXDOperationStore, without double-counting

	/// The core regression this file guards against: `listTasks()` (the merged, gRPC-facing method
	/// backing `ListTasks`/`cakectl tasks list`/the `caker` GUI) must include both a gRPC-native
	/// task and a REST-initiated `LXDOperationStore` operation exactly once each — while
	/// `nativeRunningTasks()` (what `LXDOperationsController.listOperations`/`getOperation` call,
	/// since they already list `LXDOperationStore`'s own entries themselves) must include only the
	/// gRPC-native one, or a REST-initiated Running operation would be double-listed once both
	/// call sites feed the same webui/REST response.
	func testListTasksMergesNativeAndRestOperationsExactlyOnce() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let flag = CancellationFlag()

		let running = Task {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: flag), title: "build native-vm")
		}

		defer {
			running.cancel()
		}

		let restOperation = await LXDOperationStore.shared.create(description: "Building rest-vm")

		defer {
			Task { await LXDOperationStore.shared.delete(id: restOperation.id) }
		}

		try await Task.sleep(nanoseconds: 200_000_000)

		let merged = await provider.listTasks()
		let mergedTitles = Set(merged.tasks.list.tasks.map { $0.title })
		let mergedIDs = Set(merged.tasks.list.tasks.map { $0.id.lowercased() })

		XCTAssertEqual(merged.tasks.list.tasks.count, 2, "listTasks() should include both the gRPC-native task and the Running REST operation, exactly once each")
		XCTAssertTrue(mergedTitles.contains("build native-vm"))
		XCTAssertTrue(mergedTitles.contains("Building rest-vm"))
		XCTAssertTrue(mergedIDs.contains(restOperation.id.lowercased()))

		let native = provider.nativeRunningTasks()

		XCTAssertEqual(native.tasks.list.tasks.count, 1, "nativeRunningTasks() must exclude LXDOperationStore entries, or LXDOperationsController would double-list them")
		XCTAssertEqual(native.tasks.list.tasks.first?.title, "build native-vm")
	}

	/// A `Success`/`Failure`-status `LXDOperationStore` operation is done, not "running" — it must
	/// not show up in `listTasks()`.
	func testListTasksExcludesCompletedRestOperations() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let completed = await LXDOperationStore.shared.create(description: "Already finished")

		await LXDOperationStore.shared.complete(id: completed.id, success: true)

		defer {
			Task { await LXDOperationStore.shared.delete(id: completed.id) }
		}

		let reply = await provider.listTasks()

		XCTAssertFalse(reply.tasks.list.tasks.contains { $0.id.lowercased() == completed.id.lowercased() }, "a completed REST operation should not be reported as a running task")
	}

	/// `cancelTask(id:)` must be able to cancel (i.e. remove) an `LXDOperationStore`-backed
	/// operation by id, exactly like it already does for a `runningTasks`-backed one.
	func testCancelTaskCancelsRestOperationByID() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let restOperation = await LXDOperationStore.shared.create(description: "Building rest-vm-2")

		let reply = await provider.cancelTask(id: restOperation.id)

		XCTAssertTrue(reply.tasks.cancelled.success)

		let stillThere = await LXDOperationStore.shared.get(id: restOperation.id)
		XCTAssertNil(stillThere, "cancelTask(id:) should have removed the REST operation from the store")
	}

	/// An id belonging to neither `runningTasks` nor `LXDOperationStore` must still fail with the
	/// original "No running task with id" reason.
	func testCancelTaskWithIdInNeitherRegistryStillFails() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let reply = await provider.cancelTask(id: UUID().uuidString)

		XCTAssertFalse(reply.tasks.cancelled.success)
		XCTAssertTrue(reply.tasks.cancelled.hasReason)
	}
}
