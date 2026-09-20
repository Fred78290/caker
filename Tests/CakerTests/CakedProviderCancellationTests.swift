import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import XCTest

@testable import CakedLib
@testable import caked

/// Exercises `CakedProvider.executeCancellable(command:)`/`stop()` directly (no real gRPC
/// transport involved) — regression coverage for the bug where `caked service listen` receiving
/// SIGINT called `provider.stop()`, which never actually cancelled a long-running streaming
/// command's (build/launch/provision) `Task`, since `CakedCommandAsync`'s default
/// `run(on:runMode:)` runs on an unstructured `Task` created by `EventLoop.makeFutureWithTask`
/// that nothing could reach from the outside.
final class CakedProviderCancellationTests: XCTestCase {
	/// A `CakedCommandAsync` that just sleeps and records whether it observed cancellation —
	/// standing in for `BuildHandler`/`ProvisionHandler`'s own long-running work without needing
	/// to actually build or provision a VM.
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
				// Long enough that the test would fail waiting for it to finish on its own —
				// the assertion is that `stop()` cancels it well before this elapses.
				try await Task.sleep(nanoseconds: 5_000_000_000)
			} catch is CancellationError {
				self.flag.markCancelled()
			} catch {
				// Not expected, but don't let an unrelated error fail this test's own timing.
			}

			return Caked_Reply()
		}
	}

	func testProviderStopCancelsInFlightExecuteCancellableTask() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let flag = CancellationFlag()

		let task = Task {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: flag), title: "sleepy task") {}
		}

		// Give `executeCancellable` a moment to register the task and reach the `Task.sleep` call
		// before asking the provider to stop.
		try await Task.sleep(nanoseconds: 200_000_000)

		provider.stop()

		try await task.value

		XCTAssertTrue(flag.wasCancelled, "stop() should have cancelled the in-flight task instead of letting it run to completion")
	}

	func testExecuteCancellableThrowsOnceProviderHasStopped() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)

		provider.stop()

		do {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: CancellationFlag()), title: "sleepy task") {}
			XCTFail("executeCancellable should refuse new work once the provider has stopped")
		} catch {
			// Expected — the same "Service is shutting down" guard `execute(command:)` already has.
		}
	}

	func testListTasksReturnsRegisteredTaskWithTitle() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let flag = CancellationFlag()

		let running = Task {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: flag), title: "build my-vm") {}
		}

		defer {
			running.cancel()
		}

		// Give `executeCancellable` a moment to register the task before listing.
		try await Task.sleep(nanoseconds: 200_000_000)

		let reply = await provider.listTasks()

		XCTAssertEqual(reply.tasks.list.tasks.count, 1)
		XCTAssertEqual(reply.tasks.list.tasks.first?.title, "build my-vm")
		XCTAssertNotNil(UUID(uuidString: reply.tasks.list.tasks.first?.id ?? ""), "the listed id should be a real UUID")
	}

	func testCancelTaskCancelsOnlyTheTargetedTask() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let targetFlag = CancellationFlag()
		let otherFlag = CancellationFlag()

		let target = Task {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: targetFlag), title: "target") {}
		}
		let other = Task {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: otherFlag), title: "other") {}
		}

		defer {
			other.cancel()
		}

		try await Task.sleep(nanoseconds: 200_000_000)

		let listed = await provider.listTasks()
		let targetEntry = try XCTUnwrap(listed.tasks.list.tasks.first { $0.title == "target" })

		let cancelReply = await provider.cancelTask(id: targetEntry.id)

		XCTAssertTrue(cancelReply.tasks.cancelled.success)

		try await target.value

		XCTAssertTrue(targetFlag.wasCancelled, "the targeted task should have been cancelled")
		XCTAssertFalse(otherFlag.wasCancelled, "cancelTask should not touch an unrelated task")
	}

	func testCancelTaskWithUnknownIdFails() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)

		let reply = await provider.cancelTask(id: UUID().uuidString)

		XCTAssertFalse(reply.tasks.cancelled.success)
		XCTAssertTrue(reply.tasks.cancelled.hasReason)
	}

	func testCancelTaskWithMalformedIdFails() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)

		let reply = await provider.cancelTask(id: "not-a-uuid")

		XCTAssertFalse(reply.tasks.cancelled.success)
		XCTAssertTrue(reply.tasks.cancelled.hasReason)
	}
}
